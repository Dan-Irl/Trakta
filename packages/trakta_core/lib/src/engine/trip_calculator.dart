import '../explain/reason.dart';
import '../model/calendar_date.dart';
import '../model/enums.dart';
import '../model/trip.dart';
import '../money/ore.dart';
import '../rules/rules_pack.dart';
import 'country_resolver.dart';
import 'trip_timeline.dart';

enum ResultStatus {
  /// Calculated.
  ok,

  /// The trip does not qualify; amount is 0.
  notEligible,

  /// The app has no rules pack for this income year.
  noRulesForYear,

  /// Countries tie for the day; the user must pick one.
  needsCountryChoice,
}

final class DayResult {
  const DayResult({
    required this.date,
    required this.status,
    required this.amount,
    required this.reasons,
    this.dayType,
    this.country,
    this.baseFullDay = Ore.zero,
    this.beforeMeals = Ore.zero,
    this.mealPct = 0,
    this.mealReduction = Ore.zero,
    this.packVersion,
  });

  final CalendarDate date;
  final ResultStatus status;
  final DayType? dayType;
  final DayCountry? country;

  /// Full-day amount for the day's country before any reduction.
  final Ore baseFullDay;

  /// After the half-day reduction, before meals.
  final Ore beforeMeals;
  final int mealPct;
  final Ore mealReduction;

  /// Final standard amount for the day.
  final Ore amount;
  final List<Reason> reasons;
  final String? packVersion;
}

final class NightResult {
  const NightResult({
    required this.evening,
    required this.status,
    required this.amount,
    required this.reasons,
    this.country,
    this.lodging = LodgingKind.standard,
  });

  /// The night between [evening] and the next day.
  final CalendarDate evening;
  final ResultStatus status;
  final DayCountry? country;
  final LodgingKind lodging;
  final Ore amount;
  final List<Reason> reasons;
}

final class TripResult {
  TripResult({required this.eligible, required this.eligibilityReasons, required this.days, required this.nights});

  final bool eligible;
  final List<Reason> eligibilityReasons;
  final List<DayResult> days;
  final List<NightResult> nights;

  Ore get perDiemTotal => Ore.sum(days.map((d) => d.amount));
  Ore get nightTotal => Ore.sum(nights.map((n) => n.amount));
  Ore get total => perDiemTotal + nightTotal;

  /// True when every day and night could be calculated.
  bool get isComplete =>
      days.every((d) => d.status == ResultStatus.ok || d.status == ResultStatus.notEligible) &&
      nights.every((n) => n.status == ResultStatus.ok || n.status == ResultStatus.notEligible);

  Set<int> get missingYears => {
        for (final d in days)
          if (d.status == ResultStatus.noRulesForYear) d.date.year,
        for (final n in nights)
          if (n.status == ResultStatus.noRulesForYear) n.evening.year,
      };

  Set<String> get packVersions => {
        for (final d in days)
          if (d.packVersion != null) d.packVersion!,
      };

  List<Reason> get openQuestions => [
        for (final d in days)
          ...d.reasons.where((r) => r.code.name.startsWith('openQuestion')),
      ];
}

/// The traktamente pipeline (docs/architecture.md): eligibility → days → day type →
/// country → meals → nights. Pure; recompute on every edit.
abstract final class TripCalculator {
  static TripResult calculate(TripInput t, RulesLibrary library) {
    final elig = TripTimeline.eligibility(t);
    final days = <DayResult>[];
    final dayCountries = <CalendarDate, DayCountry>{};

    for (final d in TripTimeline.days(t)) {
      final pack = library.forYear(d.year);
      if (pack == null) {
        days.add(DayResult(
          date: d,
          status: ResultStatus.noRulesForYear,
          amount: Ore.zero,
          reasons: [Reason(ReasonCode.noRulesForYear, {'year': d.year})],
        ));
        continue;
      }
      if (!elig.eligible) {
        days.add(DayResult(
          date: d,
          status: ResultStatus.notEligible,
          amount: Ore.zero,
          reasons: elig.reasons,
          packVersion: pack.packVersion,
        ));
        continue;
      }
      final r = computeDay(d, t, pack);
      if (r.country != null) dayCountries[d] = r.country!;
      days.add(r);
    }

    final nights = <NightResult>[];
    for (final evening in TripTimeline.nights(t)) {
      final pack = library.forYear(evening.year);
      if (pack == null) {
        nights.add(NightResult(
          evening: evening,
          status: ResultStatus.noRulesForYear,
          amount: Ore.zero,
          reasons: [Reason(ReasonCode.noRulesForYear, {'year': evening.year})],
        ));
        continue;
      }
      if (!elig.eligible) {
        nights.add(NightResult(
            evening: evening, status: ResultStatus.notEligible, amount: Ore.zero, reasons: elig.reasons));
        continue;
      }
      nights.add(computeNight(evening, t, pack, dayCountries[evening] ?? const DomesticCountry()));
    }

    return TripResult(eligible: elig.eligible, eligibilityReasons: elig.reasons, days: days, nights: nights);
  }

