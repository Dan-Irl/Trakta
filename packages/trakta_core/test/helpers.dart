import 'dart:convert';
import 'dart:io';

import 'package:trakta_core/trakta_core.dart';

/// Repository root, found by walking up until `rules/` exists.
Directory repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory('${dir.path}/rules').existsSync() && File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) throw StateError('rules/ directory not found above ${Directory.current.path}');
    dir = parent;
  }
}

Map<String, Object?> loadPackJson(int year) {
  final f = File('${repoRoot().path}/rules/$year.json');
  return (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
}

RulesPack loadPack(int year) => RulesPack.fromJson(loadPackJson(year));

RulesLibrary library2026() => RulesLibrary([loadPack(2026)]);

DateTime w(String s) => WallTime.parse(s);
CalendarDate d(String s) => CalendarDate.parse(s);

/// Shortcut for a domestic, eligible trip.
TripInput domesticTrip(
  String from,
  String to, {
  Map<CalendarDate, DayInput> days = const {},
}) =>
    TripInput(
      departure: w(from),
      returnTime: w(to),
      isBusinessTrip: true,
      outside50km: true,
      days: days,
    );

DayResult dayOf(TripResult r, String date) => r.days.firstWhere((x) => x.date == d(date));
