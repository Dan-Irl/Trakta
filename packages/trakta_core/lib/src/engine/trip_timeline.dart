import '../explain/reason.dart';
import '../model/calendar_date.dart';
import '../model/enums.dart';
import '../model/trip.dart';
import '../rules/rules_pack.dart';

/// Calendar days and nights of a trip, and the eligibility checks
/// (docs/tax-rules.md).
abstract final class TripTimeline {
  /// The last calendar date the trip touches. A trip that ends exactly at
  /// midnight does not touch the new date.
  static CalendarDate lastDate(TripInput t) {
    final r = t.returnTime;
    final d = CalendarDate.of(r);
    if (r.hour == 0 && r.minute == 0 && d.isAfter(t.firstDate)) return d.previous;
    return d;
  }

  static bool _returnsAtMidnight(TripInput t) =>
      t.returnTime.hour == 0 && t.returnTime.minute == 0 && CalendarDate.of(t.returnTime).isAfter(t.firstDate);

  /// All local calendar dates of the trip, first to last inclusive.
  static List<CalendarDate> days(TripInput t) {
    if (!t.returnTime.isAfter(t.departure)) return const [];
    return CalendarDate.range(t.firstDate, lastDate(t)).toList();
  }

  /// Evening dates D such that the trip covers D+1 00:00–06:00 in full.
  /// The night allowance for that night is keyed by D (the day whose
  /// `lodging` input describes it).
  static List<CalendarDate> nights(TripInput t) {
    final result = <CalendarDate>[];
    for (var d = t.firstDate; d.isBefore(CalendarDate.of(t.returnTime)); d = d.next) {
      final midnight = d.next.start;
      final six = d.next.at(6);
      if (!t.departure.isAfter(midnight) && !t.returnTime.isBefore(six)) result.add(d);
    }
    return result;
  }

  /// Eligibility: business trip, more than 50 km away, and an overnight stay.
  static ({bool eligible, List<Reason> reasons}) eligibility(TripInput t) {
    final reasons = <Reason>[];
    if (!t.isBusinessTrip) reasons.add(const Reason(ReasonCode.notEligibleNotBusinessTrip));
    if (!t.outside50km) reasons.add(const Reason(ReasonCode.notEligibleWithin50km));
    if (!t.nightWorker && nights(t).isEmpty) {
      reasons.add(const Reason(ReasonCode.notEligibleNoOvernight, {}, Sources.traktamente));
    }
    if (reasons.isEmpty) return (eligible: true, reasons: const [Reason(ReasonCode.eligible)]);
    return (eligible: false, reasons: reasons);
  }

  /// Full or half day for one calendar date of the trip.
  static ({DayType type, List<Reason> reasons}) dayType(CalendarDate d, TripInput t, RulesPack r) {
    final reasons = <Reason>[];
    var full = true;
    if (d == t.firstDate) {
      final dep = t.departure.hour * 60 + t.departure.minute;
      final limit = r.dayType.departureFullIfBefore;
      if (dep < limit.minutes) {
        reasons.add(Reason(ReasonCode.departureBeforeNoon,
            {'time': WallTime.format(t.departure), 'limit': limit.toString()}));
      } else {
        full = false;
        reasons.add(Reason(ReasonCode.departureAtOrAfterNoon,
            {'time': WallTime.format(t.departure), 'limit': limit.toString()}));
      }
    }
    if (d == lastDate(t)) {
      final limit = r.dayType.returnFullIfAfter;
      if (_returnsAtMidnight(t)) {
        reasons.add(Reason(ReasonCode.returnAfter19, {'time': '24:00', 'limit': limit.toString()}));
      } else {
        final ret = t.returnTime.hour * 60 + t.returnTime.minute;
        if (ret > limit.minutes) {
          reasons.add(Reason(ReasonCode.returnAfter19,
              {'time': WallTime.format(t.returnTime), 'limit': limit.toString()}));
        } else {
          full = false;
          reasons.add(Reason(ReasonCode.returnAtOrBefore19,
              {'time': WallTime.format(t.returnTime), 'limit': limit.toString()}));
        }
      }
    }
    if (reasons.isEmpty) reasons.add(const Reason(ReasonCode.wholeDayAway));
    return (type: full ? DayType.full : DayType.half, reasons: reasons);
  }
}
