import 'package:trakta_core/trakta_core.dart';

import '../db/database.dart';
import '../repositories/commute_repository.dart';
import '../repositories/mileage_repository.dart';
import '../repositories/trip_repository.dart';

/// Builds the engine input for one income year from what is stored. The
/// three travel types meet here: business trips remove commuting days, and
/// business driving with the same car decides whether parking counts.
abstract final class CommuteCalculations {
  static CommuteResult compute(
    int year,
    CommuteData data,
    List<VehicleRow> vehicles,
    List<MileageEntryRow> drives,
    List<TripBundle> trips,
    RulesLibrary library, {
    CalendarDate? until,
  }) =>
      CommuteCalculator.calculate(toInput(year, data, vehicles, drives, trips, until: until), library.forYear(year));

  static CommuteInput toInput(
    int year,
    CommuteData data,
    List<VehicleRow> vehicles,
    List<MileageEntryRow> drives,
    List<TripBundle> trips, {
    CalendarDate? until,
  }) {
    final vehicleById = {for (final v in vehicles) v.id: v};
    final service = <int, ({int metres, Set<CalendarDate> days})>{};
    for (final e in drives) {
      final date = CalendarDate.parse(e.date);
      if (date.year != year) continue;
      final s = service[e.vehicleId] ?? (metres: 0, days: <CalendarDate>{});
      service[e.vehicleId] = (metres: s.metres + e.distanceM, days: s.days..add(date));
    }
    return CommuteInput(
      year: year,
      until: until,
      routes: [
        for (final r in data.routes)
          if (vehicleById[r.vehicleId] case final v?)
            CommuteRouteInput(
              id: r.id,
              vehicleId: r.vehicleId,
              vehicle: v.toInput(),
              oneWayMetres: r.oneWayM,
              weekdays: parseWorkDays(r.workDays),
              from: CalendarDate.parse(r.startDate),
              to: r.endDate == null ? null : CalendarDate.parse(r.endDate!),
            ),
      ],
      overrides: {
        for (final d in data.days)
          CalendarDate.parse(d.date): d.commuted
              ? CommuteDayOverride.commuted(CalendarDate.parse(d.date), routeId: d.routeId, oneWayMetres: d.oneWayM)
              : CommuteDayOverride.notCommuted(CalendarDate.parse(d.date), d.reason ?? NoCommuteReason.other),
      },
      businessTripDays: {for (final t in trips) ...awayAllDay(t)},
      expenses: [
        for (final e in data.expenses)
          CommuteExpenseInput(
            id: e.id,
            kind: e.kind,
            amountOre: e.amountOre,
            recurrence: e.recurrence,
            from: CalendarDate.parse(e.fromDate),
            to: e.toDate == null ? null : CalendarDate.parse(e.toDate!),
            routeId: e.routeId,
          ),
      ],
      serviceDriving: {
        for (final MapEntry(:key, :value) in service.entries)
          key: ServiceDriving(metres: value.metres, days: value.days),
      },
    );
  }

  /// Dates spent entirely away on a trip: the days between departure and
  /// return. Those two days are kept, since the user may have gone to the
  /// workplace first or after.
  static Iterable<CalendarDate> awayAllDay(TripBundle t) {
    final first = CalendarDate.of(t.departureWall);
    final last = CalendarDate.of(t.returnWall);
    if (last.daysUntil(first).abs() < 2) return const [];
    return CalendarDate.range(first.next, last.previous);
  }
}
