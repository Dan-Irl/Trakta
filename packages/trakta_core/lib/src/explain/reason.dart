/// Why the engine produced an amount. The UI turns a [Reason] into localized
/// text; the engine never produces user-facing prose.
enum ReasonCode {
  // Eligibility
  notEligibleNotBusinessTrip,
  notEligibleWithin50km,
  notEligibleNoOvernight,
  eligible,

  // Day type
  departureBeforeNoon,
  departureAtOrAfterNoon,
  returnAfter19,
  returnAtOrBefore19,
  wholeDayAway,

  // Country
  countrySweden,
  countryForeign,
  countryFallback,
  countryRedirect,
  countryInternationalTransit,
  countryAmbiguous,
  countryChosenByUser,
  countryNoTimeRecorded,
  noRulesForYear,


  // Meals
  mealReduction,
  mealNotReducedTransport,
  mealNotReducedUnused,

  // Nights
  nightEmployerPaid,
  nightReceipt,
  nightStandardDomestic,
  nightStandardForeign,
  nightNoLodging,

  // Mileage
  mileagePrivateTrip,
  mileageRate,
  mileageEmployerPaysFuel,
  mileagePluginHybridWorkplaceCharging,

  // Commuting (resor till och från arbetet)
  commuteRate,
  commuteRouteTooShort,
  commuteFeeCounted,
  commuteFeeNoCarDeduction,
  commuteParkingNotMet,
  commuteParkingServiceDaysOnly,
  commuteParkingAllDays,

  // Employer comparison
  employerPaidAtLeastStandard,
  employerPaidBelowStandard,
  employerPaidNothing,
  soleTraderDeductionBasis,

  /// Car allowance paid but below the standard: no deduction for the rest.
  carAllowanceNoDeduction,

  // Open questions flagged to the user
  openQuestionOddHalfNormalbelopp,
  openQuestionMealCombination,
}

/// One explanation step, with parameters for the localized message and an
/// optional Skatteverket source URL.
final class Reason {
  const Reason(this.code, [this.params = const {}, this.source]);

  final ReasonCode code;
  final Map<String, Object> params;
  final String? source;

  @override
  String toString() => params.isEmpty ? code.name : '${code.name}$params';

  @override
  bool operator ==(Object other) =>
      other is Reason && other.code == code && _mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(code, Object.hashAllUnordered(params.entries.map((e) => Object.hash(e.key, e.value))));
}

bool _mapEquals(Map<String, Object> a, Map<String, Object> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

abstract final class Sources {
  static const traktamente =
      'https://www.skatteverket.se/privat/skatter/arbeteochinkomst/traktamente.4.dfe345a107ebcc9baf80006547.html';
  static const utlandstraktamente = 'https://www.skatteverket.se/utlandstraktamente';
  static const specifikationReserakning = 'https://skatteverket.entryscape.net/store/9/resource/2430';

  /// Avdragslexikon T: Tjänsteresor (business driving rates, car allowance)
  /// and Trängselskatt.
  static const avdragslexikonT =
      'https://www.skatteverket.se/privat/skatter/arbeteochinkomst/avdragforprivatpersoner/t.4.5fc8c94513259a4ba1d800042933.html';
}
