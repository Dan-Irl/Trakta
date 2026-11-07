import 'package:drift/drift.dart';
import 'package:trakta_core/trakta_core.dart';

// The tables store only user input. Tax
// data lives in the read-only rules packs and calculated amounts are never
// stored, so a corrected rules pack fixes every past trip automatically.
//
// Enum columns store the enum's `name`. Never rename an enum value in
// trakta_core without a migration.

/// One row (id = 1): who the user is and when they normally work.
@DataClassName('ProfileRow')
class Profiles extends Table {
  IntColumn get id => integer()();
  TextColumn get userType => textEnum<UserType>().withDefault(Constant(UserType.employee.name))();

  BoolColumn get onboardingDone => boolean().withDefault(const Constant(false))();

  /// The car allowance (bilersättning) the employer pays, in öre per mil,
  /// used for new business drives; null when the employer pays none.
  IntColumn get carAllowanceOrePerMil => integer().nullable()();

  /// App language chosen in settings ('sv' or 'en'); null follows the device.
  TextColumn get localeCode => text().nullable()();

  /// When the latest backup was created (on this phone, or the restored
  /// backup's date); null before the first one.
  DateTimeColumn get lastBackupUtc => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TripRow')
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get purpose => text()();
  DateTimeColumn get startUtc => dateTime()();
  DateTimeColumn get endUtc => dateTime()();

  /// IANA zone of the departure place, e.g. Europe/Stockholm.
  TextColumn get startTz => text()();
  TextColumn get endTz => text()();

  /// Country for the whole trip: Skatteverket's Swedish name from the rules
  /// pack ("Tyskland"), or "Sverige" for a domestic trip. Single days can
  /// differ through [TripDays.countryOverride].
  TextColumn get country => text().withDefault(const Constant(swedenName))();

  BoolColumn get confirmedBusinessTrip => boolean().withDefault(const Constant(false))();
  BoolColumn get confirmed50km => boolean().withDefault(const Constant(false))();

  /// Night worker sleeping during the day (overnight requirement met).
  BoolColumn get nightWorker => boolean().withDefault(const Constant(false))();
  BoolColumn get employerPaysPerDiem => boolean().withDefault(const Constant(true))();

  /// Meals for the whole trip, e.g. breakfast included in the hotel price.
  /// Single days can differ through [TripDays.breakfast] and friends.
  TextColumn get breakfast => textEnum<MealStatus>().withDefault(Constant(MealStatus.none.name))();
  TextColumn get lunch => textEnum<MealStatus>().withDefault(Constant(MealStatus.none.name))();
  TextColumn get dinner => textEnum<MealStatus>().withDefault(Constant(MealStatus.none.name))();

  /// Lodging for every night of the trip, e.g. a hotel paid by the employer
  /// (no night allowance). Never [LodgingKind.receipt]: receipts belong to a
  /// night. Single nights can differ through [TripDays.lodging].
  TextColumn get lodging => textEnum<LodgingKind>().withDefault(Constant(LodgingKind.standard.name))();
  IntColumn get continuesTripId => integer().nullable().references(Trips, #id, onDelete: KeyAction.setNull)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdUtc => dateTime()();
}

/// Stays and legs inside a trip, for country resolution (M2).
@DataClassName('TripSegmentRow')
class TripSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId => integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<SegmentKind>()();

  /// Swedish name from the rules pack's country list, or "Sverige".
  TextColumn get countryName => text().nullable()();
  TextColumn get countryCode => text().nullable()();
  DateTimeColumn get startUtc => dateTime()();
  DateTimeColumn get endUtc => dateTime()();
  TextColumn get tz => text()();
}

@DataClassName('TripDayRow')
class TripDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId => integer().references(Trips, #id, onDelete: KeyAction.cascade)();

  /// Local calendar date, ISO `YYYY-MM-DD`.
  TextColumn get date => text()();

  /// Meal changes for this day; null means the trip's meal applies (see
  /// `TripBundle.mealsFor`).
  TextColumn get breakfast => textEnum<MealStatus>().nullable()();
  TextColumn get lunch => textEnum<MealStatus>().nullable()();
  TextColumn get dinner => textEnum<MealStatus>().nullable()();

  /// Lodging the night after this day; null means the trip's lodging
  /// applies.
  TextColumn get lodging => textEnum<LodgingKind>().nullable()();
  IntColumn get lodgingCostOre => integer().nullable()();
  TextColumn get countryOverride => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {tripId, date},
      ];
}

