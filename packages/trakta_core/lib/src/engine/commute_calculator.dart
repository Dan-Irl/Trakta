import '../explain/reason.dart';
import '../model/calendar_date.dart';
import '../model/commute.dart';
import '../model/enums.dart';
import '../model/swedish_holidays.dart';
import '../money/ore.dart';
import '../rules/rules_pack.dart';
import 'mileage_calculator.dart';

/// Why a scheduled commuting day was not counted.
enum CommuteSkip { publicHoliday, businessTrip, marked }

/// One day the user commuted (a round trip).
final class CommuteDay {
  const CommuteDay({
    required this.date,
    required this.routeId,
    required this.metres,
    required this.counts,
    this.extra = false,
  });

  final CalendarDate date;
  final int routeId;

  /// Round trip.
  final int metres;

  /// Whether the day's mileage counts toward the deduction: the route is
  /// long enough and the car's fuel is paid by the user.
  final bool counts;

  /// Not on the schedule; added by the user.
  final bool extra;
}

/// A scheduled day that was not commuted, and why.
final class SkippedCommuteDay {
  const SkippedCommuteDay({required this.date, required this.skip, this.holiday, this.reason});

  final CalendarDate date;
  final CommuteSkip skip;
  final SwedishHoliday? holiday;
  final NoCommuteReason? reason;
}

/// Whether commuting parking is deductible this year (see
/// [CommuteParkingRules]).
enum ParkingStatus {
  /// Business driving with the car is below the limits: no parking.
  notMet,

  /// Enough business driving over enough days: parking on the days the car
  /// was also used in the job.
  serviceDaysOnly,

  /// Business driving on enough days: parking on every commuting day.
  allDays,
}

/// The parking check for one car, with the numbers behind it so the UI can
/// say how far the user is from the limits.
final class ParkingCheck {
  const ParkingCheck({
    required this.vehicleId,
    required this.status,
    required this.serviceMetres,
    required this.serviceDays,
    required this.rules,
  });

  final int vehicleId;
  final ParkingStatus status;
  final int serviceMetres;
  final int serviceDays;
  final CommuteParkingRules rules;
}

/// One commuting cost for the year: what was entered and what counts.
final class CommuteExpenseResult {
  const CommuteExpenseResult({
    required this.expenseId,
    required this.kind,
    required this.entered,
    required this.counted,
    required this.reasons,
  });

  final int expenseId;
  final CommuteExpenseKind kind;
  final Ore entered;
  final Ore counted;
  final List<Reason> reasons;
}

final class CommuteRouteResult {
  const CommuteRouteResult({
    required this.routeId,
    required this.days,
    required this.metres,
    required this.amount,
    required this.reasons,
  });

  final int routeId;
  final int days;

  /// Round trips on counting days.
  final int metres;
  final Ore amount;
  final List<Reason> reasons;
}

/// The commuting deduction (resor till och från arbetet) for one income year.
final class CommuteResult {
  const CommuteResult({
    required this.year,
    required this.noRules,
    required this.days,
    required this.skipped,
    required this.routes,
    required this.expenses,
    required this.parking,
    required this.threshold,
  });

  final int year;

  /// No rules pack for [year]: days are listed but nothing is calculated.
  final bool noRules;
  final List<CommuteDay> days;
  final List<SkippedCommuteDay> skipped;
  final List<CommuteRouteResult> routes;
  final List<CommuteExpenseResult> expenses;

  /// Per car used for commuting.
  final Map<int, ParkingCheck> parking;

  /// Only costs above this are deductible (beloppsgräns).
  final Ore threshold;

  int get metres => routes.fold(0, (n, r) => n + r.metres);
  Ore get mileage => Ore.sum(routes.map((r) => r.amount));
  Ore get fees => Ore.sum(expenses.where((e) => !e.kind.isParking).map((e) => e.counted));
  Ore get parkingEntered => Ore.sum(expenses.where((e) => e.kind.isParking).map((e) => e.entered));
  Ore get parkingCounted => Ore.sum(expenses.where((e) => e.kind.isParking).map((e) => e.counted));

