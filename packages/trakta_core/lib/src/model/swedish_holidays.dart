import 'calendar_date.dart';

/// A day most people in Sweden do not work: the public holidays of Lagen
/// (1989:253) om allmänna helgdagar, plus the three eves (Midsommarafton,
/// Julafton, Nyårsafton) that are days off by collective agreement for most
/// employees. Commuting days skip them; a user who worked can add the day.
enum SwedishHoliday {
  newYearsDay,
  epiphany,
  goodFriday,
  easterSunday,
  easterMonday,
  mayDay,
  ascensionDay,
  whitSunday,
  nationalDay,
  midsummerEve,
  midsummerDay,
  allSaintsDay,
  christmasEve,
  christmasDay,
  boxingDay,
  newYearsEve,
}

abstract final class SwedishHolidays {
  /// Every holiday of [year] by date. Computed, so it works for any year.
  static Map<CalendarDate, SwedishHoliday> of(int year) {
    final easter = easterSunday(year);
    // Midsummer Day: the Saturday 20–26 June. All Saints' Day: the Saturday
    // 31 October – 6 November.
    final midsummerDay = _saturdayFrom(CalendarDate(year, 6, 20));
    final allSaints = _saturdayFrom(CalendarDate(year, 10, 31));
    return {
      CalendarDate(year, 1, 1): SwedishHoliday.newYearsDay,
      CalendarDate(year, 1, 6): SwedishHoliday.epiphany,
      easter.addDays(-2): SwedishHoliday.goodFriday,
      easter: SwedishHoliday.easterSunday,
      easter.addDays(1): SwedishHoliday.easterMonday,
      CalendarDate(year, 5, 1): SwedishHoliday.mayDay,
      easter.addDays(39): SwedishHoliday.ascensionDay,
      easter.addDays(49): SwedishHoliday.whitSunday,
      CalendarDate(year, 6, 6): SwedishHoliday.nationalDay,
      midsummerDay.previous: SwedishHoliday.midsummerEve,
      midsummerDay: SwedishHoliday.midsummerDay,
      allSaints: SwedishHoliday.allSaintsDay,
      CalendarDate(year, 12, 24): SwedishHoliday.christmasEve,
      CalendarDate(year, 12, 25): SwedishHoliday.christmasDay,
      CalendarDate(year, 12, 26): SwedishHoliday.boxingDay,
      CalendarDate(year, 12, 31): SwedishHoliday.newYearsEve,
    };
  }

  /// Easter Sunday (Gregorian calendar, anonymous algorithm).
  static CalendarDate easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = (h + l - 7 * m + 114) % 31 + 1;
    return CalendarDate(year, month, day);
  }

  static CalendarDate _saturdayFrom(CalendarDate first) =>
      first.addDays((DateTime.saturday - first.weekday) % 7);
}
