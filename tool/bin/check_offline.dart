// CI gate for the offline guarantee (docs/architecture.md):
//  1. The main (release) AndroidManifest.xml has no INTERNET permission.
//  2. Any merged *release* manifest from a build has no INTERNET permission.
//  3. No banned networking/analytics package is in the app's runtime
//     dependency tree.
//
//   dart run tool/bin/check_offline.dart   # from the repo root
import 'dart:convert';
import 'dart:io';

import 'package:trakta_tool/offline_check.dart';
import 'package:trakta_tool/repo.dart';

Future<void> main() async {
  final root = findRepoRoot();
  final app = Directory(p(root, ['apps', 'trakta_app']));
  final failures = <String>[];

  // 1. Source manifest.
  final manifest = File(p(app, ['android', 'app', 'src', 'main', 'AndroidManifest.xml']));
  if (!manifest.existsSync()) {
    failures.add('Missing ${manifest.path} (the android folder is committed; restore it from git)');
  } else if (manifestHasInternet(manifest.readAsStringSync())) {
    failures.add('${manifest.path} declares android.permission.INTERNET');
  } else {
    print('OK  main AndroidManifest.xml has no INTERNET permission');
  }

  // 2. Merged release manifests, if a release build exists.
  final intermediates = Directory(p(app, ['build', 'app', 'intermediates']));
  var mergedChecked = 0;
  if (intermediates.existsSync()) {
    for (final f in intermediates.listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll('\\', '/');
      if (!path.endsWith('/AndroidManifest.xml')) continue;
      if (!path.contains('merged_manifest') || !path.toLowerCase().contains('release')) continue;
      mergedChecked++;
      if (manifestHasInternet(f.readAsStringSync())) {
        failures.add('Merged release manifest declares INTERNET: ${f.path}');
      }
    }
  }
  print(mergedChecked == 0
      ? 'SKIP merged release manifest (no release build found; CI builds one)'
      : 'OK  $mergedChecked merged release manifest(s) checked');

  // 3. Dependency tree.
  final result = await Process.run(
    'flutter',
    ['pub', 'deps', '--json'],
    workingDirectory: app.path,
    runInShell: true,
    stdoutEncoding: utf8,
  );
  if (result.exitCode != 0) {
    failures.add('flutter pub deps failed: ${result.stderr}');
  } else {
    final out = result.stdout as String;
    final json = (jsonDecode(out.substring(out.indexOf('{'))) as Map).cast<String, Object?>();
    final deps = parseDepsJson(json, 'trakta_app');
    final banned = findBanned('trakta_app', deps.runtimeDeps, deps.graph);
    if (banned.isEmpty) {
      print('OK  no banned packages among ${deps.graph.length} packages');
    } else {
      for (final path in banned) {
        failures.add('Banned package ${path.last} reached via ${path.join(' -> ')}');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('\nOffline check FAILED:\n  ${failures.join('\n  ')}');
    exit(1);
  }
  print('\nOffline check passed.');
}
