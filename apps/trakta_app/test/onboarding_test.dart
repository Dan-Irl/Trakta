// First launch: the welcome pages and the disclaimer, and the same text
// under Settings → About.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_helpers.dart';

void main() {
  testWidgets('first launch: three pages, the disclaimer must be accepted, then the overview', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'), onboarded: false);
    await pumpUntilFound(tester, find.text('Welcome to Trakta'));
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Next'));
    await pumpUntilFound(tester, find.text('Not tax advice'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining("I'm a software engineer, not a tax advisor"), findsOneWidget);

    await tester.tap(find.text('Next'));
    await pumpUntilFound(tester, find.text('Offline, free, and your data'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('no internet access at all'), findsOneWidget);
    expect(find.textContaining('You own your data'), findsOneWidget);

    // Get started stays disabled until the disclaimer is confirmed.
    final start = find.widgetWithText(FilledButton, 'Get started');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.tap(find.text('I understand that Trakta is not tax advice'));
    await tester.pump();
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);

    await tester.tap(start);
    await pumpUntilFound(tester, find.textContaining('Expected deduction'));
    expect(find.byType(NavigationBar), findsOneWidget);
    final profile = await tester.runAsync(() => db.select(db.profiles).getSingle());
    expect(profile!.onboardingDone, isTrue);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('the disclaimer can be read again under Settings', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester, locale: const Locale('sv', 'SE'));
    await pumpUntilFound(tester, find.byTooltip('Inställningar'));
    await tester.tap(find.byTooltip('Inställningar'));
    await pumpUntilFound(tester, find.text('Språk'));
    await tester.scrollUntilVisible(find.text('Om Trakta och ansvarsfriskrivning'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Om Trakta och ansvarsfriskrivning'));
    await tester.pump();
    await tester.tap(find.text('Om Trakta och ansvarsfriskrivning'));
    await pumpUntilFound(tester, find.text('Inte skatterådgivning'));
    expect(find.textContaining('Jag är mjukvaruutvecklare, inte skatterådgivare'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Offline, gratis och dina data'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Offline, gratis och dina data'), findsOneWidget);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