  /// The amount to enter in box 2.1: all costs, before the threshold.
  /// Skatteverket subtracts the threshold itself.
  Ore get total => mileage + fees + parkingCounted;

  /// The part that actually lowers taxable income.
  Ore get deductible => Ore.max(total - threshold, Ore.zero);
}

/// Commuting between home and the regular workplace.
abstract final class CommuteCalculator {
  static CommuteResult calculate(CommuteInput t, RulesPack? r) {
    final year = t.year;
    final holidays = SwedishHolidays.of(year);
    final routes = [...t.routes]..sort((a, b) => a.id.compareTo(b.id));
    final byId = {for (final route in routes) route.id: route};
    final minMetres = (r?.commute.carMinKm ?? 0) * 1000;

    CommuteRouteInput? scheduled(CalendarDate d) =>
        routes.where((x) => x.activeOn(d) && x.weekdays.contains(d.weekday)).firstOrNull;

    bool fuelOk(CommuteRouteInput route, CalendarDate d) {
      final v = route.vehicle;
      if (v.ownership != Ownership.company || !v.employerPaysFuel) return true;
      return r != null && MileageCalculator.hybridChargingException(v, d, r);
    }

    // 1. Days: the schedule, minus holidays, business trips and days the
    //    user marked, plus days the user added.
    final days = <CommuteDay>[];
    final skipped = <SkippedCommuteDay>[];
    final yearEnd = CalendarDate(year, 12, 31);
    final end = t.until == null || t.until!.isAfter(yearEnd) ? yearEnd : t.until!;
    for (final d in CalendarDate.range(CalendarDate(year, 1, 1), end)) {
      final override = t.overrides[d];
      final planned = scheduled(d);
      if (override != null && override.commuted) {
        final route = byId[override.routeId] ??
            planned ??
            routes.where((x) => x.activeOn(d)).firstOrNull ??
            routes.firstOrNull;
        if (route == null) continue;
        final oneWay = override.oneWayMetres ?? route.oneWayMetres;
        days.add(CommuteDay(
          date: d,
          routeId: route.id,
          metres: 2 * oneWay,
          counts: oneWay >= minMetres && fuelOk(route, d),
          extra: planned == null,
        ));
        continue;
      }
      if (planned == null) continue;
      if (override != null) {
        skipped.add(SkippedCommuteDay(date: d, skip: CommuteSkip.marked, reason: override.reason));
      } else if (holidays[d] case final h?) {
        skipped.add(SkippedCommuteDay(date: d, skip: CommuteSkip.publicHoliday, holiday: h));
      } else if (t.businessTripDays.contains(d)) {
        skipped.add(SkippedCommuteDay(date: d, skip: CommuteSkip.businessTrip));
      } else {
        days.add(CommuteDay(
          date: d,
          routeId: planned.id,
          metres: 2 * planned.oneWayMetres,
          counts: planned.oneWayMetres >= minMetres && fuelOk(planned, d),
        ));
      }
    }

    final threshold = r == null ? Ore.zero : Ore.kr(r.commute.thresholdKr);
    if (r == null) {
      return CommuteResult(
        year: year,
        noRules: true,
        days: days,
        skipped: skipped,
        routes: const [],
        expenses: const [],
        parking: const {},
        threshold: threshold,
      );
    }

    // 2. Mileage per route: round trips on counting days × rate per mil.
    final routeResults = <CommuteRouteResult>[];
    for (final route in routes) {
      final mine = days.where((d) => d.routeId == route.id).toList();
      if (mine.isEmpty) continue;
      final key = MileageCalculator.rateKey(route.vehicle);
      final orePerMil = r.commute.orePerMil[key] ?? 0;
      final counting = mine.where((d) => d.counts);
      final metres = counting.fold(0, (n, d) => n + d.metres);
      final amount = Ore(orePerMil).times(metres, 10000);
      routeResults.add(CommuteRouteResult(
        routeId: route.id,
        days: mine.length,
        metres: metres,
        amount: amount,
        reasons: [
          if (route.oneWayMetres < minMetres)
            Reason(ReasonCode.commuteRouteTooShort, {'minKm': r.commute.carMinKm}, _source),
          if (mine.any((d) => !d.counts) && route.oneWayMetres >= minMetres)
            const Reason(ReasonCode.mileageEmployerPaysFuel),
          if (metres > 0)
            Reason(ReasonCode.commuteRate, {
              'days': counting.length,
              'metres': metres,
              'orePerMil': orePerMil,
              'amount': amount.value,
            }, _source),
        ],
      ));
    }

    // 3. Parking: the business-driving check for every car used to commute.
    final parking = <int, ParkingCheck>{};
    for (final vehicleId in {for (final d in days) byId[d.routeId]!.vehicleId}) {
      final service = t.serviceDriving[vehicleId] ?? const ServiceDriving();
      final p = r.commute.parking;
      final enoughMil = service.metres >= p.minServiceMil * 10000;
      final status = !enoughMil
          ? ParkingStatus.notMet
          : service.days.length >= p.minServiceDaysForAllDays
              ? ParkingStatus.allDays
              : service.days.length >= p.minServiceDaysForServiceDays
                  ? ParkingStatus.serviceDaysOnly
                  : ParkingStatus.notMet;
      parking[vehicleId] = ParkingCheck(
        vehicleId: vehicleId,
        status: status,
        serviceMetres: service.metres,
        serviceDays: service.days.length,
        rules: p,
      );
    }
    // Costs without a route belong to the car used on most commuting days.
    final mainVehicle = _mostCommon([for (final d in days) byId[d.routeId]!.vehicleId]);

    // 4. Costs.
    final expenses = [
      for (final e in t.expenses) _expense(e, year, end, days, byId, routeResults, minMetres, parking, mainVehicle, t),
    ].whereType<CommuteExpenseResult>().toList();

    return CommuteResult(
      year: year,
      noRules: false,
      days: days,
      skipped: skipped,
      routes: routeResults,
      expenses: expenses,
      parking: parking,
      threshold: threshold,
    );
  }

