// Backup and restore for moving to a new phone: everything comes back
// exactly, documents included, and a wrong password, a damaged or foreign
// file, or a backup from a newer app never touches the data on the phone.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:trakta_app/data/backup/backup_file.dart';
import 'package:trakta_app/data/backup/backup_repository.dart';
import 'package:trakta_app/data/db/database.dart';
import 'package:trakta_app/data/repositories/attachment_repository.dart';
import 'package:trakta_core/trakta_core.dart';

import 'widget_helpers.dart';

/// One phone: a database, its documents folder and its backup folders.
class Phone {
  Phone(this.db, this.root)
      : documents = Directory(p.join(root.path, 'documents')),
        folders = BackupFolders(
          outgoing: Directory(p.join(root.path, 'outgoing')),
          incoming: Directory(p.join(root.path, 'incoming')),
        );

  final AppDatabase db;
  final Directory root;
  final Directory documents;
  final BackupFolders folders;

  BackupRepository get backups => BackupRepository(db, documents, folders);
  AttachmentRepository get attachments => AttachmentRepository(db, documents);

  static Phone create() {
    final db = testDatabase();
    final root = Directory.systemTemp.createTempSync('trakta_phone');
    addTearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });
    return Phone(db, root);
  }

  /// Every row of every table, as stored.
  Future<Map<String, List<Map<String, Object?>>>> dump() async => {
        for (final t in db.allTables)
          t.actualTableName: [
            for (final r in await db.customSelect('SELECT * FROM "${t.actualTableName}" ORDER BY rowid').get()) r.data,
          ],
      };

  Set<String> documentNames() =>
      documents.existsSync() ? {for (final f in documents.listSync().whereType<File>()) p.basename(f.path)} : {};
}

Stream<List<int>> bytes(String s) => Stream.value(utf8.encode(s));
Stream<List<int>> fileContent(File f) => f.openRead();

/// A year of use: a sole trader with a car, two trips (one continuing the
/// other), drives, a commute with costs and days off, and documents.
Future<void> fillWithData(Phone phone) async {
  final db = phone.db;
  final now = DateTime.utc(2026, 10, 8, 12);
  await db.update(db.profiles).write(const ProfilesCompanion(
        userType: Value(UserType.soleTrader),
        onboardingDone: Value(true),
        carAllowanceOrePerMil: Value(1850),
        localeCode: Value('en'),
      ));
  final car = await db.into(db.vehicles).insert(VehiclesCompanion.insert(
        label: 'Volvo V60',
        registration: const Value('ABC123'),
        ownership: Ownership.own,
        powertrain: Powertrain.pluginHybrid,
      ));
  final berlin = await db.into(db.trips).insert(TripsCompanion.insert(
        purpose: 'Customer workshop, Berlin',
        startUtc: DateTime.utc(2026, 3, 2, 6),
        endUtc: DateTime.utc(2026, 3, 5, 18),
        startTz: 'Europe/Stockholm',
        endTz: 'Europe/Berlin',
        country: const Value('Tyskland'),
        confirmedBusinessTrip: const Value(true),
        confirmed50km: const Value(true),
        breakfast: const Value(MealStatus.hotelIncluded),
        note: const Value('Hotel by the station, åäö ✓'),
        createdUtc: now,
      ));
  final munich = await db.into(db.trips).insert(TripsCompanion.insert(
        purpose: 'Follow-up, Munich',
        startUtc: DateTime.utc(2026, 3, 5, 18),
        endUtc: DateTime.utc(2026, 3, 7, 15),
        startTz: 'Europe/Berlin',
        endTz: 'Europe/Stockholm',
        continuesTripId: Value(berlin),
        createdUtc: now,
      ));
  await db.into(db.tripDays).insert(TripDaysCompanion.insert(
        tripId: berlin,
        date: '2026-03-03',
        lunch: const Value(MealStatus.paid),
        lodging: const Value(LodgingKind.receipt),
        lodgingCostOre: const Value(129900),
      ));
  await db.into(db.employerPayments).insert(
      EmployerPaymentsCompanion.insert(tripId: munich, kind: EmployerPaymentKind.perDiem, amountOre: 50000));
  await db.into(db.mileageEntries).insert(MileageEntriesCompanion.insert(
        date: '2026-03-02',
        vehicleId: car,
        tripId: Value(berlin),
        odoStart: const Value(12000),
        odoEnd: const Value(12045),
        distanceM: 45000,
        purpose: const Value('To Arlanda'),
        allowanceOrePerMil: const Value(1850),
        createdUtc: now,
      ));
  final route = await db.into(db.commuteRoutes).insert(CommuteRoutesCompanion.insert(
        vehicleId: car,
        oneWayM: 32000,
        startDate: '2026-01-01',
        createdUtc: now,
      ));
  await db.into(db.commuteDays).insert(CommuteDaysCompanion.insert(
        date: '2026-04-10',
        commuted: false,
        reason: const Value(NoCommuteReason.vacation),
      ));
  final expense = await db.into(db.commuteExpenses).insert(CommuteExpensesCompanion.insert(
        kind: CommuteExpenseKind.congestionTax,
        recurrence: ExpenseRecurrence.once,
        amountOre: 45000,
        fromDate: '2026-02-28',
        routeId: Value(route),
        createdUtc: now,
      ));

  final ticket = await phone.attachments.import('Flight SK123.pdf', bytes('boarding pass'));
  final invoice = await phone.attachments.import('Invoice.JPG', bytes('pixels'));
  await phone.attachments.add(AttachmentOwner.trip, berlin, [ticket, invoice]);
  await phone.attachments.add(AttachmentOwner.trip, munich, [ticket]); // same file, stored once
  await phone.attachments.add(AttachmentOwner.commuteExpense, expense, [invoice]);
}

