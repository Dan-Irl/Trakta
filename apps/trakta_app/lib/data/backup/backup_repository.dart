import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../db/database.dart';
import '../repositories/attachment_repository.dart';
import 'backup_file.dart';

export 'backup_file.dart' show BackupError, BackupException;

/// Working folders for backups.
class BackupFolders {
  const BackupFolders({required this.outgoing, required this.incoming});

  /// New backup files wait here until the user has saved or shared them
  /// (temporary storage; the next backup clears it).
  final Directory outgoing;

  /// A backup being restored is copied and unpacked here. It sits next to
  /// the documents folder, so its documents can be moved in.
  final Directory incoming;
}

/// Creates and restores `.trakta` backups (see [BackupFile]) for moving to a
/// new phone. A restore replaces everything on this phone; there is no
/// merging and no syncing.
class BackupRepository {
  BackupRepository(this._db, this._documents, this._folders);

  final AppDatabase _db;
  final Directory _documents;
  final BackupFolders _folders;

  /// Writes a backup of all data and documents, protected by [password], and
  /// returns the file. Older backup files waiting in the outgoing folder are
  /// removed first.
  Future<File> create(String password, {DateTime? now}) async {
    final createdUtc = (now ?? DateTime.now()).toUtc();
    final records = <String, List<Map<String, Object?>>>{};
    // One transaction, so the backup is a consistent snapshot.
    await _db.transaction(() async {
      for (final t in _db.allTables) {
        final rows = await _db.customSelect('SELECT * FROM "${t.actualTableName}" ORDER BY rowid').get();
        records[t.actualTableName] = [for (final r in rows) r.data];
      }
    });
    final attachments = AttachmentRepository(_db, _documents);
    final files = <String, BackupFileEntry>{};
    for (final a in await _db.select(_db.attachments).get()) {
      final file = attachments.fileFor(a.sha256, a.fileName);
      // A missing file is left out; its row still restores.
      if (file.existsSync()) files[p.basename(file.path)] = (name: p.basename(file.path), sha256: a.sha256, path: file.path);
    }

    final outgoing = _folders.outgoing;
    if (outgoing.existsSync()) await outgoing.delete(recursive: true);
    await outgoing.create(recursive: true);
    final path = p.join(outgoing.path, 'Trakta-backup-${createdUtc.toIso8601String().substring(0, 10)}.${BackupFile.extension}');
    await _writeInBackground(path, password, _db.schemaVersion, createdUtc, records, files.values.toList());
    return File(path);
  }

  /// Remembers that a backup was made, for "Last backup" in Settings.
  Future<void> markBackedUp(DateTime createdUtc) =>
      _db.update(_db.profiles).write(ProfilesCompanion(lastBackupUtc: Value(createdUtc.toUtc())));

  /// Copies a picked backup into the app, opens it with [password] and checks
  /// all of it, without changing anything yet. Throws [BackupException].
  Future<BackupPreview> open(Stream<List<int>> content, String password) async {
    final incoming = _folders.incoming;
    if (incoming.existsSync()) await incoming.delete(recursive: true);
    await incoming.create(recursive: true);
    final copy = File(p.join(incoming.path, 'backup.${BackupFile.extension}'));
    final sink = copy.openWrite();
    await sink.addStream(content);
    await sink.close();

    final path = copy.path;
    final staging = p.join(incoming.path, 'documents');
    final BackupContents contents;
    try {
      contents = await _readInBackground(path, password, staging);
    } finally {
      // Holds the user's data: never leave it lying around.
      if (copy.existsSync()) await copy.delete();
    }
    if (contents.schemaVersion > _db.schemaVersion) throw const BackupException(BackupError.newerApp);
    // Schema 1 is the first; when it changes, rows from backups of older
    // versions are converted here, like the database migrations do.

    final tables = {for (final t in _db.allTables) t.actualTableName: t};
    final rows = <TableInfo, List<Insertable>>{};
    try {
      for (final MapEntry(key: name, value: list) in contents.records.entries) {
        final table = tables[name] ?? (throw const BackupException(BackupError.damaged));
        rows[table] = [for (final r in list) table.map(r) as Insertable];
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      // A row that does not fit the table: missing or wrongly typed values.
      throw const BackupException(BackupError.damaged);
    }
    final profiles = rows[_db.profiles] ?? const [];
    if (profiles.length != 1 || (profiles.single as ProfileRow).id != 1) {
      throw const BackupException(BackupError.damaged);
    }
    return BackupPreview._(contents.createdUtc, rows, Directory(staging), contents.files);
  }

  /// Replaces all data and documents on this phone with [backup]. The
  /// database part is one transaction: if it fails, nothing changed.
  Future<void> restore(BackupPreview backup) async {
    await _db.transaction(() async {
      // Rows reference each other (a trip continuing another); check the
      // references once everything is in.
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');
      for (final t in _db.allTables.toList().reversed) {
        await _db.delete(t).go();
      }
      await _db.batch((b) {
        for (final t in _db.allTables) {
          final rows = backup._rows[t];
          if (rows != null && rows.isNotEmpty) b.insertAll(t, rows);
        }
      });
      await markBackedUp(backup.createdUtc);
    });

    // Documents: move the backup's files in, then delete the files of the
    // replaced data.
    await _documents.create(recursive: true);
    for (final name in backup._files) {
      final target = File(p.join(_documents.path, name));
      if (target.existsSync()) continue;
      final staged = File(p.join(backup._staging.path, name));
      try {
        await staged.rename(target.path);
      } on FileSystemException {
        await staged.copy(target.path);
      }
    }
    final attachments = AttachmentRepository(_db, _documents);
    final used = {
      for (final a in await _db.select(_db.attachments).get()) p.basename(attachments.fileFor(a.sha256, a.fileName).path),
    };
    for (final f in _documents.listSync().whereType<File>()) {
      final name = p.basename(f.path);
      if (BackupFile.isDocumentName(name) && !used.contains(name)) await f.delete();
    }
    await discard(backup);
  }

  /// Deletes what [open] unpacked, e.g. when the user cancels.
  Future<void> discard(BackupPreview backup) async {
    if (_folders.incoming.existsSync()) await _folders.incoming.delete(recursive: true);
  }
}

/// A checked backup, ready to restore. The counts are for the confirmation.
class BackupPreview {
  BackupPreview._(this.createdUtc, this._rows, this._staging, this._files);

  final DateTime createdUtc;
  final Map<TableInfo, List<Insertable>> _rows;
  final Directory _staging;
  final List<String> _files;

  /// How many rows [table] has in the backup.
  int count(TableInfo table) => _rows[table]?.length ?? 0;
}

// Top level, so the isolate closures capture only their arguments and never
// the repository (whose database cannot be sent to another isolate).
Future<void> _writeInBackground(
  String path,
  String password,
  int schemaVersion,
  DateTime createdUtc,
  Map<String, List<Map<String, Object?>>> records,
  List<BackupFileEntry> files,
) =>
    Isolate.run(() => BackupFile.write(
          path: path,
          password: password,
          schemaVersion: schemaVersion,
          createdUtc: createdUtc,
          records: records,
          files: files,
        ));

Future<BackupContents> _readInBackground(String path, String password, String stagingDir) =>
    Isolate.run(() => BackupFile.read(path: path, password: password, stagingDir: stagingDir));