  static const _source =
      'https://www.skatteverket.se/privat/skatter/bilochtrafik/avdragforresortillochfranarbetet.4.3810a01c150939e893f25603.html';
  static const _parkingSource =
      'https://www.skatteverket.se/privat/skatter/arbeteochinkomst/avdragforprivatpersoner/np.4.5fc8c94513259a4ba1d800042822.html';

  /// What one cost amounts to in [year], and how much of it counts. Null
  /// when it has nothing in the year.
  static CommuteExpenseResult? _expense(
    CommuteExpenseInput e,
    int year,
    CalendarDate end,
    List<CommuteDay> days,
    Map<int, CommuteRouteInput> routes,
    List<CommuteRouteResult> routeResults,
    int minMetres,
    Map<int, ParkingCheck> parking,
    int? mainVehicle,
    CommuteInput t,
  ) {
    bool inPeriod(CalendarDate d) => d.isOnOrAfter(e.from) && (e.to == null || d.isOnOrBefore(e.to!));
    final myDays = [
      for (final d in days)
        if (d.date.year == year && inPeriod(d.date) && (e.routeId == null || d.routeId == e.routeId)) d,
    ];

    // Each payment with the commuting days it covers (for parking by day).
    final payments = <({Ore amount, List<CommuteDay> covers, CalendarDate? date})>[];
    final amount = Ore(e.amountOre);
    switch (e.recurrence) {
      case ExpenseRecurrence.once:
        if (e.from.year == year && e.from.isOnOrBefore(end)) {
          payments.add((amount: amount, covers: const [], date: e.from));
        }
      case ExpenseRecurrence.monthly:
        for (var m = 1; m <= end.month; m++) {
          final first = CalendarDate(year, m, 1);
          final last = CalendarDate(year, m + 1, 1).previous;
          // A month counts when the period has started by its end and has not
          // ended before its start.
          if (last.isBefore(e.from) || (e.to != null && first.isAfter(e.to!))) continue;
          payments.add((
            amount: amount,
            covers: [for (final d in myDays) if (d.date.month == m) d],
            date: null,
          ));
        }
      case ExpenseRecurrence.perCommuteDay:
        for (final d in myDays) {
          payments.add((amount: amount, covers: [d], date: d.date));
        }
    }
    if (payments.isEmpty) return null;
    final entered = Ore.sum(payments.map((p) => p.amount));

    // Fees follow the car deduction: they count when the route qualifies.
    if (!e.kind.isParking) {
      final route = e.routeId == null ? null : routes[e.routeId];
      final carDeduction = route != null
          ? route.oneWayMetres >= minMetres
          : routeResults.any((x) => x.amount > Ore.zero);
      return CommuteExpenseResult(
        expenseId: e.id,
        kind: e.kind,
        entered: entered,
        counted: carDeduction ? entered : Ore.zero,
        reasons: [
          carDeduction
              ? const Reason(ReasonCode.commuteFeeCounted, {}, _source)
              : Reason(ReasonCode.commuteFeeNoCarDeduction, {'minKm': minMetres ~/ 1000}, _source),
        ],
      );
    }

    // Parking follows the business-driving check for its car.
    final vehicleId = e.routeId != null ? routes[e.routeId]?.vehicleId : mainVehicle;
    final check = vehicleId == null ? null : parking[vehicleId];
    final params = {
      'mil': (check?.serviceMetres ?? 0) ~/ 10000,
      'days': check?.serviceDays ?? 0,
      'minMil': check?.rules.minServiceMil ?? 0,
      'minDays': check?.rules.minServiceDaysForServiceDays ?? 0,
      'allDays': check?.rules.minServiceDaysForAllDays ?? 0,
    };
    switch (check?.status) {
      case null || ParkingStatus.notMet:
        return CommuteExpenseResult(
          expenseId: e.id,
          kind: e.kind,
          entered: entered,
          counted: Ore.zero,
          reasons: [Reason(ReasonCode.commuteParkingNotMet, params, _parkingSource)],
        );
      case ParkingStatus.allDays:
        return CommuteExpenseResult(
          expenseId: e.id,
          kind: e.kind,
          entered: entered,
          counted: entered,
          reasons: [Reason(ReasonCode.commuteParkingAllDays, params, _parkingSource)],
        );
      case ParkingStatus.serviceDaysOnly:
        // Only the days the car was also used in the job. A monthly cost is
        // shared evenly over that month's commuting days.
        final service = t.serviceDriving[vehicleId]?.days ?? const {};
        var counted = Ore.zero;
        for (final p in payments) {
          if (p.covers.isEmpty) {
            if (p.date != null && service.contains(p.date)) counted += p.amount;
            continue;
          }
          final used = p.covers.where((d) => service.contains(d.date)).length;
          counted += p.amount.times(used, p.covers.length);
        }
        return CommuteExpenseResult(
          expenseId: e.id,
          kind: e.kind,
          entered: entered,
          counted: counted,
          reasons: [Reason(ReasonCode.commuteParkingServiceDaysOnly, params, _parkingSource)],
        );
    }
  }

  static int? _mostCommon(List<int> xs) {
    final counts = <int, int>{};
    for (final x in xs) {
      counts[x] = (counts[x] ?? 0) + 1;
    }
    return counts.entries.fold<MapEntry<int, int>?>(null, (best, e) => best == null || e.value > best.value ? e : best)?.key;
  }
}