@DataClassName('EmployerPaymentRow')
class EmployerPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId => integer().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<EmployerPaymentKind>()();
  IntColumn get amountOre => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {tripId, kind},
      ];
}

@DataClassName('VehicleRow')
class Vehicles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text()();
  TextColumn get registration => text().withDefault(const Constant(''))();
  TextColumn get ownership => textEnum<Ownership>()();
  TextColumn get powertrain => textEnum<Powertrain>()();
  BoolColumn get employerPaysFuel => boolean().withDefault(const Constant(false))();
  BoolColumn get onlyWorkplaceCharging => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Körjournal rows.
@DataClassName('MileageEntryRow')
class MileageEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Local calendar date, ISO `YYYY-MM-DD`.
  TextColumn get date => text()();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();
  IntColumn get tripId => integer().nullable().references(Trips, #id, onDelete: KeyAction.setNull)();
  IntColumn get odoStart => integer().nullable()();
  IntColumn get odoEnd => integer().nullable()();
  IntColumn get distanceM => integer()();
  TextColumn get fromText => text().withDefault(const Constant(''))();
  TextColumn get toText => text().withDefault(const Constant(''))();
  TextColumn get purpose => text().withDefault(const Constant(''))();
  TextColumn get visited => text().withDefault(const Constant(''))();
  IntColumn get congestionTaxOre => integer().withDefault(const Constant(0))();
  IntColumn get tollOre => integer().withDefault(const Constant(0))();

  /// Car allowance (bilersättning) the employer pays for this drive, in öre
  /// per mil (10 km); null when none. Copied from the profile's rate when the
  /// drive is added, so a later change of rate leaves past drives as they were.
  IntColumn get allowanceOrePerMil => integer().nullable()();
  DateTimeColumn get createdUtc => dateTime()();
}

/// A regular commute between home and the regular workplace (reseavdrag,
/// box 2.1). Driving in the job is a [MileageEntries] row instead.
@DataClassName('CommuteRouteRow')
class CommuteRoutes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text().withDefault(const Constant(''))();
  IntColumn get vehicleId => integer().references(Vehicles, #id)();

  /// Home to workplace by the shortest route, one way.
  IntColumn get oneWayM => integer()();

  /// ISO weekdays commuted, comma separated ("1,2,3,4,5").
  TextColumn get workDays => text().withDefault(const Constant('1,2,3,4,5'))();

  /// ISO `YYYY-MM-DD`; [endDate] null while the route is in use.
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
  DateTimeColumn get createdUtc => dateTime()();
}

/// A change to the commuting schedule on one date: not commuted (vacation,
/// sick, home office) or commuted on a day that is not scheduled. Days
/// without a row follow the schedule.
@DataClassName('CommuteDayRow')
class CommuteDays extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Local calendar date, ISO `YYYY-MM-DD`.
  TextColumn get date => text().unique()();
  BoolColumn get commuted => boolean()();
  TextColumn get reason => textEnum<NoCommuteReason>().nullable()();
  IntColumn get routeId => integer().nullable().references(CommuteRoutes, #id, onDelete: KeyAction.setNull)();
  IntColumn get oneWayM => integer().nullable()();
}

/// A commuting cost besides the mileage: congestion tax invoices, road,
/// bridge and ferry fees, parking. Recurring costs are one row.
@DataClassName('CommuteExpenseRow')
class CommuteExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => textEnum<CommuteExpenseKind>()();
  TextColumn get recurrence => textEnum<ExpenseRecurrence>()();

  /// Per payment, per month or per commuting day, see [recurrence].
  IntColumn get amountOre => integer()();

  /// ISO dates: the payment date, or the first and last day of the period.
  TextColumn get fromDate => text()();
  TextColumn get toDate => text().nullable()();
  IntColumn get routeId => integer().nullable().references(CommuteRoutes, #id, onDelete: KeyAction.setNull)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdUtc => dateTime()();
}

/// Documents kept with a record: flight tickets, booking confirmations,
/// receipts. The file itself lives in the app's private storage under its
/// SHA-256 (see `AttachmentStore`), so the same file added twice is stored
/// once. [ownerType] says which table [ownerId] points into ("trip").
@DataClassName('AttachmentRow')
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get ownerType => text()();
  IntColumn get ownerId => integer()();

  /// The name the file had when it was added, shown to the user.
  TextColumn get fileName => text()();
  TextColumn get sha256 => text()();
  IntColumn get sizeBytes => integer()();
  DateTimeColumn get createdUtc => dateTime()();
}
