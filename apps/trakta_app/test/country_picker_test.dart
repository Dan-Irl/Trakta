// Country search, flags and the picker on the trip form.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/features/common/country_picker.dart';
import 'package:trakta_app/features/common/format.dart';
import 'package:trakta_app/l10n/app_localizations.dart';
import 'package:trakta_core/trakta_core.dart';

import 'test_rules.dart';
import 'widget_helpers.dart';

void main() {
  final pack = testLibrary().forYear(2026)!;
  final options = countryOptions(pack, lookupAppLocalizations(const Locale('sv')));
  List<String> search(String q) => searchCountries(options, q).map((o) => o.name).toList();

  test('flags come from the ISO code', () {
    expect(flagEmoji('DE'), '🇩🇪');
    expect(flagEmoji('se'), '🇸🇪');
    expect(flagEmoji(null), '');
    expect(flagEmoji('XYZ'), '');
  });

  test('options: Sweden first with the domestic amount, fallback last', () {
    expect(options.first.name, swedenName);
    expect(options.first.kr, pack.domestic.fullDayKr);
    expect(options.last.isFallback, isTrue);
    expect(options.where((o) => o.name == pack.foreignFallback), hasLength(1));
  });

  test('search by Swedish name, English name or code, ignoring accents', () {
    expect(search('tysk').first, 'Tyskland');
    expect(search('germ').first, 'Tyskland');
    expect(search('DE').first, 'Tyskland'); // exact code wins over names containing "de"
    expect(search('osterrike').first, 'Österrike');
    expect(search('sweden').first, swedenName);
    expect(search('SE').first, swedenName);
    expect(search('united').take(3), containsAll(['USA', 'Storbritannien och Nordirland']));
    expect(search('zzzz'), isEmpty);
    expect(search('  '), hasLength(options.length));
  });

  testWidgets('trip form: search and pick a country', (tester) async {
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'));
    await openTab(tester, 'Trips');
    await pumpUntilFound(tester, find.text('New trip'));
    await tester.tap(find.text('New trip'));
    await pumpUntilFound(tester, find.text('Country'));
    expect(find.textContaining('Sweden'), findsOneWidget);

    await tester.tap(find.textContaining('Sweden'));
    await pumpUntilFound(tester, find.text('Search country or code'));
    await tester.enterText(find.byType(TextField).last, 'germ');
    await pumpUntilFound(tester, find.text('Germany (Tyskland)'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(find.text(en.amountPerDay(formatMoney('en', const Ore.kr(760)))), findsOneWidget);

    await tester.tap(find.text('Germany (Tyskland)'));
    for (var i = 0; i < 20 && find.text('Search country or code').evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Search country or code'), findsNothing);
    expect(find.text('Germany (Tyskland)'), findsOneWidget); // now shown in the form field

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
