import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trakta_core/trakta_core.dart';

import '../data/backup/backup_repository.dart';
import '../data/calculation/commute_calculations.dart';
import '../data/calculation/trip_calculations.dart';
import '../data/db/connection.dart';
import '../data/db/database.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/commute_repository.dart';
import '../data/repositories/mileage_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/trip_repository.dart';
import '../data/rules/rules_repository.dart';

/// The app database. Overridden with an in-memory database in tests.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openEncryptedDatabase());
  ref.onDispose(db.close);
  return db;
});

/// Where attached documents are kept: app-private storage next to the
/// database. Looked up once in main() (see [attachmentRoot]); a temporary
/// folder in tests.
final attachmentRootProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('attachmentRootProvider is set in main()'),
);

/// The documents folder inside the app's private support directory.
Future<Directory> attachmentRoot() async =>
    Directory(p.join((await getApplicationSupportDirectory()).path, 'attachments'));

final attachmentRepositoryProvider = Provider<AttachmentRepository>(
  (ref) => AttachmentRepository(ref.watch(databaseProvider), ref.watch(attachmentRootProvider)),
);

/// Documents attached to one record, e.g. `(AttachmentOwner.trip, 3)`.
final attachmentsProvider = StreamProvider.family<List<AttachmentRow>, (String, int)>(
  (ref, owner) => ref.watch(attachmentRepositoryProvider).watch(owner.$1, owner.$2),
);

/// Number of documents per record of one owner type, for list rows.
final attachmentCountsProvider = StreamProvider.family<Map<int, int>, String>(
  (ref, ownerType) => ref.watch(attachmentRepositoryProvider).watchCounts(ownerType),
);

/// A file the user picked: its name and its content. On Android the picker
/// hands over a content URI, not a path, so the content is read as a stream.
typedef PickedFile = ({String name, Stream<List<int>> Function() read});

/// Opens the system file picker (any type, several at once). Overridden in
/// tests, which cannot show it.
final pickFilesProvider = Provider<Future<List<PickedFile>> Function()>((ref) => () async {
      final files = await FilePicker.pickFiles();
      return [for (final f in files) (name: f.name, read: f.readAsByteStream)];
    });

/// Working folders for backups, looked up once in main() (see
/// [backupFolders]); temporary folders in tests.
final backupFoldersProvider = Provider<BackupFolders>(
  (ref) => throw UnimplementedError('backupFoldersProvider is set in main()'),
);

/// New backups wait in temporary storage until shared; a backup being
/// restored is unpacked next to the documents so they can be moved in.
Future<BackupFolders> backupFolders() async => BackupFolders(
      outgoing: Directory(p.join((await getTemporaryDirectory()).path, 'backup')),
      incoming: Directory(p.join((await getApplicationSupportDirectory()).path, 'restore')),
    );

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(
    ref.watch(databaseProvider),
    ref.watch(attachmentRootProvider),
    ref.watch(backupFoldersProvider),
  ),
);

/// Opens the system file picker for one file (a backup). Null when the user
/// cancels. Overridden in tests.
final pickBackupFileProvider = Provider<Future<PickedFile?> Function()>((ref) => () async {
      final f = await FilePicker.pickFile();
      return f == null ? null : (name: f.name, read: f.readAsByteStream);
    });

/// Lets the user save a copy of a file anywhere on the phone through the
/// system's save dialog (Android: the file browser with Downloads, Documents,
/// Drive...; iPhone: the Files app). Returns false when cancelled.
/// Overridden in tests.
final saveFileProvider = Provider<Future<bool> Function(File file)>(
  (ref) => (file) async =>
      await FilePicker.saveFile(fileName: p.basename(file.path), bytes: await file.readAsBytes()) != null,
);

/// Hands a file to the phone's share sheet (save to Files, Google Drive,
/// iCloud Drive, email...). [origin] anchors the sheet on iPad. Returns false
/// only when the user dismissed it. Overridden in tests.
final shareFileProvider = Provider<Future<bool> Function(File file, Rect? origin)>(
  (ref) => (file, origin) async {
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/octet-stream')],
      sharePositionOrigin: origin,
    ));
    return result.status != ShareResultStatus.dismissed;
  },
);

