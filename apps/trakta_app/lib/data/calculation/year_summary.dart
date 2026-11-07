import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart' show MileageLine;
import '../repositories/mileage_repository.dart';
import 'trip_calculations.dart';

/// Everything the user can expect to deduct for one income year, from what
/// is tracked so far. Nothing here is stored; it is recomputed like the rest.
///
/// "Deduction" is what the user claims themselves: box 2.2 for employees, the
/// business deduction basis for sole traders, plus the commuting costs above
/// the limit in box 2.1. Amounts the employer paid
/// tax-free are shown separately, since they are not deducted.
class YearSummary {
  const YearSummary({
    required this.year,
    required this.trips,
    required this.days,
    required this.nights,
    required this.tripsNeedingInput,
    required this.perDiemDeduction,
    required this.nightDeduction,
    required this.tripTaxFree,
    required this.drives,
    required this.businessMetres,
    required this.mileageDeduction,
    required this.drivingExpenses,
    required this.mileageTaxFree,
    required this.box12Income,
    this.commute,
  });

  final int year;

  final int trips;
  final int days;
  final int nights;

  /// Trips that give nothing yet or miss information (not eligible,
  /// incomplete, or no rules for the year).
  final int tripsNeedingInput;
  final Ore perDiemDeduction;
  final Ore nightDeduction;
  final Ore tripTaxFree;

  /// Drives in the year (the driving log holds business driving only).
  final int drives;
  final int businessMetres;
  final Ore mileageDeduction;

  /// Congestion tax and tolls on business drives, deducted at actual cost.
  final Ore drivingExpenses;
  final Ore mileageTaxFree;

  /// Allowances the employer paid below the standard amount: income in box
  /// 1.2 (Kostnadsersättningar), normally pre-filled from the employer.
  final Ore box12Income;

  /// Commuting (box 2.1); null when no commute is set up.
  final CommuteResult? commute;

  Ore get tripDeduction => perDiemDeduction + nightDeduction;
  Ore get drivingDeduction => mileageDeduction + drivingExpenses;
  /// Only the part of the commuting costs above the limit lowers income.
  Ore get commuteDeduction => commute?.deductible ?? Ore.zero;
  Ore get total => tripDeduction + drivingDeduction + commuteDeduction;
  bool get isEmpty => trips == 0 && drives == 0;

  /// A trip counts in the year it starts; a drive in the year of its date.
  static YearSummary of(
    int year,
    Iterable<TripCalculation> trips,
    Iterable<MileageLine> lines,
    UserType userType, {
    CommuteResult? commute,
  }) {
    final inYear = [for (final t in trips) if (t.bundle.departureWall.year == year) t];
    final drives = [
      for (final m in lines)
        if (CalendarDate.parse(m.entry.date).year == year) m,
    ];
    final mileage = [for (final m in drives) mileageSettlement(m, userType)];
    Ore sum<T>(Iterable<T> xs, Ore Function(T) f) => xs.fold(Ore.zero, (a, x) => a + f(x));

    return YearSummary(
      year: year,
      trips: inYear.length,
      days: inYear.fold(0, (n, t) => n + t.result.days.length),
      nights: inYear.fold(0, (n, t) => n + t.result.nights.length),
      tripsNeedingInput: inYear
          .where((t) => !t.result.eligible || !t.result.isComplete || t.result.missingYears.isNotEmpty)
          .length,
      perDiemDeduction: sum(inYear, (t) => _deduction(t.perDiem)),
      nightDeduction: sum(inYear, (t) => _deduction(t.nights)),
      tripTaxFree: sum(inYear, (t) => t.perDiem.taxFree + t.nights.taxFree),
      drives: drives.length,
      businessMetres: drives.fold(0, (n, m) => n + m.entry.distanceM),
      mileageDeduction: sum(mileage, _deduction),
      drivingExpenses: sum(drives, (m) => m.result.expenses),
      mileageTaxFree: sum(mileage, (s) => s.taxFree),
      box12Income: sum(inYear, (t) => t.perDiem.box12Income + t.nights.box12Income) +
          sum(mileage, (s) => s.box12Income),
      commute: commute,
    );
  }

  /// Years with anything tracked, newest first, always including [current].
  static List<int> years(Iterable<TripCalculation> trips, Iterable<MileageLine> lines, int current) => {
        current,
        for (final t in trips) t.bundle.departureWall.year,
        for (final m in lines) CalendarDate.parse(m.entry.date).year,
      }.toList()
        ..sort((a, b) => b.compareTo(a));

  /// Standard mileage amount against the car allowance the employer paid.
  static Settlement mileageSettlement(MileageLine m, UserType userType) => EmployerSettlement.settle(
        standard: m.result.amount,
        paid: m.entry.allowancePaid,
        kind: EmployerPaymentKind.mileage,
        userType: userType,
      );

  static Ore _deduction(Settlement s) => s.box22Deduction + s.businessDeduction;
}

