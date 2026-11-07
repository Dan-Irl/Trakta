import 'package:test/test.dart';
import 'package:trakta_core/trakta_core.dart';

void main() {
  test('weekday', () {
    expect(CalendarDate.parse('2026-09-01').weekday, DateTime.tuesday);
    expect(CalendarDate.parse('2026-03-02').weekday, DateTime.monday);
  });

  test('addCalendarMonths clamps to month end', () {
    expect(const CalendarDate(2026, 1, 31).addCalendarMonths(1), const CalendarDate(2026, 2, 28));
    expect(const CalendarDate(2026, 11, 15).addCalendarMonths(3), const CalendarDate(2027, 2, 15));
    expect(const CalendarDate(2026, 9, 1).addCalendarMonths(24), const CalendarDate(2028, 9, 1));
  });

  test('range and daysUntil across DST change', () {
    final from = CalendarDate.parse('2026-03-28');
    final to = CalendarDate.parse('2026-03-30');
    expect(CalendarDate.range(from, to).length, 3);
    expect(from.daysUntil(to), 2);
  });

  test('wall time overlap', () {
    final a = WallTime.parse('2026-03-02T06:00');
    final b = WallTime.parse('2026-03-03T00:00');
    expect(WallTime.overlapMinutes(a, b, WallTime.parse('2026-03-02T05:00'), WallTime.parse('2026-03-02T07:30')), 90);
    expect(WallTime.overlapMinutes(a, b, WallTime.parse('2026-03-03T01:00'), WallTime.parse('2026-03-03T02:00')), 0);
  });

  test('midnight return does not add a day', () {
    final t = TripInput(
      departure: WallTime.parse('2026-03-02T08:00'),
      returnTime: WallTime.parse('2026-03-04T00:00'),
      isBusinessTrip: true,
      outside50km: true,
    );
    expect(TripTimeline.days(t).map((d) => d.toIso()), ['2026-03-02', '2026-03-03']);
  });
}
