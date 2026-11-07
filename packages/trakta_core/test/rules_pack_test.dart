// Every bundled rules pack must load and validate.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:trakta_core/trakta_core.dart';

import 'helpers.dart';

void main() {
  final root = repoRoot();
  final packFiles = Directory('${root.path}/rules')
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'[/\\]\d{4}\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('at least the 2026 pack is present', () {
    expect(packFiles.map((f) => f.uri.pathSegments.last), contains('2026.json'));
  });

  for (final f in packFiles) {
    final name = f.uri.pathSegments.last;
    group(name, () {
      late RulesPack pack;
      late Map<String, Object?> json;

      setUpAll(() {
        json = (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
        pack = RulesPack.fromJson(json);
      });

      test('file name matches incomeYear', () {
        expect(name, '${pack.incomeYear}.json');
      });

      test('passes semantic validation', () {
        expect(validateRulesPack(pack), isEmpty);
      });

      test('has only known top-level keys', () {
        const known = {
          r'$schema', 'incomeYear', 'packVersion', 'domestic', 'dayType', 'mealReductionPct',
          'internationalTransitFullDay', 'foreignRatesSource', 'foreignRatesTakenOn', 'foreignFallback',
          'foreignRates', 'mileageOrePerMil', 'pluginHybridWorkplaceChargingOkFrom', 'commute', 'sources',
        };
        expect(json.keys.toSet().difference(known), isEmpty);
      });

      test('app asset copy is identical (run: dart run tool/bin/sync_rules.dart)', () {
        final asset = File('${root.path}/apps/trakta_app/assets/rules/$name');
        expect(asset.existsSync(), isTrue, reason: 'missing ${asset.path}');
        expect(asset.readAsStringSync(), f.readAsStringSync());
      });
    });
  }

  test('2026 has the published list (200 rows incl. fallback, page 2026-01-27)', () {
    // Skatteverket's page mentioned 201 rows; the reviewed list has 200. Re-check with
    // `dart run bin/build_rules_pack.dart --year 2026 --check` in tool/.
    expect(loadPack(2026).foreignRates.length, greaterThanOrEqualTo(200));
  });

  test('validator catches a broken redirect and a missing fallback', () {
    final json = loadPackJson(2026);
    final rates = [
      for (final r in (json['foreignRates']! as List).cast<Map<String, Object?>>())
        if (r['name'] != 'Övriga länder och områden') r,
      {'name': 'Testland', 'code': null, 'kr': 999, 'redirectTo': 'Nowhere'},
    ];
    final broken = RulesPack.fromJson({...json, 'foreignRates': rates});
    final errors = validateRulesPack(broken);
    expect(errors.any((e) => e.contains('fallback')), isTrue);
    expect(errors.any((e) => e.contains('Nowhere')), isTrue);
  });
}
