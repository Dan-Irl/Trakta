import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_helpers.dart';

void main() {
  testWidgets('app starts on the overview; the trips tab has the empty list, in Swedish', (tester) async {
    final db = await pumpApp(tester, locale: const Locale('sv', 'SE'));

    await pumpUntilFound(tester, find.text('Förväntat avdrag ${DateTime.now().year}'));
    await openTab(tester, 'Resor');
    await pumpUntilFound(tester, find.textContaining('Inga resor ännu'));
    expect(find.text('Resor'), findsWidgets);
    expect(find.text('Ny resa'), findsOneWidget);

    await tester.tap(find.text('Ny resa'));
    await pumpUntilFound(tester, find.text('Syfte med resan'));

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('English device gets the English app', (tester) async {
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'));

    await pumpUntilFound(tester, find.text('Overview'));
    await openTab(tester, 'Trips');
    await pumpUntilFound(tester, find.text('New trip'));
    expect(find.text('Trips'), findsWidgets);

    await openTab(tester, 'Overview');
    await tester.tap(find.byTooltip('Settings'));
    await pumpUntilFound(tester, find.text('Language'));

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
