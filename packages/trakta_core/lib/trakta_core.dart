/// Trakta's pure-Dart tax rules engine: traktamente (per diem), milersättning
/// (business driving) and reseavdrag (commuting) according to Skatteverket's
/// standard amounts.
///
/// No Flutter, no I/O, no network. Everything is a pure function of user
/// input plus a per-income-year [RulesPack].
library;

export 'src/engine/commute_calculator.dart';
export 'src/engine/country_resolver.dart';
export 'src/engine/employer_settlement.dart';
export 'src/engine/mileage_calculator.dart';
export 'src/engine/trip_calculator.dart';
export 'src/engine/trip_timeline.dart';
export 'src/explain/reason.dart';
export 'src/model/calendar_date.dart';
export 'src/model/commute.dart';
export 'src/model/enums.dart';
export 'src/model/mileage.dart';
export 'src/model/swedish_holidays.dart';
export 'src/model/trip.dart';
export 'src/money/ore.dart';
export 'src/rules/rules_pack.dart';
export 'src/rules/rules_validation.dart';
