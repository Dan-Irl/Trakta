// Trakta developer script: set up, generate code, analyze and test, on
// Windows, macOS and Linux. Run from the repository root:
//
//   dart tool/bin/dev.dart          everything (setup + check)
//   dart tool/bin/dev.dart setup    pub get, rules sync, code generation
//   dart tool/bin/dev.dart check    analyze, all tests, schema, sync and offline checks
//   dart tool/bin/dev.dart rules    verify the rules pack against Skatteverket (network)
//
// It uses only dart:io, so it runs on a fresh clone before `pub get`. Output
// is also written to .dev-logs/last-run.log (git-ignored). The exit code is
// non-zero when a step failed. CI runs the same steps in checks.yml.
import 'dart:convert';
import 'dart:io';

final root = File.fromUri(Platform.script).parent.parent.parent.path;
final app = _join(root, 'apps/trakta_app');
final core = _join(root, 'packages/trakta_core');
final tool = _join(root, 'tool');
late final IOSink log;
final results = <String>[];

Future<void> main(List<String> args) async {
  final task = args.isEmpty ? 'all' : args.first;
  if (!const {'all', 'setup', 'check', 'rules'}.contains(task)) {
    stderr.writeln('Usage: dart tool/bin/dev.dart [all|setup|check|rules]');
    exit(64);
  }
  Directory(_join(root, '.dev-logs')).createSync(recursive: true);
  log = File(_join(root, '.dev-logs/last-run.log')).openWrite()
    ..writeln('Trakta dev.dart $task  ${DateTime.now().toIso8601String()}');

  switch (task) {
    case 'setup':
      await setup();
    case 'check':
      await check();
    case 'rules':
      await rules();
    default:
      await setup();
      await check();
  }

  final summary = '\n===== SUMMARY\n${results.join('\n')}';
  stdout.writeln(summary);
  log.writeln(summary);
  await log.close();
  stdout.writeln('\nFull log: ${_join(root, '.dev-logs/last-run.log')}');
  exit(results.any((r) => r.startsWith('FAIL')) ? 1 : 0);
}

Future<void> setup() async {
  await step('flutter version', root, 'flutter', ['--version']);
  await step('pub get (workspace)', root, 'flutter', ['pub', 'get']);
  await step('sync rules into app assets', root, 'dart', ['run', 'tool/bin/sync_rules.dart']);
  await step('gen-l10n', app, 'flutter', ['gen-l10n']);
  await step('build_runner (drift)', app, 'dart', ['run', 'build_runner', 'build']);
}

Future<void> check() async {
  await step('analyze', root, 'flutter', ['analyze']);
  await step('trakta_core tests (golden cases)', core, 'dart', ['test']);
  await step('tool tests', tool, 'dart', ['test']);
  await step('app tests', app, 'flutter', ['test', '--timeout', '90s']);
  await step('rules in sync', root, 'dart', ['run', 'tool/bin/sync_rules.dart', '--check']);
  await schemaSnapshot();
  await step('offline check', root, 'dart', ['run', 'tool/bin/check_offline.dart']);
}

Future<void> rules() async {
  await step('verify 2026 against Skatteverket API', tool, 'dart', ['run', 'bin/build_rules_pack.dart', '--year', '2026', '--check']);
}

/// The database schema must match its committed snapshot (AGENTS.md, Database).
Future<void> schemaSnapshot() async {
  const name = 'schema matches drift_schemas';
  final dumped = await run(app, 'dart', ['run', 'drift_dev', 'schema', 'dump', 'lib/data/db/database.dart', 'drift_schemas/app/']);
  final status = await Process.run('git', ['status', '--porcelain', '--', 'drift_schemas'], workingDirectory: app, runInShell: true);
  final changed = (status.stdout as String).trim();
  if (changed.isNotEmpty) {
    final message = 'The database schema changed:\n$changed\n'
        "Bump schemaVersion, add the migration step and run 'dart run drift_dev make-migrations' in apps/trakta_app.";
    stdout.writeln(message);
    log.writeln(message);
  }
  record(name, dumped == 0 && status.exitCode == 0 && changed.isEmpty ? 0 : 1);
}

Future<void> step(String name, String dir, String command, List<String> args) async {
  record(name, await run(dir, command, args));
}

/// Runs [command] in [dir], streaming its output to the console and the log.
Future<int> run(String dir, String command, List<String> args) async {
  final header = '\n===== $command ${args.join(' ')}  (in ${_relative(dir)})';
  stdout.writeln(header);
  log.writeln(header);
  try {
    // runInShell finds flutter.bat and dart.bat on Windows.
    final process = await Process.start(command, args, workingDirectory: dir, runInShell: true);
    final out = process.stdout.transform(utf8.decoder).forEach((s) {
      stdout.write(s);
      log.write(s);
    });
    final err = process.stderr.transform(utf8.decoder).forEach((s) {
      stderr.write(s);
      log.write(s);
    });
    final code = await process.exitCode;
    await Future.wait([out, err]);
    return code;
  } on ProcessException catch (e) {
    final message = 'Could not start $command: ${e.message}';
    stderr.writeln(message);
    log.writeln(message);
    return 127;
  }
}

void record(String name, int code) {
  final line = '${code == 0 ? 'OK  ' : 'FAIL($code)'} $name';
  results.add(line);
  log.writeln('----- $line');
}

String _join(String a, String b) => [a, ...b.split('/')].join(Platform.pathSeparator);

String _relative(String dir) => dir == root ? '.' : dir.substring(root.length + 1).replaceAll(r'\', '/');
