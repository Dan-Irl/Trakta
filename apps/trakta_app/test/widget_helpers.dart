import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakta_app/app/app.dart';
import 'package:trakta_app/app/build_info.dart';
import 'package:trakta_app/app/providers.dart';
import 'package:path/path.dart' as p;
import 'package:trakta_app/data/backup/backup_repository.dart';
import 'package:trakta_app/data/db/database.dart';

import 'test_rules.dart';

/// In-memory database for widget tests. `closeStreamsSynchronously` stops
/// drift's stream cleanup timers from outliving the test, which otherwise
/// keeps the fake clock busy and can make a widget test hang.
AppDatabase testDatabase() =>
    AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

/// Pumps the whole app with an in-memory database and the bundled rules, in
/// the given device language. Returns the database so the test can close it.
/// Starts past the welcome pages unless [onboarded] is false. Documents go to
/// a temporary folder; [pick] stands in for the system file picker and
/// [opened] records files the app asked to open. [pickBackup] stands in for
/// picking a backup file; [shared] records files handed to the share sheet
/// and [saved] files saved through the save dialog. [seed] fills the database
/// before the app starts (writing while screens watch it can deadlock).
/// [channel] stands in for the `TRAKTA_CHANNEL` the release builds set.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  required Locale locale,
  bool onboarded = true,
  List<PickedFile> Function()? pick,
  List<File>? opened,
  List<Uri>? links,
  PickedFile? Function()? pickBackup,
  List<File>? shared,
  List<File>? saved,
  Future<void> Function(AppDatabase db)? seed,
  DistributionChannel channel = DistributionChannel.source,
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  // Real file I/O happens here, outside the fake-async zone, so a missing
  // file fails the test at once instead of leaving a provider loading.
  final library = testLibrary();
  final db = testDatabase();
  final attachments = Directory.systemTemp.createTempSync('trakta_docs');
  addTearDown(() => attachments.deleteSync(recursive: true));
  final backups = Directory.systemTemp.createTempSync('trakta_backups');
  addTearDown(() => backups.deleteSync(recursive: true));
  if (seed != null) await tester.runAsync(() => seed(db));
  if (onboarded) {
    await tester.runAsync(() => db.update(db.profiles).write(const ProfilesCompanion(onboardingDone: Value(true))));
  }
  await tester.pumpWidget(ProviderScope(
    // No automatic retries in tests: an error should fail fast, not spin.
    retry: (retryCount, error) => null,
    overrides: [
      databaseProvider.overrideWithValue(db),
      distributionChannelProvider.overrideWithValue(channel),
      rulesLibraryProvider.overrideWith((ref) async => library),
      attachmentRootProvider.overrideWithValue(attachments),
      pickFilesProvider.overrideWithValue(() async => pick?.call() ?? const []),
      backupFoldersProvider.overrideWithValue(BackupFolders(
        outgoing: Directory(p.join(backups.path, 'outgoing')),
        incoming: Directory(p.join(backups.path, 'incoming')),
      )),
      pickBackupFileProvider.overrideWithValue(() async => pickBackup?.call()),
      saveFileProvider.overrideWithValue((file) async {
        saved?.add(file);
        return true;
      }),
      shareFileProvider.overrideWithValue((file, origin) async {
        shared?.add(file);
        return true;
      }),
      openLinkProvider.overrideWithValue((uri) async {
        links?.add(uri);
        return true;
      }),
      openFileProvider.overrideWithValue((file) async {
        opened?.add(file);
        return true;
      }),
    ],
    child: const TraktaApp(),
  ));
  return db;
}

/// Pumps frames until [finder] matches, or fails after [maxFrames] with a
/// dump of the visible text so the test never hangs silently (unlike
/// pumpAndSettle, which waits up to 10 minutes on endless animations).
Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxFrames = 100}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText()).toList();
  fail('Not found: $finder\nVisible text: $texts\nException: ${tester.takeException()}');
}

/// Unmounts the app and closes the database without leaving timers behind.
Future<void> tearDownApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await db.close();
  await tester.pump();
}

/// Opens a tab in the bottom navigation bar by its label.
Future<void> openTab(WidgetTester tester, String label) async {
  final tab = find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
  await pumpUntilFound(tester, tab);
  await tester.tap(tab);
  await tester.pump(const Duration(milliseconds: 300));
}
