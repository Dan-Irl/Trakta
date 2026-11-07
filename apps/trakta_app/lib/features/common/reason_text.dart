import 'package:trakta_core/trakta_core.dart';

import '../../l10n/app_localizations.dart';
import 'country_names.dart';
import 'format.dart';

/// Localized text for an engine [Reason].
String reasonText(AppLocalizations l, Reason r) {
  String s(String key) => '${r.params[key] ?? ''}';
  String money(String key) {
    final v = r.params[key];
    return v is int ? formatMoney(l.localeName, Ore(v)) : '';
  }

  String kr(String key) {
    final v = r.params[key];
    return v is int ? formatMoney(l.localeName, Ore.kr(v)) : '';
  }

  String country(String key) => countryName(l, s(key));
  String countries(String key) => s(key).split(', ').map((c) => countryName(l, c)).join(', ');

  String meal(String key) => switch (s(key)) {
        'breakfast' => l.breakfast,
        'lunch' => l.lunch,
        'dinner' => l.dinner,
        final other => other,
      };

  String meals(String key) => s(key).split('+').map((m) => switch (m) {
        'breakfast' => l.breakfast,
        'lunch' => l.lunch,
        'dinner' => l.dinner,
        final other => other,
      }).join(' + ').toLowerCase();

  return switch (r.code) {
    ReasonCode.eligible => l.rEligible,
    ReasonCode.notEligibleNotBusinessTrip => l.rNotBusinessTrip,
    ReasonCode.notEligibleWithin50km => l.rWithin50km,
    ReasonCode.notEligibleNoOvernight => l.rNoOvernight,
    ReasonCode.departureBeforeNoon => l.rDepartureBeforeNoon(s('time'), s('limit')),
    ReasonCode.departureAtOrAfterNoon => l.rDepartureAfterNoon(s('time'), s('limit')),
    ReasonCode.returnAfter19 => l.rReturnAfter19(s('time'), s('limit')),
    ReasonCode.returnAtOrBefore19 => l.rReturnBefore19(s('time'), s('limit')),
    ReasonCode.wholeDayAway => l.rWholeDayAway,
    ReasonCode.countrySweden => l.rCountrySweden,
    ReasonCode.countryForeign => l.rCountryForeign(country('country'), kr('kr')),
    ReasonCode.countryFallback => l.rCountryFallback(s('country'), country('fallback')),
    ReasonCode.countryRedirect => l.rCountryRedirect(country('country'), country('target')),
    ReasonCode.countryInternationalTransit => l.rTransit,
    ReasonCode.countryAmbiguous => l.rAmbiguous(countries('countries')),
    ReasonCode.countryChosenByUser => l.rChosenByUser(country('country')),
    ReasonCode.countryNoTimeRecorded => l.rNoTimeRecorded,
    ReasonCode.noRulesForYear => l.rNoRules(s('year')),
    ReasonCode.mealReduction => l.rMealReduction(meals('meals'), s('pct'), money('amount')),
    ReasonCode.mealNotReducedTransport => l.rMealTransport(meal('meal')),
    ReasonCode.mealNotReducedUnused => l.rMealUnused(meal('meal')),
    ReasonCode.nightEmployerPaid => l.rNightEmployerPaid,
    ReasonCode.nightReceipt => l.rNightReceipt(money('amount')),
    ReasonCode.nightStandardDomestic => l.rNightDomestic(money('amount')),
    ReasonCode.nightStandardForeign => l.rNightForeign(country('country'), money('amount')),
    ReasonCode.nightNoLodging => l.rNightNone,
    ReasonCode.mileagePrivateTrip => l.rMileagePrivate,
    ReasonCode.mileageRate => l.rMileageRate(
        _km(l, r.params['metres']),
        money('orePerMil'),
        money('amount'),
      ),
    ReasonCode.mileageEmployerPaysFuel => l.rMileageEmployerFuel,
    ReasonCode.mileagePluginHybridWorkplaceCharging => l.rMileageHybrid(s('from')),
    ReasonCode.commuteRate => l.rCommuteRate(s('days'), _km(l, r.params['metres']), money('orePerMil'), money('amount')),
    ReasonCode.commuteRouteTooShort => l.rCommuteRouteTooShort(s('minKm')),
    ReasonCode.commuteFeeCounted => l.rCommuteFeeCounted,
    ReasonCode.commuteFeeNoCarDeduction => l.rCommuteFeeNoCarDeduction(s('minKm')),
    ReasonCode.commuteParkingNotMet =>
      l.rCommuteParkingNotMet(s('minMil'), s('minDays'), s('mil'), s('days')),
    ReasonCode.commuteParkingServiceDaysOnly => l.rCommuteParkingServiceDaysOnly(s('mil'), s('days'), s('allDays')),
    ReasonCode.commuteParkingAllDays => l.rCommuteParkingAllDays(s('mil'), s('days')),
    ReasonCode.carAllowanceNoDeduction => l.rCarAllowanceNoDeduction,
    ReasonCode.employerPaidAtLeastStandard => l.rPaidAtLeast,
    ReasonCode.employerPaidBelowStandard => l.rPaidBelow(money('difference')),
    ReasonCode.employerPaidNothing => l.rPaidNothing,
    ReasonCode.soleTraderDeductionBasis => l.rSoleTrader,
    ReasonCode.openQuestionOddHalfNormalbelopp => l.rOpenOddHalf,
    ReasonCode.openQuestionMealCombination => l.rOpenMealCombination(meals('meals')),
  };
}

String _km(AppLocalizations l, Object? metres) =>
    metres is int ? formatDecimal(l.localeName, metres / 1000) : '';
