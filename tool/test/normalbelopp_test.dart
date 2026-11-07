// Build tool tests. The fixtures are synthetic files in the shape of
// Skatteverket's API and CSV (the API could not be called when they were made).
// Replace them with a real recorded response when running the tool for real.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trakta_core/trakta_core.dart';
import 'package:trakta_tool/normalbelopp.dart';
import 'package:trakta_tool/repo.dart';

void main() {
  final root = findRepoRoot();
  final fixtures = p(root, ['tool', 'test', 'fixtures']);

  List<RawRow> apiRows() {
    final body = jsonDecode(File('$fixtures/api_2026_synthetic.json').readAsStringSync()) as Map;
    return parseApiResults((body['results'] as List).cast<Object?>());
  }

  test('parseAmount strips spaces and non-breaking spaces', () {
    expect(parseAmount('1 226'), 1226);
    expect(parseAmount('1 226'), 1226);
    expect(parseAmount('470'), 470);
    expect(parseAmount('Se Myanmar'), isNull);
  });

  test('parseRedirect is case-insensitive', () {
    expect(parseRedirect('Se Myanmar'), 'Myanmar');
    expect(parseRedirect('se övriga länder och områden'), 'övriga länder och områden');
    expect(parseRedirect('1226'), isNull);
  });

  test('API rows resolve to the reviewed 2026 pack', () {
    final resolved = resolveRows(apiRows(), knownCodes: const {'Grönland': 'GL', 'Iran': 'IR'});
    expect(resolved.errors, isEmpty);
    final reviewed = RulesPack.fromJson(readJson(File(p(root, ['rules', '2026.json']))));
    final byName = {for (final r in resolved.rates) r.name: r};
    for (final r in reviewed.foreignRates) {
      expect(byName[r.name]?.kr, r.kr, reason: r.name);
      expect(byName[r.name]?.redirectTo, r.redirectTo, reason: r.name);
    }
    expect(resolved.rates.last.name, fallbackName);
  });

  test('lowercase redirect to the fallback resolves with canonical casing', () {
    final nigeria = resolveRows(apiRows()).rates.firstWhere((r) => r.name == 'Nigeria');
    expect(nigeria.kr, 470);
    expect(nigeria.redirectTo, fallbackName);
  });

  test('CSV and API agree', () {
    final csv = resolveRows(parseCsv(File('$fixtures/normalbelopp_2026_synthetic.csv').readAsStringSync()));
    expect(csv.errors, isEmpty);
    final d = diffRates(csv.rates, resolveRows(apiRows()).rates);
    expect(d.added, isEmpty);
    expect(d.removed, isEmpty);
    expect(d.changed.where((c) => c.from.kr != c.to.kr), isEmpty);
  });

  test('broken redirect and missing fallback are errors', () {
    final rows = [
      for (var i = 0; i < 120; i++) RawRow(name: 'Land $i', code: null, value: '${300 + i}'),
      const RawRow(name: 'Alias', code: null, value: 'Se Nowhere'),
    ];
    final r = resolveRows(rows);
    expect(r.errors.any((e) => e.contains('Nowhere')), isTrue);
    expect(r.errors.any((e) => e.contains('Fallback')), isTrue);
  });

  test('diff flags changes over 30 percent', () {
    const a = [ForeignRate(name: 'X', code: 'XX', kr: 100), ForeignRate(name: 'Y', code: 'YY', kr: 100)];
    const b = [ForeignRate(name: 'X', code: 'XX', kr: 131), ForeignRate(name: 'Y', code: 'YY', kr: 110)];
    final d = diffRates(a, b);
    expect(d.changed, hasLength(2));
    expect(d.bigChanges.single.to.name, 'X');
  });

  test('encodePack round-trips', () {
    final json = readJson(File(p(root, ['rules', '2026.json'])));
    final again = jsonDecode(encodePack(json));
    expect(again, json);
  });
}
