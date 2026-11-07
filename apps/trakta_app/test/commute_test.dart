// Commuting (reseavdrag): set up once, days from the schedule, and how
// business trips and business driving affect it.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/data/calculation/commute_calculations.dart';
import 'package:trakta_app/data/db/database.dart';
import 'package:trakta_app/data/repositories/commute_repository.dart';
import 'package:trakta_app/data/repositories/mileage_repository.dart';
import 'package:trakta_app/data/repositories/trip_repository.dart';
import 'package:trakta_app/features/common/format.dart';
import 'package:trakta_app/features/commute/commute_calendar.dart';
import 'package:trakta_core/trakta_core.dart';

import 'test_rules.dart';
import 'widget_helpers.dart';

Future<int> addCar(AppDatabase db, {String registration = ''}) => MileageRepository(db).saveVehicle(
      VehiclesCompanion.insert(
        label: 'Volvo',
        registration: Value(registration),
        ownership: Ownership.own,
        powertrain: Powertrain.fossil,
      ),
    );

void main() {
  test('business trips remove commuting days; business driving decides parking', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final car = await addCar(db);
    final commute = CommuteRepository(db);
    await commute.saveRoute(CommuteRoutesCompanion.insert(
      label: const Value('Hem – Kontor'),
      vehicleId: car,
      oneWayM: 30000,
      startDate: '2026-01-01',
      createdUtc: DateTime.now().toUtc(),
    ));
    await commute.saveExpense(CommuteExpensesCompanion.insert(
      kind: CommuteExpenseKind.parking,
      recurrence: ExpenseRecurrence.monthly,
      amountOre: 80000,
      fromDate: '2026-01-01',
      createdUtc: DateTime.now().toUtc(),
    ));
    await commute.markNotCommuted(CalendarDate.parse('2026-07-06'), CalendarDate.parse('2026-07-10'),
        NoCommuteReason.vacation);
    // A business trip Monday–Friday: Tuesday to Thursday are spent away.
    await TripRepository(db).save(TripDraft(
      purpose: 'Mässa',
      departure: WallTime.parse('2026-03-02T07:00'),
      returnTime: WallTime.parse('2026-03-06T20:00'),
      confirmedBusinessTrip: true,
      confirmed50km: true,
      employerPaysPerDiem: true,
    ));

    Future<CommuteResult> calc() async => CommuteCalculations.compute(
          2026,
          await commute.load(),
          await db.select(db.vehicles).get(),
          await db.select(db.mileageEntries).get(),
          await TripRepository(db).loadAll(),
          testLibrary(),
        );

    var r = await calc();
    expect(r.skipped.where((s) => s.skip == CommuteSkip.businessTrip).map((s) => s.date.toIso()),
        ['2026-03-03', '2026-03-04', '2026-03-05']);
    expect(r.skipped.where((s) => s.skip == CommuteSkip.marked), hasLength(5));
    expect(r.days, hasLength(251 - 3 - 5));
    expect(r.parking[car]!.status, ParkingStatus.notMet);
    expect(r.parkingCounted, Ore.zero);

    // 170 days of business driving with the same car, 10 km each (340 mil).
    final mileage = MileageRepository(db);
    for (final d in r.days.take(170)) {
      await mileage.saveEntry(MileageEntriesCompanion.insert(
        date: d.date.toIso(),
        vehicleId: car,
        distanceM: 20000,
        createdUtc: DateTime.now().toUtc(),
      ));
    }
    r = await calc();
    expect(r.parking[car]!.status, ParkingStatus.allDays);
    expect(r.parkingCounted, const Ore.kr(12 * 800));
  });

  testWidgets('set up a commute, add parking, see the requirement', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'));
    await addCar(db);
    await openTab(tester, 'Commuting');
    await pumpUntilFound(tester, find.text('What counts as commuting'));

    await tester.tap(find.text('Set up my commute'));
    await pumpUntilFound(tester, find.text('Driving to work gives a deduction only if'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Home – Office');
    await tester.enterText(find.widgetWithText(TextFormField, 'Distance one way (km)'), '30');
    await tester.tap(find.text('Save'));
    // The calendar leads; box 2.1 is the next card down.
    await pumpUntilFound(tester, find.byType(CommuteMonthGrid));
    await tester.scrollUntilVisible(find.textContaining('Box 2.1'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Home – Office'), findsNothing); // routes card is further down

    await tester.tap(find.text('Add cost'));
    await pumpUntilFound(tester, find.text('New cost'));
    await tester.tap(find.text('Congestion tax (trängselskatt)'));
    await pumpUntilFound(tester, find.text('Parking').last);
    await tester.tap(find.text('Parking').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Every month'), findsOneWidget); // parking defaults to monthly
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount (SEK)'), '800');
    await tester.tap(find.text('Save'));
    await pumpUntilFound(tester, find.byType(CommuteMonthGrid));
    await tester.scrollUntilVisible(find.text('Parking needs business driving'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.scrollUntilVisible(find.text('Open business driving'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Parking does not count yet'), findsOneWidget);
    expect(find.text('Open business driving'), findsOneWidget);

    // Monthly from today: so far that is this month only.
    final entered = formatMoney('en', const Ore.kr(800));
    // In the costs: parking is entered but does not count.
    await tester.scrollUntilVisible(find.textContaining('$entered entered'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('$entered entered, ${formatMoney('en', Ore.zero)} counts'), findsOneWidget);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a route whose car was archived still opens, and can switch car', (tester) async {
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'));
    final old = await addCar(db, registration: 'ABC123');
    await CommuteRepository(db).saveRoute(CommuteRoutesCompanion.insert(
      label: const Value('Home – Office'),
      vehicleId: old,
      oneWayM: 30000,
      startDate: '2026-01-01',
      createdUtc: DateTime.now().toUtc(),
    ));
    await MileageRepository(db).archiveVehicle(old);
    await addCar(db, registration: 'XYZ789'); // a new car with the same name

    await openTab(tester, 'Commuting');
    await pumpUntilFound(tester, find.byType(CommuteMonthGrid));
    await tester.scrollUntilVisible(find.text('Home – Office'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Home – Office'));
    await pumpUntilFound(tester, find.text('Edit route'));
    expect(tester.takeException(), isNull);

    // Both the archived car (still on the route) and the new one are
    // offered, told apart by their registration.
    expect(find.text('Volvo – ABC123'), findsOneWidget);
    await tester.tap(find.text('Volvo – ABC123'));
    await pumpUntilFound(tester, find.text('Volvo – XYZ789'));
    await tester.tap(find.text('Volvo – XYZ789').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Volvo – XYZ789'), findsOneWidget);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  Future<AppDatabase> withCommute(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpApp(tester, locale: const Locale('en', 'SE'));
    final car = await addCar(db);
    await tester.runAsync(() => CommuteRepository(db).saveRoute(CommuteRoutesCompanion.insert(
          label: const Value('Home – Office'),
          vehicleId: car,
          oneWayM: 30000,
          startDate: '${DateTime.now().year}-01-01',
          createdUtc: DateTime.now().toUtc(),
        )));
    await openTab(tester, 'Commuting');
    await pumpUntilFound(tester, find.byType(CommuteMonthGrid));
    return db;
  }

  /// The stored day changes once [ready] holds (the write is asynchronous),
  /// failing after a second.
  Future<List<CommuteDayRow>> stored(WidgetTester tester, AppDatabase db, bool Function(List<CommuteDayRow>) ready) async {
    var rows = <CommuteDayRow>[];
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      rows = (await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return db.select(db.commuteDays).get();
      }))!;
      if (ready(rows)) return rows;
    }
    return rows;
  }

  testWidgets('today in one tap', (tester) async {
    final db = await withCommute(tester);
    final today = CalendarDate.of(DateTime.now()).toIso();
    await pumpUntilFound(tester, find.textContaining('Today, '));
    // The test font is wider, so lift the card clear of the floating button.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Home'));
    var rows = await stored(tester, db, (r) => r.isNotEmpty);
    expect(rows.map((r) => (r.date, r.commuted, r.reason)), [(today, false, NoCommuteReason.homeOffice)]);
    await pumpUntilFound(tester, find.byIcon(Icons.check)); // the chosen button shows a tick
    expect(find.textContaining('Worked from home'), findsOneWidget); // and the status says it

    await tester.tap(find.text('Commuted').last);
    rows = await stored(tester, db, (r) => r.isNotEmpty && r.first.commuted);
    expect(rows.map((r) => (r.date, r.commuted)), [(today, true)]);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('full calendar: press, hold and drag to mark several days', (tester) async {
    final db = await withCommute(tester);
    await tester.tap(find.byType(CommuteMonthGrid));
    await pumpUntilFound(tester, find.text('Commuting days'));
    await pumpUntilFound(tester, find.textContaining('Press, hold and drag'));

    Offset dayAt(int day) => tester.getCenter(
          find.descendant(of: find.byType(CommuteMonthGrid), matching: find.text('$day')),
        );
    final gesture = await tester.startGesture(dayAt(1));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(dayAt(3));
    await tester.pump();
    await gesture.moveTo(dayAt(5));
    await tester.pump();
    await gesture.up();
    await pumpUntilFound(tester, find.textContaining('5 days'));
    await tester.pump(const Duration(milliseconds: 500)); // let the sheet finish opening

    await tester.tap(find.text('Vacation'));
    final now = DateTime.now();
    final rows = await stored(tester, db, (r) => r.length == 5);
    expect(rows.map((r) => r.date), [
      for (var d = 1; d <= 5; d++) CalendarDate(now.year, now.month, d).toIso(),
    ]);
    expect(rows.every((r) => !r.commuted && r.reason == NoCommuteReason.vacation), isTrue);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
