/// A calendar date without time or time zone.
///
/// Internally backed by a UTC [DateTime] at midnight so that day arithmetic
/// is never affected by daylight saving time.
final class CalendarDate implements Comparable<CalendarDate> {
  const CalendarDate(this.year, this.month, this.day);

  /// The calendar date of a wall-clock time (see [WallTime]).
  factory CalendarDate.of(DateTime dt) => CalendarDate(dt.year, dt.month, dt.day);

  /// Parses `YYYY-MM-DD`.
  factory CalendarDate.parse(String iso) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso.trim());
    if (m == null) throw FormatException('Expected YYYY-MM-DD', iso);
    return CalendarDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// ISO weekday, 1 = Monday … 7 = Sunday.
  int get weekday => _utc.weekday;

  /// Wall-clock time on this date.
  DateTime at(int hour, [int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute);

  /// Midnight at the start of this date, as wall-clock time.
  DateTime get start => at(0);

  CalendarDate addDays(int days) =>
      CalendarDate.of(DateTime.utc(year, month, day + days));

  CalendarDate get next => addDays(1);
  CalendarDate get previous => addDays(-1);

  /// The same day number [months] calendar months later, clamped to the last
  /// day of the target month (31 January + 1 month = 28/29 February).
  CalendarDate addCalendarMonths(int months) {
    final total = year * 12 + (month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final lastDay = DateTime.utc(y, m + 1, 0).day;
    return CalendarDate(y, m, day > lastDay ? lastDay : day);
  }

  /// Number of days from this date to [other] (negative if [other] is earlier).
  int daysUntil(CalendarDate other) => other._utc.difference(_utc).inDays;

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;
  bool isOnOrBefore(CalendarDate other) => compareTo(other) <= 0;
  bool isOnOrAfter(CalendarDate other) => compareTo(other) >= 0;

  /// Dates from [from] to [to], both inclusive.
  static Iterable<CalendarDate> range(CalendarDate from, CalendarDate to) sync* {
    for (var d = from; d.isOnOrBefore(to); d = d.next) {
      yield d;
    }
  }

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => toIso();
}

/// Helpers for wall-clock times.
///
/// The engine works on *local wall-clock time at the place in question*,
/// because Skatteverket's day rules use local time (06:00–24:00, 12:00, 19:00).
/// Wall-clock times are represented as [DateTime] values in UTC mode so that
/// no platform time-zone or DST conversion ever touches them. The app converts
/// stored UTC instants plus IANA zone names into wall-clock times before
/// calling the engine.
abstract final class WallTime {
  static DateTime of(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute);

  /// Parses `YYYY-MM-DDTHH:MM` as wall-clock time.
  static DateTime parse(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})$').firstMatch(s.trim());
    if (m == null) throw FormatException('Expected YYYY-MM-DDTHH:MM', s);
    return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!),
        int.parse(m[4]!), int.parse(m[5]!));
  }

  /// Minutes of overlap between [aStart, aEnd) and [bStart, bEnd).
  static int overlapMinutes(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    final s = aStart.isAfter(bStart) ? aStart : bStart;
    final e = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    if (!e.isAfter(s)) return 0;
    return e.difference(s).inMinutes;
  }

  static String format(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
