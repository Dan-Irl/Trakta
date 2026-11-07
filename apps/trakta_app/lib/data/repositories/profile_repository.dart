import 'package:trakta_core/trakta_core.dart';

import '../db/database.dart';

class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  Stream<ProfileRow> watch() => (_db.select(_db.profiles)..where((p) => p.id.equals(1))).watchSingle();

  Future<void> update(ProfilesCompanion changes) =>
      (_db.update(_db.profiles)..where((p) => p.id.equals(1))).write(changes);
}

extension ProfileRowX on ProfileRow {
  bool get isSoleTrader => userType == UserType.soleTrader;
}