  /// One day of an eligible trip.
  static DayResult computeDay(CalendarDate d, TripInput t, RulesPack r) {
    final reasons = <Reason>[];

    final dt = TripTimeline.dayType(d, t, r);
    reasons.addAll(dt.reasons);

    final c = CountryResolver.resolve(d, t, r);
    reasons.addAll(c.reasons);
    final country = c.country;
    if (country is AmbiguousCountry) {
      return DayResult(
        date: d,
        status: ResultStatus.needsCountryChoice,
        amount: Ore.zero,
        reasons: reasons,
        dayType: dt.type,
        country: country,
        packVersion: r.packVersion,
      );
    }

    final base = switch (country) {
      DomesticCountry() || InternationalTransitDay() => Ore.kr(r.domestic.fullDayKr),
      ForeignCountry(:final rate) => Ore.kr(rate.kr),
      AmbiguousCountry() => Ore.zero, // handled above
    };

    final halfDivisor = dt.type == DayType.full ? 1 : 2;
    final beforeMeals = base.times(1, halfDivisor);
    if (beforeMeals.value % 100 != 0) {
      reasons.add(Reason(ReasonCode.openQuestionOddHalfNormalbelopp, {'amount': beforeMeals.value}));
    }

    // Meals.
    final input = t.dayInput(d);
    final pcts = country.usesDomesticAmounts ? r.mealDomestic : r.mealForeign;
    var mealPct = 0;
    final reducing = <String>[];
    for (final (name, status, pct) in [
      ('breakfast', input.breakfast, pcts.breakfast),
      ('lunch', input.lunch, pcts.lunch),
      ('dinner', input.dinner, pcts.dinner),
    ]) {
      if (status.reducesPerDiem) {
        mealPct += pct;
        reducing.add(name);
      } else if (status == MealStatus.transportIncluded) {
        reasons.add(Reason(ReasonCode.mealNotReducedTransport, {'meal': name}));
      } else if (status == MealStatus.unused) {
        reasons.add(Reason(ReasonCode.mealNotReducedUnused, {'meal': name}));
      }
    }
    var reduction = Ore.zero;
    if (mealPct > 0) {
      reduction = beforeMeals.percent(mealPct).roundHalfUpToKrona();
      reasons.add(Reason(ReasonCode.mealReduction,
          {'meals': reducing.join('+'), 'pct': mealPct, 'amount': reduction.value}, Sources.traktamente));
      final listed = reducing.length != 2 || (reducing.contains('lunch') && reducing.contains('dinner'));
      if (!listed) {
        reasons.add(Reason(ReasonCode.openQuestionMealCombination, {'meals': reducing.join('+')}));
      }
    }
    final amount = Ore.max(beforeMeals - reduction, Ore.zero);

    return DayResult(
      date: d,
      status: ResultStatus.ok,
      amount: amount,
      reasons: reasons,
      dayType: dt.type,
      country: country,
      baseFullDay: base,
      beforeMeals: beforeMeals,
      mealPct: mealPct,
      mealReduction: reduction,
      packVersion: r.packVersion,
    );
  }

  /// The night after [evening].
  static NightResult computeNight(CalendarDate evening, TripInput t, RulesPack r, DayCountry dayCountry) {
    final input = t.dayInput(evening);
    final country = CountryResolver.nightCountry(evening, t, r, dayCountry);
    switch (input.lodging) {
      case LodgingKind.employerPaid:
        return NightResult(
          evening: evening,
          status: ResultStatus.ok,
          amount: Ore.zero,
          reasons: const [Reason(ReasonCode.nightEmployerPaid)],
          country: country,
          lodging: input.lodging,
        );
      case LodgingKind.none:
        return NightResult(
          evening: evening,
          status: ResultStatus.ok,
          amount: Ore.zero,
          reasons: const [Reason(ReasonCode.nightNoLodging)],
          country: country,
          lodging: input.lodging,
        );
      case LodgingKind.receipt:
        final cost = Ore(input.lodgingCostOre ?? 0);
        return NightResult(
          evening: evening,
          status: ResultStatus.ok,
          amount: cost,
          reasons: [Reason(ReasonCode.nightReceipt, {'amount': cost.value}, Sources.traktamente)],
          country: country,
          lodging: input.lodging,
        );
      case LodgingKind.standard:
        if (country is ForeignCountry) {
          final amount = Ore.kr(country.rate.kr).times(1, 2);
          return NightResult(
            evening: evening,
            status: ResultStatus.ok,
            amount: amount,
            reasons: [
              Reason(ReasonCode.nightStandardForeign, {'country': country.rate.name, 'amount': amount.value},
                  Sources.utlandstraktamente),
            ],
            country: country,
            lodging: input.lodging,
          );
        }
        final amount = Ore.kr(r.domestic.nightKr);
        return NightResult(
          evening: evening,
          status: ResultStatus.ok,
          amount: amount,
          reasons: [Reason(ReasonCode.nightStandardDomestic, {'amount': amount.value}, Sources.traktamente)],
          country: country,
          lodging: input.lodging,
        );
    }
  }
}
