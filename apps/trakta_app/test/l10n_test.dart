// Full Swedish and English support (both languages must always be complete).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/app/app.dart';
import 'package:trakta_app/features/common/country_names.dart';
import 'package:trakta_app/features/common/format.dart';
import 'package:trakta_app/features/common/reason_text.dart';
import 'package:trakta_app/features/settings/glossary_screen.dart';
import 'package:trakta_app/l10n/app_localizations.dart';
import 'package:trakta_core/trakta_core.dart';

import 'test_rules.dart';

Map<String, Object?> _arb(String lang) =>
    (jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map).cast<String, Object?>();

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m[1]!).toSet();

void main() {
  final sv = _arb('sv');
  final en = _arb('en');
  final svL = lookupAppLocalizations(const Locale('sv'));
  final enL = lookupAppLocalizations(const Locale('en'));

  test('Swedish and English have exactly the same messages and placeholders', () {
    final svKeys = sv.keys.where((k) => !k.startsWith('@')).toSet();
    final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
    expect(svKeys.difference(enKeys), isEmpty, reason: 'missing in app_en.arb');
    expect(enKeys.difference(svKeys), isEmpty, reason: 'missing in app_sv.arb');
    for (final k in svKeys) {
      expect((sv[k]! as String).trim(), isNotEmpty, reason: 'empty sv $k');
      expect((en[k]! as String).trim(), isNotEmpty, reason: 'empty en $k');
      expect(_placeholders(en[k]! as String), _placeholders(sv[k]! as String), reason: k);
    }
  });

  test('every engine reason has text in both languages', () {
    const params = <String, Object>{
      'time': '08:00', 'limit': '12:00', 'country': 'Tyskland', 'kr': 760,
      'fallback': 'Övriga länder och områden', 'target': 'Danmark', 'countries': 'Finland, Norge',
      'year': 2031, 'from': '2026-12-01', 'pct': 70, 'days': 5, 'meals': 'breakfast+lunch',
      'amount': 7400, 'meal': 'lunch', 'metres': 486000, 'orePerMil': 2500, 'difference': 5000,
      'key': 'own_car', 'minutes': 600,
    };
    for (final code in ReasonCode.values) {
      final r = Reason(code, params);
      final s = reasonText(svL, r);
      final e = reasonText(enL, r);
      expect(s, isNotEmpty, reason: code.name);
      expect(e, isNotEmpty, reason: code.name);
      expect(e, isNot(contains('{')), reason: code.name);
    }
    expect(reasonText(enL, const Reason(ReasonCode.countryForeign, {'country': 'Tyskland', 'kr': 760})),
        'Germany (Tyskland): normalbelopp (standard daily amount) SEK 760.');
    expect(reasonText(svL, const Reason(ReasonCode.countryForeign, {'country': 'Tyskland', 'kr': 760})),
        'Tyskland: normalbelopp 760 kr.');
  });

  test('every country in the bundled rules packs has an English name', () {
    for (final pack in testLibrary().packs) {
      for (final r in pack.foreignRates) {
        expect(translatedCountryNames, contains(r.name), reason: '${pack.incomeYear}: ${r.name}');
      }
    }
    expect(countryName(enL, 'Sverige'), 'Sweden (Sverige)');
    expect(countryName(enL, 'USA'), 'United States (USA)');
    expect(countryName(svL, 'Tyskland'), 'Tyskland');
  });

  test('money and numbers follow the language', () {
    expect(formatMoney('sv', const Ore(122650)), '1 226,50 kr');
    expect(formatMoney('sv', const Ore.kr(300)), '300 kr');
    expect(formatMoney('en', const Ore(122650)), 'SEK 1,226.50');
    expect(formatMoney('en', const Ore.kr(300)), 'SEK 300');
    expect(formatDecimal('sv', 48.6), '48,6');
    expect(formatDecimal('en', 48.6), '48.6');
  });

  test('amounts typed in either language parse the same', () {
    for (final input in ['1 226,50', '1226,5', '1,226.50', '1226.50', '1.226,50']) {
      expect(parseKronorToOre(input), 122650, reason: input);
    }
    expect(parseKronorToOre('1,226'), 122600);
    expect(parseKronorToOre('300'), 30000);
    expect(parseKronorToOre('abc'), isNull);
    expect(oreToInput(122650, 'sv'), '1226,50');
    expect(oreToInput(122650, 'en'), '1226.50');
  });

  test('language choice: setting wins, else English devices get English, others Swedish', () {
    expect(resolveAppLocale('en', const Locale('sv')), const Locale('en'));
    expect(resolveAppLocale('sv', const Locale('en')), const Locale('sv'));
    expect(resolveAppLocale(null, const Locale('en', 'GB')), const Locale('en'));
    expect(resolveAppLocale(null, const Locale('sv', 'SE')), const Locale('sv'));
    expect(resolveAppLocale(null, const Locale('ar')), const Locale('sv'));
  });

  test('glossary entries are complete in both languages', () {
    for (final g in glossary) {
      expect(g.sv, isNotEmpty);
      expect(g.en, isNotEmpty);
    }
  });
}
