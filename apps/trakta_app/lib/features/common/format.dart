import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../l10n/app_localizations.dart';

/// Locale-aware display of money and numbers. The engine only deals in öre;
/// how an amount looks is purely a presentation concern:
///   sv: `1 226,50 kr`, `300 kr`
///   en: `SEK 1,226.50`, `SEK 300`
String formatMoney(String localeName, Ore amount) {
  final whole = amount.value % 100 == 0;
  final swedish = localeName.startsWith('sv');
  final f = swedish
      ? NumberFormat.currency(locale: 'sv', symbol: 'kr', decimalDigits: whole ? 0 : 2)
      : NumberFormat.currency(locale: 'en', symbol: 'SEK ', decimalDigits: whole ? 0 : 2);
  // Display only: the öre integer is converted to a double for formatting,
  // never for calculation.
  return f.format(amount.value / 100);
}

/// A plain decimal number in the user's language ("48,6" / "48.6").
String formatDecimal(String localeName, num value, {int maxDigits = 1}) {
  final f = NumberFormat.decimalPattern(localeName.startsWith('sv') ? 'sv' : 'en')
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = maxDigits;
  return f.format(value);
}

extension LocalizedFormatting on BuildContext {
  String get _localeName => AppLocalizations.of(this).localeName;

  String money(Ore amount) => formatMoney(_localeName, amount);

  String decimal(num value, {int maxDigits = 1}) => formatDecimal(_localeName, value, maxDigits: maxDigits);
}

String formatDate(BuildContext context, CalendarDate d) =>
    MaterialLocalizations.of(context).formatMediumDate(DateTime(d.year, d.month, d.day));

/// Weekday and date without the year, for day rows and titles:
/// "Sat, Oct 3" / "lör 3 okt.". Use this rather than putting [weekdayShort]
/// in front of [formatDate], whose English form already has the weekday.
String formatDayDate(BuildContext context, CalendarDate d) =>
    DateFormat.MMMEd(AppLocalizations.of(context).localeName).format(DateTime(d.year, d.month, d.day));

String formatWall(BuildContext context, DateTime wall) {
  final m = MaterialLocalizations.of(context);
  final date = m.formatMediumDate(DateTime(wall.year, wall.month, wall.day));
  final time = m.formatTimeOfDay(TimeOfDay(hour: wall.hour, minute: wall.minute), alwaysUse24HourFormat: true);
  return '$date $time';
}

String weekdayShort(AppLocalizations l, int isoWeekday) => switch (isoWeekday) {
      1 => l.wd1,
      2 => l.wd2,
      3 => l.wd3,
      4 => l.wd4,
      5 => l.wd5,
      6 => l.wd6,
      _ => l.wd7,
    };

/// Parses a kronor amount typed in either language into öre:
/// "1 226,50", "1226,5", "1,226.50", "1226.50", "300". Returns null if empty
/// or invalid. When both separators appear, the last one is the decimal mark.
int? parseKronorToOre(String input) {
  var s = input.replaceAll(RegExp(r'[\s  ]'), '');
  if (s.isEmpty) return null;
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  final decimalAt = lastComma > lastDot ? lastComma : lastDot;
  if (decimalAt >= 0) {
    final intPart = s.substring(0, decimalAt).replaceAll(RegExp('[,.]'), '');
    final frac = s.substring(decimalAt + 1);
    // "1,226" / "1.226" with three digits after the only separator is a
    // thousands separator, not decimals.
    final onlyOne = s.indexOf(s[decimalAt]) == decimalAt && (lastComma < 0 || lastDot < 0);
    s = (onlyOne && frac.length == 3) ? '$intPart$frac' : '$intPart.$frac';
  }
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  final kr = int.parse(m[1]!);
  final ore = m[2] == null ? 0 : int.parse(m[2]!.padRight(2, '0'));
  return kr * 100 + ore;
}

/// Öre → editable kronor text without thousands separators, using the
/// language's decimal mark ("1226,5" / "1226.5").
String oreToInput(int? ore, [String localeName = 'sv']) {
  if (ore == null || ore == 0) return '';
  final kr = ore ~/ 100;
  final rest = ore % 100;
  if (rest == 0) return '$kr';
  final mark = localeName.startsWith('sv') ? ',' : '.';
  return '$kr$mark${rest.toString().padLeft(2, '0')}';
}
