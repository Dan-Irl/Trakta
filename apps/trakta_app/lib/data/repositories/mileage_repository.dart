import 'package:drift/drift.dart';
import 'package:trakta_core/trakta_core.dart';

import '../db/database.dart';

class MileageRepository {
  MileageRepository(this._db);

  final AppDatabase _db;

  Stream<List<VehicleRow>> watchVehicles() =>
      (_db.select(_db.vehicles)..orderBy([(v) => OrderingTerm.asc(v.label)])).watch();

  Stream<List<MileageEntryRow>> watchEntries() => (_db.select(_db.mileageEntries)
        ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.id)]))
      .watch();

  Future<int> saveVehicle(VehiclesCompanion v) async {
    if (v.id.present) {
      await (_db.update(_db.vehicles)..where((t) => t.id.equals(v.id.value))).write(v);
      return v.id.value;
    }
    return _db.into(_db.vehicles).insert(v);
  }

  Future<int> saveEntry(MileageEntriesCompanion e) async {
    if (e.id.present) {
      await (_db.update(_db.mileageEntries)..where((t) => t.id.equals(e.id.value))).write(e);
      return e.id.value;
    }
    return _db.into(_db.mileageEntries).insert(e.copyWith(createdUtc: Value(DateTime.now().toUtc())));
  }

  /// Sets the car allowance rate on every drive in [year], e.g. when the
  /// user changes the rate and wants it for drives already logged.
  Future<void> setAllowanceForYear(int year, int? orePerMil) =>
      (_db.update(_db.mileageEntries)..where((e) => e.date.like('$year-%')))
          .write(MileageEntriesCompanion(allowanceOrePerMil: Value(orePerMil)));

  Future<void> deleteEntry(int id) => (_db.delete(_db.mileageEntries)..where((t) => t.id.equals(id))).go();

  /// Vehicles with logged trips are archived rather than deleted, so the
  /// körjournal stays complete.
  Future<void> archiveVehicle(int id) =>
      (_db.update(_db.vehicles)..where((t) => t.id.equals(id))).write(const VehiclesCompanion(archived: Value(true)));
}

extension VehicleRowX on VehicleRow {
  /// How a car is shown everywhere: "Volvo V60 – ABC123", so two cars with
  /// the same name (e.g. an archived one and its replacement) can be told
  /// apart. Just the name when there is no registration.
  String get displayName => registration.isEmpty ? label : '$label – $registration';

  VehicleInput toInput() => VehicleInput(
        ownership: ownership,
        powertrain: powertrain,
        employerPaysFuel: employerPaysFuel,
        onlyWorkplaceChargingFromEmployer: onlyWorkplaceCharging,
      );
}

extension MileageEntryRowX on MileageEntryRow {
  /// The car allowance paid for this drive: rate per mil × distance.
  Ore get allowancePaid =>
      allowanceOrePerMil == null ? Ore.zero : Ore(allowanceOrePerMil!).times(distanceM, 10000);

  MileageInput toInput() => MileageInput(
        date: CalendarDate.parse(date),
        distanceMetres: distanceM,
        // Everything in the driving log is business driving.
        isBusiness: true,
        congestionTaxOre: congestionTaxOre,
        tollOre: tollOre,
      );
}
