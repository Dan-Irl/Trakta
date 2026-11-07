import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// The `.trakta` backup file: everything the user entered plus their
/// documents, in one file they keep wherever they like and restore on a new
/// phone (Android or iPhone).
///
/// The file is an SQLite database encrypted by SQLite3MultipleCiphers in the
/// standard SQLCipher 4 format: AES-256 with an HMAC on every page and a key
/// derived from the user's password with PBKDF2-HMAC-SHA512 (256 000
/// iterations). A wrong password, a damaged file or one that was tampered with
/// all fail to open. The format is public, so the user can also open their
/// backup with any SQLCipher tool (e.g. DB Browser for SQLite).
///
/// Inside, the tables are generic so this file does not depend on the app's
/// schema:
///
/// * `meta`: format, schema version, creation time.
/// * `records`: one row per database row, as JSON of its SQL values.
/// * `files`: the documents, named as in the app's document folder.
///
/// The functions here are synchronous and run in a background isolate.
abstract final class BackupFile {
  /// Bumped when the layout above changes in a way older apps cannot read.
  static const format = 1;
  static const extension = 'trakta';

  /// Writes a new backup to [path]. [records] holds each table's rows by
  /// table name; [files] the documents to include.
  static void write({
    required String path,
    required String password,
    required int schemaVersion,
    required DateTime createdUtc,
    required Map<String, List<Map<String, Object?>>> records,
    required List<BackupFileEntry> files,
  }) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    final db = _open(path, password);
    try {
      db.execute('''
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE records (tbl TEXT NOT NULL, row TEXT NOT NULL);
        CREATE TABLE files (name TEXT PRIMARY KEY, sha256 TEXT NOT NULL, data BLOB NOT NULL);
      ''');
      db.execute('BEGIN');
      final meta = db.prepare('INSERT INTO meta (key, value) VALUES (?, ?)');
      for (final e in {
        'app': 'trakta',
        'format': '$format',
        'schemaVersion': '$schemaVersion',
        'createdUtc': createdUtc.toUtc().toIso8601String(),
      }.entries) {
        meta.execute([e.key, e.value]);
      }
      meta.close();
      final rows = db.prepare('INSERT INTO records (tbl, row) VALUES (?, ?)');
      for (final MapEntry(key: table, value: list) in records.entries) {
        for (final row in list) {
          rows.execute([table, jsonEncode(row)]);
        }
      }
      rows.close();
      final blobs = db.prepare('INSERT INTO files (name, sha256, data) VALUES (?, ?, ?)');
      for (final f in files) {
        blobs.execute([f.name, f.sha256, File(f.path).readAsBytesSync()]);
      }
      blobs.close();
      db.execute('COMMIT');
    } catch (_) {
      db.close();
      if (file.existsSync()) file.deleteSync();
      rethrow;
    }
    db.close();
  }

  /// Opens and checks the backup at [path]: the password, the format, every
  /// row's JSON and every document's SHA-256. The documents are written to
  /// [stagingDir], not yet into the app. Throws [BackupException].
  static BackupContents read({required String path, required String password, required String stagingDir}) {
    final Database db;
    try {
      db = _open(path, password);
    } on SqliteException {
      throw const BackupException(BackupError.wrongPasswordOrDamaged);
    }
    try {
      db.select('SELECT count(*) FROM sqlite_master');
    } on SqliteException {
      db.close();
      throw const BackupException(BackupError.wrongPasswordOrDamaged);
    }
    try {
      final Map<String, String> meta;
      try {
        meta = {for (final r in db.select('SELECT key, value FROM meta')) r['key'] as String: r['value'] as String};
      } on SqliteException {
        throw const BackupException(BackupError.notABackup);
      }
      if (meta['app'] != 'trakta') throw const BackupException(BackupError.notABackup);
      final fileFormat = int.tryParse(meta['format'] ?? '');
      final schemaVersion = int.tryParse(meta['schemaVersion'] ?? '');
      final createdUtc = DateTime.tryParse(meta['createdUtc'] ?? '');
      if (fileFormat == null || schemaVersion == null || createdUtc == null) {
        throw const BackupException(BackupError.damaged);
      }
      if (fileFormat > format) throw const BackupException(BackupError.newerApp);

      final records = <String, List<Map<String, Object?>>>{};
      for (final r in db.select('SELECT tbl, row FROM records ORDER BY rowid')) {
        final row = jsonDecode(r['row'] as String);
        if (row is! Map<String, Object?>) throw const BackupException(BackupError.damaged);
        (records[r['tbl'] as String] ??= []).add(row);
      }

      final staging = Directory(stagingDir)..createSync(recursive: true);
      final files = <String>[];
      for (final r in db.select('SELECT name, sha256 FROM files')) {
        final name = r['name'] as String;
        final hash = r['sha256'] as String;
        // Names come from the file and are used as paths: only the app's own
        // "<sha256><extension>" names are accepted.
        if (!isDocumentName(name) || !name.startsWith(hash)) throw const BackupException(BackupError.damaged);
        final data = db.select('SELECT data FROM files WHERE name = ?', [name]).single['data'] as List<int>;
        if (sha256.convert(data).toString() != hash) throw const BackupException(BackupError.damaged);
        File(p.join(staging.path, name)).writeAsBytesSync(data);
        files.add(name);
      }
      return BackupContents(schemaVersion: schemaVersion, createdUtc: createdUtc.toUtc(), records: records, files: files);
    } on SqliteException {
      // A page whose HMAC does not match: the file was damaged or changed.
      throw const BackupException(BackupError.damaged);
    } on FormatException {
      throw const BackupException(BackupError.damaged);
    } on TypeError {
      throw const BackupException(BackupError.damaged);
    } finally {
      db.close();
    }
  }

  /// A document's file name in the app's folder: its SHA-256 plus the
  /// original extension, without any path.
  static bool isDocumentName(String name) =>
      RegExp(r'^[0-9a-f]{64}(\.[^/\\]*)?$').hasMatch(name) && !name.contains('..');

  static Database _open(String path, String password) {
    final db = sqlite3.open(path);
    try {
      if (db.select('PRAGMA cipher;').isEmpty) {
        throw StateError('SQLite3MultipleCiphers is not available. Refusing to write an unencrypted backup.');
      }
      db.execute("PRAGMA cipher = 'sqlcipher';");
      db.execute('PRAGMA legacy = 4;');
      // A string literal: quotes are doubled, so any password is safe here.
      db.execute("PRAGMA key = '${password.replaceAll("'", "''")}';");
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }
}

/// A document to put in the backup: its name in the app's folder, its
/// SHA-256 and where it is now.
typedef BackupFileEntry = ({String name, String sha256, String path});

/// What [BackupFile.read] found. The documents are in the staging folder.
class BackupContents {
  const BackupContents({
    required this.schemaVersion,
    required this.createdUtc,
    required this.records,
    required this.files,
  });

  final int schemaVersion;
  final DateTime createdUtc;
  final Map<String, List<Map<String, Object?>>> records;
  final List<String> files;
}

enum BackupError {
  /// The password is wrong, or the file is not an encrypted Trakta backup.
  /// SQLCipher cannot tell these apart.
  wrongPasswordOrDamaged,

  /// It opens, but it is not a Trakta backup.
  notABackup,

  /// It was made by a newer version of Trakta.
  newerApp,

  /// It opens, but the content is damaged or changed.
  damaged,
}

class BackupException implements Exception {
  const BackupException(this.error);
  final BackupError error;

  @override
  String toString() => 'BackupException(${error.name})';
}
