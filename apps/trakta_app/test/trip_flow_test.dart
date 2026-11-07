// Creating a trip in two steps: details, then a review of its days.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/data/repositories/trip_repository.dart';
import 'package:trakta_core/trakta_core.dart';

import 'widget_helpers.dart';

void main() {
  // The trip form's list; the trips list behind it scrolls too.
  final form = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first;

  testWidgets('new trip: details, review days, change one day, create', (tester) async {
    // Phone size, so the review and the day sheet are checked for overflow.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'));
    await openTab(tester, 'Trips');
    await pumpUntilFound(tester, find.text('New trip'));
    await tester.tap(find.text('New trip'));
    await pumpUntilFound(tester, find.text('Step 1 of 2'));
    expect(find.text('Filled in from your latest trip.'), findsNothing); // first trip
    expect(find.text('A trip gives a deduction only if'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2)); // night worker and per diem only

    // The per diem explanation sits behind an info button.
    expect(find.textContaining('box 2.2'), findsNothing);
    await tester.scrollUntilVisible(find.byTooltip('More information'), 200, scrollable: form);
    await tester.tap(find.byTooltip('More information'));
    await pumpUntilFound(tester, find.textContaining('box 2.2'));
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('box 2.2'), findsNothing);

    // Hotel paid by employer for every night.
    await tester.scrollUntilVisible(find.text('Standard (no receipt)'), 200, scrollable: form);
    await tester.tap(find.text('Standard (no receipt)'));
    await pumpUntilFound(tester, find.text('Paid by employer'));
    await tester.tap(find.text('Paid by employer').last);
    await tester.pump(const Duration(milliseconds: 500));

    // Next checks the details before leaving step 1.
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Step 1 of 2'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Kurs');
    await tester.tap(find.text('Next'));
    await pumpUntilFound(tester, find.text('Review days'));
    expect(find.text('Step 2 of 2'), findsOneWidget);
    // Default dates: today 08:00 until tomorrow 17:00, so two days.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(await db.select(db.trips).get(), isEmpty); // nothing saved yet

    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await pumpUntilFound(tester, find.text('Breakfast'));
    await tester.pump(const Duration(milliseconds: 500)); // let the sheet finish opening
    await tester.tap(find.text('Same as the trip: No free meal').first);
    await pumpUntilFound(tester, find.text('Paid by employer'));
    await tester.tap(find.text('Paid by employer').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await pumpUntilFound(tester, find.textContaining('Changed'));

    // Back keeps the flow and the change; Next returns to the review.
    await tester.pageBack();
    await pumpUntilFound(tester, find.text('Step 1 of 2'));
    await tester.tap(find.text('Next'));
    await pumpUntilFound(tester, find.textContaining('Changed'));

    await tester.tap(find.text('Create trip'));
    await pumpUntilFound(tester, find.text('Summary'));
    final bundle = (await TripRepository(db).loadAll()).single;
    expect(bundle.days.map((d) => d.breakfast), [MealStatus.paid, null]);
    expect(bundle.trip.lodging, LodgingKind.employerPaid);
    // Adding the trip confirms the listed requirements.
    expect(bundle.trip.confirmedBusinessTrip && bundle.trip.confirmed50km, isTrue);

    // The next trip starts with the same employer setup.
    await tester.pageBack();
    await pumpUntilFound(tester, find.text('New trip'));
    await tester.tap(find.text('New trip'));
    await pumpUntilFound(tester, find.text('Step 1 of 2'));
    await tester.scrollUntilVisible(find.text('Filled in from your latest trip.'), 200, scrollable: form);
    await tester.scrollUntilVisible(find.text('Paid by employer'), 200, scrollable: form);
    expect(find.text('Paid by employer'), findsOneWidget);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
