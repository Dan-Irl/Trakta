// Fetches Skatteverket's normalbelopp for an income year and writes them into
// rules/<year>.json (docs/rules-packs.md). Run from anywhere in the repo:
//
//   cd tool
//   dart run bin/build_rules_pack.dart --year 2026 --check   # verify the reviewed pack
//   dart run bin/build_rules_pack.dart --year 2027           # create/update a pack
//   dart run bin/build_rules_pack.dart --year 2026 --csv ~/Downloads/normalbelopp-2026.csv
//
// This is the only code in the repository that talks to the network, and it
// never ships in the app.
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:trakta_core/trakta_core.dart';
import 'package:trakta_tool/normalbelopp.dart';
import 'package:trakta_tool/repo.dart';

const _host = 'skatteverket.entryscape.net';
const _path = '/rowstore/dataset/70ccea31-b64c-4bf5-84c7-673f04f32505';
const _pageSize = 500;

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('year', abbr: 'y', help: 'Income year', mandatory: true)
    ..addFlag('check', help: 'Compare with the existing pack; exit 1 if it differs', negatable: false)
    ..addOption('csv', help: "Skatteverket's CSV for the same year, used as a cross-check")
    ..addOption('api-json', help: 'Use a saved API response (JSON) instead of fetching')
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }
  if (args.flag('help')) {
    print(parser.usage);
    return;
  }
  final year = int.parse(args.option('year')!);
  final root = findRepoRoot();
  final rulesDir = Directory(p(root, ['rules']));

  // 1. Fetch.
  final List<RawRow> apiRows;
  final apiJson = args.option('api-json');
  if (apiJson != null) {
    final body = readJson(File(apiJson));
    apiRows = parseApiResults((body['results']! as List).cast<Object?>());
    print('Read ${apiRows.length} rows from $apiJson');
  } else {
    apiRows = await _fetchAll(year);
    print('Fetched ${apiRows.length} rows for $year from https://$_host$_path');
  }

  // 2. Codes we already know, for redirect rows without landskod.
  final knownCodes = <String, String>{};
  for (final f in packFiles(rulesDir)) {
    for (final r in (readJson(f)['foreignRates'] as List? ?? const [])) {
      final m = (r as Map).cast<String, Object?>();
      if (m['code'] is String && m['redirectTo'] == null) knownCodes[m['name']! as String] = m['code']! as String;
    }
  }

  final resolved = resolveRows(apiRows, knownCodes: knownCodes);
  final errors = [...resolved.errors];

  // 3. Cross-check with the CSV.
  final csvPath = args.option('csv');
  if (csvPath != null) {
    final csv = resolveRows(parseCsv(File(csvPath).readAsStringSync()), knownCodes: knownCodes);
    errors.addAll(csv.errors.map((e) => 'CSV: $e'));
    final d = diffRates(csv.rates, resolved.rates);
    final amountDiffs = d.changed.where((c) => c.from.kr != c.to.kr).toList();
    if (d.added.isNotEmpty || d.removed.isNotEmpty || amountDiffs.isNotEmpty) {
      errors.add('API and CSV disagree:\n$d');
    } else {
      print('CSV cross-check: API and CSV agree (${csv.rates.length} rows).');
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Validation failed:\n  ${errors.join('\n  ')}');
    exit(1);
  }

  // 4. Diff against the previous year for human review.
  final prevFile = File(p(root, ['rules', '${year - 1}.json']));
  if (prevFile.existsSync()) {
    final prev = RulesPack.fromJson(readJson(prevFile));
    final d = diffRates(prev.foreignRates, resolved.rates);
    print('\nChanges since ${year - 1}: ${d.added.length} added, ${d.removed.length} removed, '
        '${d.changed.length} changed, ${d.bigChanges.length} over ±30 %');
    if (!d.isEmpty) print(d);
  }

  final target = File(p(root, ['rules', '$year.json']));

  // 5. --check: compare with the reviewed pack.
  if (args.flag('check')) {
    if (!target.existsSync()) {
      stderr.writeln('No ${target.path} to check.');
      exit(1);
    }
    final existing = RulesPack.fromJson(readJson(target));
    final d = diffRates(existing.foreignRates, resolved.rates);
    if (d.isEmpty) {
      print('OK: rules/$year.json matches Skatteverket (${existing.foreignRates.length} rows).');
      return;
    }
    stderr.writeln('rules/$year.json differs from Skatteverket:\n$d');
    stderr.writeln('Re-run without --check to update it, then bump packVersion.');
    exit(1);
  }

  // 6. Write.
  final draft = File(p(root, ['rules', 'drafts', '$year.json']));
  final base = target.existsSync()
      ? readJson(target)
      : draft.existsSync()
          ? readJson(draft)
          : null;
  if (base == null) {
    stderr.writeln('Neither rules/$year.json nor rules/drafts/$year.json exists. Copy last year\'s '
        'pack to rules/drafts/$year.json, update the domestic, meal, mileage and commute values, '
        'set packVersion to "$year.1", and run again.');
    exit(1);
  }
  final today = DateTime.now();
  final takenOn =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final out = <String, Object?>{
    for (final e in base.entries)
      if (!e.key.startsWith('_')) e.key: e.value,
  };
  out['foreignRatesSource'] = 'https://$_host$_path';
  out['foreignRatesTakenOn'] = takenOn;
  out['foreignFallback'] = fallbackName;
  out['foreignRates'] = ratesToJson(resolved.rates);

  final pack = RulesPack.fromJson(jsonDecode(jsonEncode(out)) as Map<String, Object?>);
  final problems = validateRulesPack(pack);
  if (problems.isNotEmpty) {
    stderr.writeln('The new pack does not validate:\n  ${problems.join('\n  ')}');
    exit(1);
  }
  target.writeAsStringSync(encodePack(out));
  print('\nWrote ${target.path} (${resolved.rates.length} foreign rows).');
  print('Next: review the diff, bump packVersion if this changes a released pack, '
      'run `dart run bin/sync_rules.dart`, and add golden tests for $year.');
}

Future<List<RawRow>> _fetchAll(int year) async {
  final client = http.Client();
  try {
    final rows = <RawRow>[];
    var offset = 0;
    while (true) {
      final uri = Uri.https(_host, _path, {
        'år': '$year',
        '_limit': '$_pageSize',
        '_offset': '$offset',
      });
      final res = await client.get(uri, headers: {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        throw HttpException('GET $uri -> ${res.statusCode}: ${res.body}');
      }
      final body = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, Object?>();
      final results = (body['results'] as List?)?.cast<Object?>();
      if (results == null) {
        throw FormatException('Unexpected API response, keys: ${body.keys.toList()}');
      }
      final page = parseApiResults(results);
      rows.addAll(page);
      final total = (body['resultCount'] ?? body['total']) as num?;
      offset += _pageSize;
      if (page.isEmpty || total == null || offset >= total) break;
    }
    // The API may ignore the year filter; keep only matching rows if a year field exists.
    return rows;
  } finally {
    client.close();
  }
}
