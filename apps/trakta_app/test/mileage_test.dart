// Business drives: distance or odometer, no business/private switch, and the
// car allowance as a rate per mil set once in the tab.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/data/db/database.dart';
import 'package:trakta_app/data/repositories/mileage_repository.dart';
import 'package:trakta_app/features/common/format.dart';
import 'package:trakta_core/trakta_core.dart';

import 'widget_helpers.dart';

void main() {
  testWidgets('allowance set in the tab is used for a new drive', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(
      tester,
      locale: const Locale('en', 'SE'),
      seed: (db) => MileageRepository(db).saveVehicle(
        VehiclesCompanion.insert(
          label: 'Volvo',
          registration: const Value('ABC123'),
          ownership: Ownership.own,
          powertrain: Powertrain.fossil,
        ),
      ),
    );
    await openTab(tester, 'Driving log');
    await pumpUntilFound(tester, find.text('Car allowance from your employer'));
    expect(find.text('None'), findsOneWidget);

    // Set 18.50 kr per mil.
    await tester.tap(find.text('Car allowance from your employer'));
    await pumpUntilFound(tester, find.text('My employer pays a car allowance'));
    await tester.tap(find.text('My employer pays a car allowance'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Amount per mil (10 km)'), '18.50');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await pumpUntilFound(tester, find.text('${formatMoney('en', const Ore(1850))} per mil'));

    // A new drive: no business switch, the allowance prefilled, the total shown.
    await tester.tap(find.text('New drive'));
    await pumpUntilFound(tester, find.text('Distance (km)'));
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Odometer start (km)'), findsNothing); // distance mode: one field
    await tester.enterText(find.widgetWithText(TextFormField, 'Distance (km)'), '120');
    await tester.pump();
    final form = find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.textContaining('for this drive'), 200, scrollable: form);
    expect(find.text('${formatMoney('en', const Ore.kr(222))} for this drive'), findsOneWidget); // 12 mil × 18.50

    await tester.tap(find.text('Save'));
    await pumpUntilFound(tester, find.text('New drive'));
    final entry = (await tester.runAsync(() => db.select(db.mileageEntries).getSingle()))!;
    expect((entry.distanceM, entry.odoStart, entry.allowanceOrePerMil), (120000, null, 1850));

    // Odometer mode instead: only the two readings.
    await tester.tap(find.text('New drive'));
    await pumpUntilFound(tester, find.text('Distance (km)'));
    await tester.tap(find.text('Odometer'));
    await tester.pump();
    expect(find.text('Distance (km)'), findsNothing);
    expect(find.text('Odometer start (km)'), findsOneWidget);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
