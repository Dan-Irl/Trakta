import '../explain/reason.dart';
import '../model/enums.dart';
import '../money/ore.dart';

/// Comparison of the standard amount with what the employer paid
/// (docs/tax-rules.md, "What the employer paid").
final class Settlement {
  const Settlement({
    required this.standard,
    required this.paid,
    required this.taxFree,
    required this.taxableExcess,
    required this.box12Income,
    required this.box22Deduction,
    required this.businessDeduction,
    required this.reasons,
  });

  /// The standard (schablon) amount the engine calculated.
  final Ore standard;

  /// What the employer actually paid.
  final Ore paid;

  /// The tax-free part of what was paid.
  final Ore taxFree;

  /// Paid above the standard: taxable salary, handled by the employer.
  final Ore taxableExcess;

  /// To report as kostnadsersättning (box 1.2) when claiming a deduction.
  final Ore box12Income;

  /// To deduct at box 2.2 (Tjänsteresor).
  final Ore box22Deduction;

  /// Sole trader: deduction basis in the business accounts.
  final Ore businessDeduction;

  /// Net effect of claiming: box 2.2 − box 1.2.
  Ore get netDeduction => box22Deduction - box12Income;

  final List<Reason> reasons;
}

abstract final class EmployerSettlement {
  static Settlement settle({
    required Ore standard,
    required Ore paid,
    required EmployerPaymentKind kind,
    UserType userType = UserType.employee,
  }) {
    if (userType == UserType.soleTrader) {
      return Settlement(
        standard: standard,
        paid: Ore.zero,
        taxFree: Ore.zero,
        taxableExcess: Ore.zero,
        box12Income: Ore.zero,
        box22Deduction: Ore.zero,
        businessDeduction: standard,
        reasons: const [Reason(ReasonCode.soleTraderDeductionBasis)],
      );
    }
    if (paid.isZero) {
      return Settlement(
        standard: standard,
        paid: paid,
        taxFree: Ore.zero,
        taxableExcess: Ore.zero,
        box12Income: Ore.zero,
        box22Deduction: standard,
        businessDeduction: Ore.zero,
        reasons: const [Reason(ReasonCode.employerPaidNothing)],
      );
    }
    if (paid >= standard) {
      return Settlement(
        standard: standard,
        paid: paid,
        taxFree: standard,
        taxableExcess: paid - standard,
        box12Income: Ore.zero,
        box22Deduction: Ore.zero,
        businessDeduction: Ore.zero,
        reasons: const [Reason(ReasonCode.employerPaidAtLeastStandard)],
      );
    }
    // Paid less than the standard.
    if (kind == EmployerPaymentKind.mileage) {
      // Skatteverket (Avdragslexikon, Tjänsteresor): no mileage deduction when
      // the employer paid a car allowance for the trips. The allowance itself
      // is tax-free up to the standard amount.
      return Settlement(
        standard: standard,
        paid: paid,
        taxFree: paid,
        taxableExcess: Ore.zero,
        box12Income: Ore.zero,
        box22Deduction: Ore.zero,
        businessDeduction: Ore.zero,
        reasons: const [Reason(ReasonCode.carAllowanceNoDeduction, {}, Sources.avdragslexikonT)],
      );
    }
    return Settlement(
      standard: standard,
      paid: paid,
      taxFree: paid,
      taxableExcess: Ore.zero,
      box12Income: paid,
      box22Deduction: standard,
      businessDeduction: Ore.zero,
      reasons: [Reason(ReasonCode.employerPaidBelowStandard, {'difference': (standard - paid).value})],
    );
  }
}
