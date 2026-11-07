// Commuting deduction (resor till och från arbetet), income year 2026.
// Hand-checked: 2026 has 261 weekdays; 10 holidays or eves fall on one
// (1 Jan, 6 Jan, 3 Apr, 6 Apr, 1 May, 14 May, 19 Jun, 24, 25 and 31 Dec),
// so a Monday–Friday commuter has 251 commuting days.
import 'package:test/test.dart';
import 'package:trakta_core/trakta_core.dart';

import 'helpers.dart';

const car = 1;
const ownCar = VehicleInput(ownership: Ownership.own, powertrain: Powertrain.fossil);

CommuteRouteInput route({int id = 1, int oneWayKm = 30, VehicleInput vehicle = ownCar, Set<int>? weekdays}) =>
    CommuteRouteInput(
      id: id,
      vehicleId: car,
      vehicle: vehicle,
      oneWayMetres: oneWayKm * 1000,
      weekdays: weekdays ?? {1, 2, 3, 4, 5},
      from: d('2026-01-01'),
    );

CommuteResult calc(CommuteInput input) => CommuteCalculator.calculate(input, loadPack(2026));

/// Business driving with [car] on every commuting day of the given months.
ServiceDriving serviceIn(Set<int> months, {int mil = 400}) {
  final all = calc(CommuteInput(year: 2026, routes: [route()]));
  return ServiceDriving(
    metres: mil * 10000,
    days: {for (final d in all.days) if (months.contains(d.date.month)) d.date},
  );
}

CommuteExpenseInput parking({int kr = 800}) => CommuteExpenseInput(
      id: 9,
      kind: CommuteExpenseKind.parking,
      amountOre: kr * 100,
      recurrence: ExpenseRecurrence.monthly,
      from: d('2026-01-01'),
    );

