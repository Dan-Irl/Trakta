import 'package:trakta_core/trakta_core.dart';

import '../../data/calculation/trip_calculations.dart';
import '../../data/db/database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/country_names.dart';
import '../common/country_picker.dart';

/// One line about a calculated day: day type, country, long-stay stage and
/// the meals that reduce the per diem.
String daySubtitle(AppLocalizations l, TripCalculation calc, DayResult day) {
  final row = calc.bundle.days.where((d) => d.date == day.date.toIso()).firstOrNull;
  final typeText = switch (day.dayType) {
    DayType.full => l.fullDay,
    DayType.half => l.halfDay,
    null => '',
  };
  final country = switch (day.country) {
    ForeignCountry(:final rate) => '${flagEmoji(rate.code)} ${countryName(l, rate.name)}'.trim(),
    // On a trip abroad, make a day spent in Sweden visible too.
    DomesticCountry() when !isSwedenKey(calc.bundle.trip.country) =>
      '${flagEmoji(swedenCode)} ${countryName(l, swedenName)}',
    AmbiguousCountry() => '?',
    _ => null,
  };
  return [
    typeText,
    ?country,
    if (row != null) mealSummary(l, calc.bundle.mealsFor(row)),
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// The meals that reduce the per diem, e.g. "Breakfast+Lunch".
String mealSummary(AppLocalizations l, DayMeals day) => [
  if (day.breakfast.reducesPerDiem) l.breakfast,
  if (day.lunch.reducesPerDiem) l.lunch,
  if (day.dinner.reducesPerDiem) l.dinner,
].join('+');

/// Whether [day] has anything of its own instead of following the trip.
bool hasOwnChanges(TripDayRow day) =>
    day.breakfast != null ||
    day.lunch != null ||
    day.dinner != null ||
    day.countryOverride != null ||
    day.lodging != null;
