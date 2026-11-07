/// Enums shared by the engine and the app's database. Their `name` values are
/// persisted by Drift (`textEnum`), so never rename a value without a
/// database migration.
library;

enum UserType { employee, soleTrader, companyOwner }

/// What happened with one meal on one day.
enum MealStatus {
  /// No free meal.
  none,

  /// Free meal paid by the employer (main rule): reduces per diem.
  paid,

  /// Hotel breakfast mandatorily included in the room price: reduces.
  hotelIncluded,

  /// Business meal (representation): reduces, no taxable benefit.
  representation,

  /// Meal mandatorily included in a public transport ticket: does not reduce.
  transportIncluded,

  /// Included meal the user could not use (e.g. early departure): does not reduce.
  unused;

  bool get reducesPerDiem =>
      this == MealStatus.paid ||
      this == MealStatus.hotelIncluded ||
      this == MealStatus.representation;
}

/// How the night before the next day was paid.
enum LodgingKind {
  /// Standard night allowance, no receipt.
  standard,

  /// Actual cost from a receipt; used even when lower than standard.
  receipt,

  /// Employer provided or paid lodging.
  employerPaid,

  /// No lodging cost (e.g. stayed with friends, night on a train).
  none,
}

enum SegmentKind {
  /// Time spent in a country (on the ground, including transfers and waits).
  stay,

  /// On a ship or plane between ports/airports in different countries.
  internationalTransit,

  /// Stopover for refuelling; counts for no country.
  stopover,
}

enum DayType { full, half }

enum Ownership { own, company }

enum Powertrain { fossil, pluginHybrid, electric }

enum EmployerPaymentKind { perDiem, night, mileage }

/// A cost of commuting (resor till och från arbetet) besides the mileage.
enum CommuteExpenseKind {
  /// Trängselskatt, entered from the monthly invoice.
  congestionTax,

  /// Road fee (vägavgift, infrastrukturavgift).
  roadToll,

  /// Bridge fee (broavgift), e.g. Öresundsbron, Svinesundsbron.
  bridgeToll,

  /// Ferry fee (färjeavgift).
  ferryFee,

  /// Parking at or near the workplace: deductible only after regular
  /// business driving with the same car (see CommuteParkingRules).
  parking;

  bool get isParking => this == CommuteExpenseKind.parking;
}

/// How often a commuting cost is paid.
enum ExpenseRecurrence {
  /// A single payment on its date, e.g. a congestion tax invoice.
  once,

  /// The same amount every month in a period, e.g. a parking permit.
  monthly,

  /// The same amount on every commuting day in a period, e.g. a bridge fee.
  perCommuteDay,
}

/// Why the user did not commute on a day they normally would.
enum NoCommuteReason { vacation, sick, homeOffice, other }
