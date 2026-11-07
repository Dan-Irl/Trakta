// Moving to a new phone through the UI: a backup from Settings, and a
// restore straight from the welcome pages of a fresh install.
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:trakta_app/data/backup/backup_repository.dart';
import 'package:trakta_app/data/db/database.dart';
import 'package:trakta_core/trakta_core.dart';

import 'widget_helpers.dart';

/// Pumps frames and lets real work (isolates, disk) run between them, until
/// [finder] matches.
Future<void> pumpUntilDone(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  }
  await pumpUntilFound(tester, finder, maxFrames: 1);
}

Finder inDialog(Finder finder) => find.descendant(of: find.byType(AlertDialog), matching: finder);

Future<void> seedCarAndTrip(AppDatabase db) async {
  await db.into(db.vehicles).insert(
      VehiclesCompanion.insert(label: 'Volvo V60', ownership: Ownership.own, powertrain: Powertrain.fossil));
  await db.into(db.trips).insert(TripsCompanion.insert(
        purpose: 'Customer visit, Göteborg',
        startUtc: DateTime.utc(2026, 9, 1, 6),
        endUtc: DateTime.utc(2026, 9, 2, 18),
        startTz: 'Europe/Stockholm',
        endTz: 'Europe/Stockholm',
        createdUtc: DateTime.utc(2026, 9, 1),
      ));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('a backup from Settings: password rules, then saved as a file', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final shared = <File>[];
    final saved = <File>[];
    final db = await pumpApp(tester,
        locale: const Locale('en', 'SE'), shared: shared, saved: saved, seed: seedCarAndTrip);
    await pumpUntilFound(tester, find.byTooltip('Settings'));
    await tester.tap(find.byTooltip('Settings'));
    await pumpUntilFound(tester, find.text('None yet. Make one before you switch phones.'));

    await tester.tap(find.text('Create backup'));
    await pumpUntilFound(tester, find.text('Password for the backup'));
    expect(find.textContaining('nobody can open the backup'), findsOneWidget);
    final create = inDialog(find.widgetWithText(FilledButton, 'Create backup'));

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.enterText(find.widgetWithText(TextFormField, 'Repeat the password'), 'short');
    await tester.tap(create);
    await tester.pump();
    expect(find.text('At least 8 characters'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'long enough password');
    await tester.enterText(find.widgetWithText(TextFormField, 'Repeat the password'), 'long enough passw0rd');
    await tester.tap(create);
    await tester.pump();
    expect(find.text('The passwords do not match'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Repeat the password'), 'long enough password');
    await tester.tap(create);
    // Saved anywhere on the phone, or shared straight to another app.
    await pumpUntilDone(tester, find.text('Save the backup'));
    expect(find.text('Share'), findsOneWidget);
    await tester.tap(find.text('Save as a file'));
    await pumpUntilDone(tester, find.text('Backup created'));

    expect(saved, hasLength(1));
    expect(shared, isEmpty);
    expect(p.extension(saved.single.path), '.trakta');
    expect(find.textContaining('Last backup:'), findsOneWidget);
    final profile = (await tester.runAsync(() => db.select(db.profiles).getSingle()))!;
    expect(profile.lastBackupUtc, isNotNull);

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 90)));

  testWidgets('a fresh install restores a backup from the welcome page', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // The old phone's backup.
    final oldFolder = Directory.systemTemp.createTempSync('trakta_old_phone');
    addTearDown(() => oldFolder.deleteSync(recursive: true));
    final backup = (await tester.runAsync(() async {
      final old = testDatabase();
      await old.update(old.profiles).write(const ProfilesCompanion(onboardingDone: Value(true)));
      await seedCarAndTrip(old);
      final file = await BackupRepository(
        old,
        Directory(p.join(oldFolder.path, 'documents')),
        BackupFolders(
          outgoing: Directory(p.join(oldFolder.path, 'outgoing')),
          incoming: Directory(p.join(oldFolder.path, 'incoming')),
        ),
      ).create('my old phone password', now: DateTime.utc(2026, 10, 1, 8));
      await old.close();
      return file;
    }))!;

    final db = await pumpApp(
      tester,
      locale: const Locale('en', 'SE'),
      onboarded: false,
      pickBackup: () => (name: 'Trakta-backup-2026-10-01.trakta', read: backup.openRead),
    );
    await pumpUntilFound(tester, find.text('Welcome to Trakta'));
    await tester.tap(find.text('Switching phones? Restore a backup'));
    await pumpUntilFound(tester, find.text('Enter the password you chose when the backup was made.'));

    // A wrong password asks again.
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'not it');
    await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Next')));
    await pumpUntilDone(tester, find.text('Wrong password, or the file is not a Trakta backup.'));

    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'my old phone password');
    await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Next')));
    await pumpUntilDone(tester, find.text('Restore this backup?'));
    expect(find.textContaining('Backup from'), findsOneWidget);
    expect(find.text('Everything currently in Trakta on this phone is replaced.'), findsOneWidget);
    final tripsRow = find.ancestor(of: find.text('Trips'), matching: find.byType(Row));
    expect(find.descendant(of: tripsRow, matching: find.text('1')), findsOneWidget);

    await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Restore')));
    // The restored profile has been through the welcome pages: straight in.
    await pumpUntilDone(tester, find.byType(NavigationBar));
    final vehicles = (await tester.runAsync(() => db.select(db.vehicles).get()))!;
    expect(vehicles.single.label, 'Volvo V60');
    final profile = (await tester.runAsync(() => db.select(db.profiles).getSingle()))!;
    expect(profile.lastBackupUtc, DateTime.utc(2026, 10, 1, 8));

    await tearDownApp(tester, db);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
