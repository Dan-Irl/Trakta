import 'package:drift/drift.dart';
import 'package:trakta_core/trakta_core.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Profiles,
    Trips,
    TripSegments,
    TripDays,
    EmployerPayments,
    Vehicles,
    MileageEntries,
    CommuteRoutes,
    CommuteDays,
    CommuteExpenses,
    Attachments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The first released schema. Bump on every schema change, add a step in
  /// [migration], and run `dart run drift_dev make-migrations` so the
  /// generated tests cover every version.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(profiles).insert(const ProfilesCompanion(id: Value(1)));
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
