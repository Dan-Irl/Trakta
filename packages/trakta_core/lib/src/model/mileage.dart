import 'calendar_date.dart';
import 'enums.dart';

final class VehicleInput {
  const VehicleInput({
    required this.ownership,
    required this.powertrain,
    this.employerPaysFuel = false,
    this.onlyWorkplaceChargingFromEmployer = false,
  });

  /// [Ownership.own] also covers borrowed, rented and leased cars, and a
  /// company car provided by someone else's employer (Specifikation v1.4).
  final Ownership ownership;
  final Powertrain powertrain;

  /// Company car only: the employer pays (part of) the fuel or charging.
  final bool employerPaysFuel;

  /// Plug-in hybrid company car: the only thing the employer provides is
  /// charging at the workplace (allowed from 2026-07-01).
  final bool onlyWorkplaceChargingFromEmployer;
}

/// One körjournal row, as the engine sees it.
final class MileageInput {
  const MileageInput({
    required this.date,
    required this.distanceMetres,
    required this.isBusiness,
    this.congestionTaxOre = 0,
    this.tollOre = 0,
  });

  final CalendarDate date;
  final int distanceMetres;
  final bool isBusiness;
  final int congestionTaxOre;
  final int tollOre;
}