void main() {
  test('Swedish holidays 2026', () {
    final h = SwedishHolidays.of(2026);
    expect(SwedishHolidays.easterSunday(2026), d('2026-04-05'));
    expect(h[d('2026-04-03')], SwedishHoliday.goodFriday);
    expect(h[d('2026-05-14')], SwedishHoliday.ascensionDay);
    expect(h[d('2026-06-19')], SwedishHoliday.midsummerEve);
    expect(h[d('2026-06-20')], SwedishHoliday.midsummerDay);
    expect(h[d('2026-10-31')], SwedishHoliday.allSaintsDay);
    expect(SwedishHolidays.easterSunday(2027), d('2027-03-28'));
  });

  test('a full year Monday–Friday, 30 km each way, own car', () {
    final r = calc(CommuteInput(year: 2026, routes: [route()]));
    expect(r.days, hasLength(251));
    expect(r.skipped.where((s) => s.skip == CommuteSkip.publicHoliday), hasLength(10));
    expect(r.metres, 251 * 60000); // 1 506 mil
    expect(r.mileage, const Ore.kr(37650)); // × 25 kr
    expect(r.threshold, const Ore.kr(15000));
    expect(r.total, const Ore.kr(37650)); // what goes in box 2.1
    expect(r.deductible, const Ore.kr(22650));
  });

  test('marked days, business trips and an extra day change the count', () {
    final r = calc(CommuteInput(
      year: 2026,
      routes: [route()],
      overrides: {
        for (final day in CalendarDate.range(d('2026-07-06'), d('2026-07-31')))
          day: CommuteDayOverride.notCommuted(day, NoCommuteReason.vacation),
        d('2026-03-07'): CommuteDayOverride.commuted(d('2026-03-07'), oneWayMetres: 40000), // a Saturday
      },
      businessTripDays: {d('2026-03-03'), d('2026-03-04')},
    ));
    expect(r.skipped.where((s) => s.skip == CommuteSkip.marked), hasLength(20));
    expect(r.skipped.where((s) => s.skip == CommuteSkip.businessTrip), hasLength(2));
    expect(r.days, hasLength(251 - 20 - 2 + 1));
    expect(r.days.singleWhere((x) => x.extra).metres, 80000);
  });

  test('under 5 km: no mileage and no fees', () {
    final r = calc(CommuteInput(
      year: 2026,
      routes: [route(oneWayKm: 4)],
      expenses: [
        CommuteExpenseInput(
          id: 1,
          kind: CommuteExpenseKind.congestionTax,
          amountOre: 90000,
          recurrence: ExpenseRecurrence.once,
          from: d('2026-02-28'),
        ),
      ],
    ));
    expect(r.days, hasLength(251)); // still days, but they give nothing
    expect(r.mileage, Ore.zero);
    expect(r.routes.single.reasons.first.code, ReasonCode.commuteRouteTooShort);
    expect(r.fees, Ore.zero);
    expect(r.expenses.single.reasons.single.code, ReasonCode.commuteFeeNoCarDeduction);
  });

  test('company car with fuel paid by the employer gives no mileage', () {
    const company = VehicleInput(ownership: Ownership.company, powertrain: Powertrain.fossil, employerPaysFuel: true);
    expect(calc(CommuteInput(year: 2026, routes: [route(vehicle: company)])).mileage, Ore.zero);
  });

  test('congestion tax invoices and a bridge fee per commuting day count', () {
    final r = calc(CommuteInput(
      year: 2026,
      routes: [route()],
      expenses: [
        CommuteExpenseInput(
          id: 1,
          kind: CommuteExpenseKind.congestionTax,
          amountOre: 110500,
          recurrence: ExpenseRecurrence.once,
          from: d('2026-02-28'),
        ),
        CommuteExpenseInput(
          id: 2,
          kind: CommuteExpenseKind.bridgeToll,
          amountOre: 1000,
          recurrence: ExpenseRecurrence.perCommuteDay,
          from: d('2026-01-01'),
          to: d('2026-01-31'),
          routeId: 1,
        ),
        CommuteExpenseInput(
          id: 3,
          kind: CommuteExpenseKind.congestionTax,
          amountOre: 50000,
          recurrence: ExpenseRecurrence.once,
          from: d('2025-12-31'), // another year
        ),
      ],
    ));
    expect(r.expenses.map((e) => e.counted), [const Ore.kr(1105), const Ore.kr(200)]); // 20 January days
    expect(r.fees, const Ore.kr(1305));
    expect(r.total, const Ore.kr(37650 + 1305));
  });

  group('parking needs business driving with the same car', () {
    test('without business driving it does not count', () {
      final r = calc(CommuteInput(year: 2026, routes: [route()], expenses: [parking()]));
      expect(r.parking[car]!.status, ParkingStatus.notMet);
      expect(r.parkingEntered, const Ore.kr(9600));
      expect(r.parkingCounted, Ore.zero);
      expect(r.expenses.single.reasons.single.code, ReasonCode.commuteParkingNotMet);
    });

    test('300 mil but too few days still does not count', () {
      final r = calc(CommuteInput(
        year: 2026,
        routes: [route()],
        expenses: [parking()],
        serviceDriving: {car: serviceIn({1})}, // 20 days
      ));
      expect(r.parking[car]!.status, ParkingStatus.notMet);
      expect(r.parkingCounted, Ore.zero);
    });

    test('at least 60 days: parking on the days the car was used in the job', () {
      final r = calc(CommuteInput(
        year: 2026,
        routes: [route()],
        expenses: [parking()],
        serviceDriving: {car: serviceIn({1, 2, 3})}, // 20 + 20 + 22 = 62 days
      ));
      expect(r.parking[car]!.status, ParkingStatus.serviceDaysOnly);
      expect(r.parkingCounted, const Ore.kr(3 * 800)); // January–March in full, nothing after
    });

    test('at least 160 days: parking on all commuting days', () {
      final r = calc(CommuteInput(
        year: 2026,
        routes: [route()],
        expenses: [parking()],
        serviceDriving: {car: serviceIn({1, 2, 3, 4, 5, 6, 7, 8, 9})},
      ));
      expect(r.parking[car]!.status, ParkingStatus.allDays);
      expect(r.parkingCounted, const Ore.kr(9600));
    });

    test('enough days but under 300 mil does not count', () {
      final r = calc(CommuteInput(
        year: 2026,
        routes: [route()],
        expenses: [parking()],
        serviceDriving: {car: serviceIn({1, 2, 3, 4, 5, 6, 7, 8, 9}, mil: 299)},
      ));
      expect(r.parkingCounted, Ore.zero);
    });
  });

  test('"so far": only days and monthly costs up to a date', () {
    final r = calc(CommuteInput(
      year: 2026,
      routes: [route()],
      expenses: [parking()],
      serviceDriving: {car: serviceIn({1, 2, 3, 4, 5, 6, 7, 8, 9})},
      until: d('2026-03-31'),
    ));
    expect(r.days, hasLength(20 + 20 + 22));
    expect(r.parkingEntered, const Ore.kr(3 * 800)); // January–March only
  });

  test('no rules pack for the year: days only', () {
    final r = CommuteCalculator.calculate(const CommuteInput(year: 2026, routes: []), null);
    expect(r.noRules, isTrue);
    expect(r.total, Ore.zero);
  });
}
