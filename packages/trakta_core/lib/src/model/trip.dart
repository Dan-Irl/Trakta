import 'calendar_date.dart';
import 'enums.dart';

/// Swedish name and code used for domestic segments.
const swedenName = 'Sverige';
const swedenCode = 'SE';

bool isSwedenKey(String? nameOrCode) {
  if (nameOrCode == null) return false;
  final k = nameOrCode.trim().toLowerCase();
  return k == 'sverige' || k == 'se' || k == 'sweden';
}

/// A stay or leg inside a trip, in the local wall-clock time of the place
/// (see [WallTime]). Used to decide which country applies each day.
final class Segment {
  const Segment({
    required this.kind,
    required this.start,
    required this.end,
    this.country,
  });

  /// A stay in Sweden.
  const Segment.sweden({required this.start, required this.end})
      : kind = SegmentKind.stay,
        country = swedenName;

  const Segment.stay({required String this.country, required this.start, required this.end})
      : kind = SegmentKind.stay;

  const Segment.transit({required this.start, required this.end})
      : kind = SegmentKind.internationalTransit,
        country = null;

  final SegmentKind kind;

  /// Swedish country name or ISO code as in the rules pack. Required for
  /// [SegmentKind.stay], ignored otherwise.
  final String? country;

  /// Local wall-clock start at this place.
  final DateTime start;

  /// Local wall-clock end at this place.
  final DateTime end;
}

/// User input for one calendar day of a trip.
final class DayInput {
  const DayInput({
    this.breakfast = MealStatus.none,
    this.lunch = MealStatus.none,
    this.dinner = MealStatus.none,
    this.lodging = LodgingKind.standard,
    this.lodgingCostOre,
    this.countryOverride,
  });

  static const empty = DayInput();

  final MealStatus breakfast;
  final MealStatus lunch;
  final MealStatus dinner;

  /// Lodging for the night that starts on the evening of this day.
  final LodgingKind lodging;

  /// Receipt amount in öre when [lodging] is [LodgingKind.receipt].
  final int? lodgingCostOre;

  /// The user's choice of country for this day (Swedish name or ISO code,
  /// "Sverige" for Sweden). Wins over the segments and also applies to the
  /// night after the day.
  final String? countryOverride;

  DayInput copyWith({
    MealStatus? breakfast,
    MealStatus? lunch,
    MealStatus? dinner,
    LodgingKind? lodging,
    int? lodgingCostOre,
    String? countryOverride,
  }) =>
      DayInput(
        breakfast: breakfast ?? this.breakfast,
        lunch: lunch ?? this.lunch,
        dinner: dinner ?? this.dinner,
        lodging: lodging ?? this.lodging,
        lodgingCostOre: lodgingCostOre ?? this.lodgingCostOre,
        countryOverride: countryOverride ?? this.countryOverride,
      );
}

/// Everything the engine needs to calculate one business trip.
final class TripInput {
  const TripInput({
    required this.departure,
    required this.returnTime,
    required this.isBusinessTrip,
    required this.outside50km,
    this.nightWorker = false,
    this.segments = const [],
    this.days = const {},
    this.userType = UserType.employee,
  });

  /// Local wall-clock time the trip starts (leaving home or workplace).
  final DateTime departure;

  /// Local wall-clock time the trip ends.
  final DateTime returnTime;

  /// User-confirmed: the employer ordered the trip (tjänsteresa).
  final bool isBusinessTrip;

  /// User-confirmed: more than 50 km from both home and regular workplace.
  final bool outside50km;

  /// Night worker who sleeps during the day away from home: the overnight
  /// requirement is treated as met.
  final bool nightWorker;

  /// Country timeline. Empty means the whole trip is in Sweden.
  final List<Segment> segments;

  /// Per-day input keyed by local calendar date. Missing days use defaults.
  final Map<CalendarDate, DayInput> days;

  final UserType userType;

  CalendarDate get firstDate => CalendarDate.of(departure);

  DayInput dayInput(CalendarDate d) => days[d] ?? DayInput.empty;

  bool get isDomesticOnly =>
      segments.every((s) => s.kind != SegmentKind.stay || isSwedenKey(s.country));
}
