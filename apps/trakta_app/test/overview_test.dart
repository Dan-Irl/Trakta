// The overview: expected deductions for an income year.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/app/providers.dart';
import 'package:trakta_app/data/calculation/trip_calculations.dart';
import 'package:trakta_app/data/calculation/year_summary.dart';
import 'package:trakta_app/data/db/database.dart';
import 'package:trakta_app/data/repositories/mileage_repository.dart';
import 'package:trakta_app/data/repositories/trip_repository.dart';
import 'package:trakta_app/features/common/format.dart';
import 'package:trakta_core/trakta_core.dart';

import 'test_rules.dart';
import 'widget_helpers.dart';

/// A trip to Germany (3 days, hotel paid by the employer, no per diem paid)
/// and business drives of 100 km with 45 kr congestion tax, and one drive
/// the year before.
Future<void> seed(AppDatabase db, int year) async {
  await TripRepository(db).save(TripDraft(
    purpose: 'Mässa',
    departure: WallTime.parse('$year-03-02T07:00'),
    returnTime: WallTime.parse('$year-03-04T20:00'),
    country: 'Tyskland',
    confirmedBusinessTrip: true,
    confirmed50km: true,
    employerPaysPerDiem: false,
    lodging: LodgingKind.employerPaid,
  ));
  final mileage = MileageRepository(db);
  final car = await mileage.saveVehicle(
    VehiclesCompanion.insert(label: 'Volvo', ownership: Ownership.own, powertrain: Powertrain.fossil),
  );
  MileageEntriesCompanion drive(String date, int km, {int congestionOre = 0}) =>
      MileageEntriesCompanion.insert(
        date: date,
        vehicleId: car,
        distanceM: km * 1000,
        congestionTaxOre: Value(congestionOre),
        createdUtc: DateTime.now().toUtc(),
      );
  await mileage.saveEntry(drive('$year-03-02', 60, congestionOre: 4500));
  await mileage.saveEntry(drive('$year-03-04', 40));
  await mileage.saveEntry(drive('${year - 1}-12-01', 500));
}

void main() {
  test('year summary adds up trips and drives of that year only', () async {
    final db = testDatabase();
    addTearDown(db.close);
    await seed(db, 2026);
    final profile = await db.select(db.profiles).getSingle();
    final trips = TripCalculations.computeAll(await TripRepository(db).loadAll(), testLibrary(), profile);
    final vehicles = {for (final v in await db.select(db.vehicles).get()) v.id: v};
    final lines = [
      for (final e in await db.select(db.mileageEntries).get())
        MileageLine(
          entry: e,
          vehicle: vehicles[e.vehicleId]!,
          result: MileageCalculator.calculate(e.toInput(), vehicles[e.vehicleId]!.toInput(), testLibrary()),
        ),
    ];

    final s = YearSummary.of(2026, trips.values, lines, profile.userType);
    expect((s.trips, s.days, s.nights), (1, 3, 2));
    expect(s.perDiemDeduction, const Ore.kr(3 * 760)); // normalbelopp Germany
    expect(s.nightDeduction, Ore.zero); // hotel paid by employer
    expect((s.drives, s.businessMetres), (2, 100000));
    expect(s.mileageDeduction, const Ore.kr(250)); // 10 mil × 25 kr
    expect(s.drivingExpenses, const Ore.kr(45));
    expect(s.total, const Ore.kr(2280 + 250 + 45));

    expect(YearSummary.of(2025, trips.values, lines, profile.userType).drives, 1);
    expect(YearSummary.years(trips.values, lines, 2026), [2026, 2025]);
  });

  testWidgets('overview: the total, what goes in which box, and each section', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final year = DateTime.now().year;
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'));
    await pumpUntilFound(tester, find.text('Expected deduction $year'));
    expect(find.textContaining('Nothing to enter yet'), findsOneWidget);
    expect(find.text('Not started'), findsNWidgets(3));

    await seed(db, year);
    String kr(int n) => formatMoney('en', Ore.kr(n));
    await pumpUntilFound(tester, find.text('Box 2.2 (Tjänsteresor)'));
    // The total and box 2.2 are the same here: trips 2 280 + driving 295.
    expect(find.text(kr(2575)), findsNWidgets(2));
    expect(find.text('Per diem, night allowance and business driving. Enter this amount.'), findsOneWidget);
    expect(find.text('Box 1.2 (Kostnadsersättningar)'), findsNothing); // the employer paid nothing
    expect(find.textContaining('Box 2.1'), findsNothing); // no commute set up

    await tester.scrollUntilVisible(find.text('Tracked in $year'), 200, scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('100 km · 2 drives'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('1 trip · 3 days'), findsOneWidget);
    expect(find.text(kr(2280)), findsOneWidget);
    expect(find.text(kr(295)), findsOneWidget);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('car allowance per mil: paid amount, tax-free part, and a rate change for the year', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final mileage = MileageRepository(db);
    final car = await mileage.saveVehicle(
      VehiclesCompanion.insert(label: 'Volvo', ownership: Ownership.own, powertrain: Powertrain.fossil),
    );
    // 100 km at the standard 25 kr per mil, with the employer paying the same.
    await mileage.saveEntry(MileageEntriesCompanion.insert(
      date: '2026-04-01',
      vehicleId: car,
      distanceM: 100000,
      allowanceOrePerMil: const Value(2500),
      createdUtc: DateTime.now().toUtc(),
    ));
    await mileage.saveEntry(MileageEntriesCompanion.insert(
      date: '2025-11-01',
      vehicleId: car,
      distanceM: 50000,
      allowanceOrePerMil: const Value(2000),
      createdUtc: DateTime.now().toUtc(),
    ));
    final profile = await db.select(db.profiles).getSingle();
    Future<YearSummary> summary() async {
      final vehicles = {for (final v in await db.select(db.vehicles).get()) v.id: v};
      final lines = [
        for (final e in await db.select(db.mileageEntries).get())
          MileageLine(
            entry: e,
            vehicle: vehicles[e.vehicleId]!,
            result: MileageCalculator.calculate(e.toInput(), vehicles[e.vehicleId]!.toInput(), testLibrary()),
          ),
      ];
      return YearSummary.of(2026, const [], lines, profile.userType);
    }

    var entry = (await db.select(db.mileageEntries).get()).firstWhere((e) => e.date.startsWith('2026'));
    expect(entry.allowancePaid, const Ore.kr(250)); // 10 mil × 25 kr
    var s = await summary();
    expect(s.mileageTaxFree, const Ore.kr(250));
    expect(s.mileageDeduction, Ore.zero); // paid the standard: nothing to deduct

    // A higher rate for the whole year: the excess is taxable, still no deduction.
    await mileage.setAllowanceForYear(2026, 3000);
    entry = (await db.select(db.mileageEntries).get()).firstWhere((e) => e.date.startsWith('2026'));
    expect(entry.allowancePaid, const Ore.kr(300));
    s = await summary();
    expect((s.mileageTaxFree, s.mileageDeduction), (const Ore.kr(250), Ore.zero));
    // Other years keep their rate.
    final old = (await db.select(db.mileageEntries).get()).firstWhere((e) => e.date.startsWith('2025'));
    expect(old.allowanceOrePerMil, 2000);

    // No allowance: the standard amount is the deduction.
    await mileage.setAllowanceForYear(2026, null);
    s = await summary();
    expect((s.mileageTaxFree, s.mileageDeduction), (Ore.zero, const Ore.kr(250)));
  });
}
