import '../explain/reason.dart';
import '../model/calendar_date.dart';
import '../model/enums.dart';
import '../model/mileage.dart';
import '../money/ore.dart';
import '../rules/rules_pack.dart';

final class MileageResult {
  const MileageResult({
    required this.amount,
    required this.reasons,
    this.rateKey,
    this.orePerMil,
    this.noRulesForYear = false,
    this.expenses = Ore.zero,
  });

  /// Standard mileage amount (tax-free or deductible).
  final Ore amount;

  /// Congestion tax and tolls, deductible at actual cost for business trips.
  final Ore expenses;
  final String? rateKey;
  final int? orePerMil;
  final bool noRulesForYear;
  final List<Reason> reasons;
}

/// docs/tax-rules.md, "Business driving".
abstract final class MileageCalculator {
  /// The rate key for a vehicle; the same keys serve business driving and
  /// commuting.
  static String rateKey(VehicleInput v) => switch ((v.ownership, v.powertrain)) {
        (Ownership.own, _) => MileageRateKey.ownCar,
        (Ownership.company, Powertrain.electric) => MileageRateKey.companyCarElectric,
        (Ownership.company, _) => MileageRateKey.companyCarNonElectric,
      };

  /// Whether a company car's standard amount survives the employer paying
  /// for fuel: only a plug-in hybrid charged at the workplace, from the date
  /// in the rules pack.
  static bool hybridChargingException(VehicleInput v, CalendarDate date, RulesPack r) =>
      v.powertrain == Powertrain.pluginHybrid &&
      v.onlyWorkplaceChargingFromEmployer &&
      !date.isBefore(r.pluginHybridWorkplaceChargingOkFrom);

  static MileageResult calculate(MileageInput e, VehicleInput v, RulesLibrary library) {
    if (!e.isBusiness) {
      return const MileageResult(amount: Ore.zero, reasons: [Reason(ReasonCode.mileagePrivateTrip)]);
    }
    final r = library.forYear(e.date.year);
    if (r == null) {
      return MileageResult(
        amount: Ore.zero,
        noRulesForYear: true,
        reasons: [Reason(ReasonCode.noRulesForYear, {'year': e.date.year})],
      );
    }
    final expenses = Ore(e.congestionTaxOre + e.tollOre);
    final key = rateKey(v);
    final reasons = <Reason>[];
    if (v.ownership == Ownership.company && v.employerPaysFuel) {
      if (!hybridChargingException(v, e.date, r)) {
        return MileageResult(
          amount: Ore.zero,
          expenses: expenses,
          rateKey: key,
          reasons: const [Reason(ReasonCode.mileageEmployerPaysFuel)],
        );
      }
      reasons.add(Reason(ReasonCode.mileagePluginHybridWorkplaceCharging,
          {'from': r.pluginHybridWorkplaceChargingOkFrom.toIso()}));
    }
    final orePerMil = r.mileageOrePerMil[key]!;
    // distance in metres / 10 000 = mil
    final amount = Ore(orePerMil).times(e.distanceMetres, 10000);
    reasons.add(Reason(ReasonCode.mileageRate, {
      'key': key,
      'orePerMil': orePerMil,
      'metres': e.distanceMetres,
      'amount': amount.value,
    }));
    return MileageResult(amount: amount, expenses: expenses, rateKey: key, orePerMil: orePerMil, reasons: reasons);
  }
}