/// Opens a stored file in the phone's own viewer (PDF reader, gallery).
/// Returns false when no app can open it.
final openFileProvider = Provider<Future<bool> Function(File)>(
  (ref) => (file) async => (await OpenFilex.open(file.path)).type == ResultType.done,
);

/// Trakta's website: about the app, help, contact and how to support it.
const websiteUrl = 'https://trakta.app';

/// Opens a link in the phone's own browser (the app itself has no internet
/// access). Returns false when no browser could take it. Overridden in tests.
final openLinkProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final rulesLibraryProvider = FutureProvider<RulesLibrary>((ref) => RulesRepository().load());

final tripRepositoryProvider = Provider((ref) => TripRepository(ref.watch(databaseProvider)));
final mileageRepositoryProvider = Provider((ref) => MileageRepository(ref.watch(databaseProvider)));
final commuteRepositoryProvider = Provider((ref) => CommuteRepository(ref.watch(databaseProvider)));
final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.watch(databaseProvider)));

final profileProvider = StreamProvider<ProfileRow>((ref) => ref.watch(profileRepositoryProvider).watch());

final tripBundlesProvider = StreamProvider<List<TripBundle>>((ref) => ref.watch(tripRepositoryProvider).watchAll());

/// Every trip, calculated. Recomputed whenever a trip, the profile or the
/// rules change; the engine is fast enough to do the whole list each time.
final tripCalculationsProvider = FutureProvider<Map<int, TripCalculation>>((ref) async {
  final bundles = await ref.watch(tripBundlesProvider.future);
  final library = await ref.watch(rulesLibraryProvider.future);
  final profile = await ref.watch(profileProvider.future);
  return TripCalculations.computeAll(bundles, library, profile);
});

final vehiclesProvider = StreamProvider<List<VehicleRow>>((ref) => ref.watch(mileageRepositoryProvider).watchVehicles());

final mileageEntriesProvider =
    StreamProvider<List<MileageEntryRow>>((ref) => ref.watch(mileageRepositoryProvider).watchEntries());

/// Körjournal rows with their calculated amounts.
final mileageCalculationsProvider = FutureProvider<List<MileageLine>>((ref) async {
  final entries = await ref.watch(mileageEntriesProvider.future);
  final vehicles = await ref.watch(vehiclesProvider.future);
  final library = await ref.watch(rulesLibraryProvider.future);
  final byId = {for (final v in vehicles) v.id: v};
  return [
    for (final e in entries)
      if (byId[e.vehicleId] case final v?)
        MileageLine(entry: e, vehicle: v, result: MileageCalculator.calculate(e.toInput(), v.toInput(), library)),
  ];
});

final commuteDataProvider = StreamProvider<CommuteData>((ref) => ref.watch(commuteRepositoryProvider).watch());

/// The commuting deduction for one income year so far: up to today in the
/// current year. Depends on trips (days away) and business driving
/// (parking), so it is recomputed when either changes.
final commuteResultProvider = FutureProvider.family<CommuteResult, int>((ref, year) async {
  final today = CalendarDate.of(DateTime.now());
  return _commute(ref, year, until: year == today.year ? today : null);
});

/// The whole year from the schedule; for the current year a projection.
final commuteFullYearProvider = FutureProvider.family<CommuteResult, int>((ref, year) => _commute(ref, year));

Future<CommuteResult> _commute(Ref ref, int year, {CalendarDate? until}) async => CommuteCalculations.compute(
      year,
      await ref.watch(commuteDataProvider.future),
      await ref.watch(vehiclesProvider.future),
      await ref.watch(mileageEntriesProvider.future),
      await ref.watch(tripBundlesProvider.future),
      await ref.watch(rulesLibraryProvider.future),
      until: until,
    );

/// Everything the overview needs, loaded together.
final overviewDataProvider = FutureProvider<
    ({Map<int, TripCalculation> trips, List<MileageLine> lines, ProfileRow profile, bool hasVehicles})>((ref) async {
  return (
    trips: await ref.watch(tripCalculationsProvider.future),
    lines: await ref.watch(mileageCalculationsProvider.future),
    profile: await ref.watch(profileProvider.future),
    hasVehicles: (await ref.watch(vehiclesProvider.future)).any((v) => !v.archived),
  );
});

class MileageLine {
  const MileageLine({required this.entry, required this.vehicle, required this.result});
  final MileageEntryRow entry;
  final VehicleRow vehicle;
  final MileageResult result;
}