Map<String, List<Map<String, Object?>>> withoutBackupDate(Map<String, List<Map<String, Object?>>> dump) => {
      for (final e in dump.entries)
        e.key: [for (final r in e.value) Map.of(r)..remove('last_backup_utc')],
    };

void main() {
  // Two phones means two databases in one test, on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('everything comes back on the new phone, documents included', () async {
    final old = Phone.create();
    await fillWithData(old);
    final created = DateTime.utc(2026, 10, 8, 9, 30);
    final file = await old.backups.create('correct horse battery', now: created);
    expect(p.basename(file.path), 'Trakta-backup-2026-10-08.trakta');

    // The file is encrypted: no table, text or document is readable.
    final raw = latin1.decode(file.readAsBytesSync());
    expect(raw.startsWith('SQLite format 3'), isFalse);
    expect(raw, isNot(contains('Berlin')));
    expect(raw, isNot(contains('boarding pass')));

    // The new phone already has some data of its own; it is replaced.
    final fresh = Phone.create();
    await fresh.db.into(fresh.db.vehicles).insert(
        VehiclesCompanion.insert(label: 'Old test car', ownership: Ownership.company, powertrain: Powertrain.electric));
    final stray = await fresh.attachments.import('stray.pdf', bytes('not in the backup'));
    await fresh.attachments.add(AttachmentOwner.trip, 99, [stray]);

    final preview = await fresh.backups.open(fileContent(file), 'correct horse battery');
    expect(preview.createdUtc, created);
    expect(preview.count(fresh.db.trips), 2);
    expect(preview.count(fresh.db.mileageEntries), 1);
    expect(preview.count(fresh.db.vehicles), 1);
    expect(preview.count(fresh.db.commuteRoutes), 1);
    expect(preview.count(fresh.db.attachments), 4);
    // Nothing changes until the user confirms.
    expect((await fresh.db.select(fresh.db.vehicles).get()).single.label, 'Old test car');

    await fresh.backups.restore(preview);

    expect(withoutBackupDate(await fresh.dump()), withoutBackupDate(await old.dump()));
    final profile = await fresh.db.select(fresh.db.profiles).getSingle();
    expect(profile.lastBackupUtc, created);
    expect(profile.onboardingDone, isTrue);
    expect(fresh.documentNames(), old.documentNames());
    expect(fresh.documentNames(), hasLength(2));
    for (final name in old.documentNames()) {
      expect(File(p.join(fresh.documents.path, name)).readAsStringSync(),
          File(p.join(old.documents.path, name)).readAsStringSync());
    }
    expect(fresh.folders.incoming.existsSync(), isFalse); // nothing left behind

    // The restored data works like any other: a new trip continues the ids.
    final next = await fresh.db.into(fresh.db.trips).insert(TripsCompanion.insert(
          purpose: 'After the move',
          startUtc: DateTime.utc(2026, 11, 1),
          endUtc: DateTime.utc(2026, 11, 2),
          startTz: 'Europe/Stockholm',
          endTz: 'Europe/Stockholm',
          createdUtc: DateTime.utc(2026, 11, 1),
        ));
    expect(next, 3);
  });

  test('a backup of an empty app restores to an empty app', () async {
    final old = Phone.create();
    final file = await old.backups.create('password1');
    final fresh = Phone.create();
    await fresh.backups.restore(await fresh.backups.open(fileContent(file), 'password1'));
    expect(withoutBackupDate(await fresh.dump()), withoutBackupDate(await old.dump()));
  });

  group('a backup that cannot be restored leaves the phone as it was', () {
    late Phone old;
    late File file;
    late Phone target;
    late Map<String, List<Map<String, Object?>>> before;

    setUp(() async {
      old = Phone.create();
      await fillWithData(old);
      file = await old.backups.create('right password');
      target = Phone.create();
      await target.db.into(target.db.vehicles).insert(
          VehiclesCompanion.insert(label: 'Kept', ownership: Ownership.own, powertrain: Powertrain.fossil));
      before = await target.dump();
    });

    Future<void> expectRefused(Stream<List<int>> content, String password, BackupError error) async {
      await expectLater(
        target.backups.open(content, password),
        throwsA(isA<BackupException>().having((e) => e.error, 'error', error)),
      );
      expect(await target.dump(), before);
      expect(target.folders.incoming.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.trakta')),
          isEmpty);
    }

    test('wrong password', () => expectRefused(fileContent(file), 'wrong password', BackupError.wrongPasswordOrDamaged));

    test('not a backup at all', () => expectRefused(bytes('%PDF-1.7 a receipt'), 'right password', BackupError.wrongPasswordOrDamaged));

    test('changed by someone', () async {
      final data = file.readAsBytesSync();
      data[data.length - 200] ^= 0x01;
      await expectRefused(Stream.value(data), 'right password', BackupError.damaged);
    });

    test('made by a newer app', () async {
      final path = p.join(old.root.path, 'future.trakta');
      BackupFile.write(
        path: path,
        password: 'right password',
        schemaVersion: old.db.schemaVersion + 1,
        createdUtc: DateTime.utc(2030),
        records: const {},
        files: const [],
      );
      await expectRefused(fileContent(File(path)), 'right password', BackupError.newerApp);
    });

    test('a document name that tries to leave the documents folder', () async {
      final path = p.join(old.root.path, 'evil.trakta');
      final evil = p.join(old.root.path, 'evil.txt');
      File(evil).writeAsStringSync('x');
      BackupFile.write(
        path: path,
        password: 'right password',
        schemaVersion: old.db.schemaVersion,
        createdUtc: DateTime.utc(2026),
        records: {'profiles': (await old.dump())['profiles']!},
        files: [(name: '../../outside.txt', sha256: '00', path: evil)],
      );
      await expectRefused(fileContent(File(path)), 'right password', BackupError.damaged);
    });

    test('cancelling after the summary changes nothing', () async {
      final preview = await target.backups.open(fileContent(file), 'right password');
      await target.backups.discard(preview);
      expect(await target.dump(), before);
      expect(target.folders.incoming.existsSync(), isFalse);
    });
  });

  test('document names: only "<sha256><extension>" is accepted', () {
    final hash = 'a' * 64;
    expect(BackupFile.isDocumentName('$hash.pdf'), isTrue);
    expect(BackupFile.isDocumentName(hash), isTrue);
    expect(BackupFile.isDocumentName('../$hash.pdf'), isFalse);
    expect(BackupFile.isDocumentName('$hash/../x'), isFalse);
    expect(BackupFile.isDocumentName('$hash.p\\df'), isFalse);
    expect(BackupFile.isDocumentName('.import-123'), isFalse);
  });
}
