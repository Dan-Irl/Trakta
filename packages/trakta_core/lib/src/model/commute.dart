import 'calendar_date.dart';
import 'enums.dart';
import 'mileage.dart';

/// A regular trip between home and the regular workplace (resor till och från
/// arbetet, box 2.1). Not a business trip: driving in the job is business
/// driving (körjournal, box 2.2) and never commuting.
final class CommuteRouteInput {
  const CommuteRouteInput({
    required this.id,
    required this.vehicleId,
    required this.vehicle,
    required this.oneWayMetres,
    required this.weekdays,
    required this.from,
    this.to,
  });

  final int id;
  final int vehicleId;
  final VehicleInput vehicle;

  /// Home to workplace by the shortest route. A commuting day is the round
  /// trip, twice this.
  final int oneWayMetres;

  /// ISO weekdays the user normally commutes (1 = Monday).
  final Set<int> weekdays;
  final CalendarDate from;

  /// Last commuting day on this route; null while it is still in use.
  final CalendarDate? to;

  bool activeOn(CalendarDate d) => d.isOnOrAfter(from) && (to == null || d.isOnOrBefore(to!));
}

/// A change to the schedule on one date: a day not commuted (vacation, sick,
/// home office), or a commute on a day that is not scheduled.
final class CommuteDayOverride {
  const CommuteDayOverride.notCommuted(this.date, this.reason)
      : commuted = false,
        routeId = null,
        oneWayMetres = null;

  const CommuteDayOverride.commuted(this.date, {this.routeId, this.oneWayMetres})
      : commuted = true,
        reason = null;

  final CalendarDate date;
  final bool commuted;
  final NoCommuteReason? reason;

  /// Only when [commuted]: the route used (else the day's scheduled route)
  /// and a different one-way distance for that day.
  final int? routeId;
  final int? oneWayMetres;
}

/// A cost of commuting besides the mileage. Recurring costs are stored once
/// and expanded over the period by the engine.
final class CommuteExpenseInput {
  const CommuteExpenseInput({
    required this.id,
    required this.kind,
    required this.amountOre,
    required this.recurrence,
    required this.from,
    this.to,
    this.routeId,
  });

  final int id;
  final CommuteExpenseKind kind;

  /// Per payment, per month or per commuting day, see [recurrence].
  final int amountOre;
  final ExpenseRecurrence recurrence;

  /// The payment date for [ExpenseRecurrence.once], otherwise the first day
  /// of the period.
  final CalendarDate from;
  final CalendarDate? to;

  /// The route the cost belongs to, when the user has more than one.
  final int? routeId;
}

/// Business driving (körjournal) with one car during the year. Decides
/// whether commuting parking is deductible.
final class ServiceDriving {
  const ServiceDriving({this.metres = 0, this.days = const {}});

  final int metres;

  /// Dates with at least one business drive.
  final Set<CalendarDate> days;
}

final class CommuteInput {
  const CommuteInput({
    required this.year,
    required this.routes,
    this.overrides = const {},
    this.businessTripDays = const {},
    this.expenses = const [],
    this.serviceDriving = const {},
    this.until,
  });

  final int year;

  /// Count only up to this date (inclusive), e.g. today for "so far". Null
  /// counts the whole year, which for the current year is a projection from
  /// the schedule.
  final CalendarDate? until;
  final List<CommuteRouteInput> routes;
  final Map<CalendarDate, CommuteDayOverride> overrides;

  /// Dates spent entirely away on a business trip: no commute.
  final Set<CalendarDate> businessTripDays;
  final List<CommuteExpenseInput> expenses;

  /// Business driving per vehicle id.
  final Map<int, ServiceDriving> serviceDriving;
}
