import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../db/database.dart';

/// What an attachment belongs to.
abstract final class AttachmentOwner {
  static const trip = 'trip';

  /// A commuting cost: the congestion tax invoice, a parking receipt.
  static const commuteExpense = 'commute_expense';

  /// A business drive: toll receipts, the meeting it was for.
  static const mileageEntry = 'mileage_entry';
}

/// A file copied into the app, not yet linked to a record. The trip form
/// keeps these until the trip is saved.
class StoredFile {
  const StoredFile({required this.fileName, required this.sha256, required this.sizeBytes});

  final String fileName;
  final String sha256;
  final int sizeBytes;
}

/// Documents kept with trips. Files are copied into [root] (the app's
/// private storage, not shared with other apps) under their SHA-256, so the
/// same file is stored once however often it is added. Nothing leaves the
/// phone.
class AttachmentRepository {
  AttachmentRepository(this._db, this.root);

  final AppDatabase _db;

  /// The folder files are kept in.
  final Directory root;

  /// Where the file for [sha256] (with the extension of [fileName]) lives.
  File fileFor(String sha256, String fileName) =>
      File(p.join(root.path, '$sha256${p.extension(fileName).toLowerCase()}'));

  /// Copies a file's [content] into the app and returns what to store about
  /// it. The content is written to a temporary file while it is hashed, then
  /// renamed to its hash (or dropped if that file is already there).
  Future<StoredFile> import(String fileName, Stream<List<int>> content) async {
    await root.create(recursive: true);
    final temp = File(p.join(root.path, '.import-${DateTime.now().microsecondsSinceEpoch}'));
    final hashSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(hashSink);
    final out = temp.openWrite();
    var size = 0;
    try {
      await for (final chunk in content) {
        hasher.add(chunk);
        out.add(chunk);
        size += chunk.length;
      }
    } finally {
      await out.close();
      hasher.close();
    }
    final hash = hashSink.value.toString();
    final target = fileFor(hash, fileName);
    if (target.existsSync()) {
      await temp.delete();
    } else {
      await temp.rename(target.path);
    }
    return StoredFile(fileName: fileName, sha256: hash, sizeBytes: size);
  }

  Stream<List<AttachmentRow>> watch(String ownerType, int ownerId) => (_db.select(_db.attachments)
        ..where((a) => a.ownerType.equals(ownerType) & a.ownerId.equals(ownerId))
        ..orderBy([(a) => OrderingTerm.asc(a.createdUtc), (a) => OrderingTerm.asc(a.id)]))
      .watch();

  /// How many documents each record of [ownerType] has, by record id.
  Stream<Map<int, int>> watchCounts(String ownerType) =>
      (_db.select(_db.attachments)..where((a) => a.ownerType.equals(ownerType))).watch().map((rows) {
        final counts = <int, int>{};
        for (final r in rows) {
          counts[r.ownerId] = (counts[r.ownerId] ?? 0) + 1;
        }
        return counts;
      });

  Future<void> add(String ownerType, int ownerId, Iterable<StoredFile> files) async {
    await _db.batch((b) {
      b.insertAll(_db.attachments, [
        for (final f in files)
          AttachmentsCompanion.insert(
            ownerType: ownerType,
            ownerId: ownerId,
            fileName: f.fileName,
            sha256: f.sha256,
            sizeBytes: f.sizeBytes,
            createdUtc: DateTime.now().toUtc(),
          ),
      ]);
    });
  }

  Future<void> remove(AttachmentRow row) async {
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(row.id))).go();
    await discard([StoredFile(fileName: row.fileName, sha256: row.sha256, sizeBytes: row.sizeBytes)]);
  }

  /// Removes everything attached to a record, e.g. when the trip is deleted.
  Future<void> removeAll(String ownerType, int ownerId) async {
    final rows = await (_db.select(_db.attachments)
          ..where((a) => a.ownerType.equals(ownerType) & a.ownerId.equals(ownerId)))
        .get();
    for (final r in rows) {
      await remove(r);
    }
  }

  /// Deletes copied files that no record uses, e.g. files picked in a form
  /// that was then cancelled.
  Future<void> discard(Iterable<StoredFile> files) async {
    for (final f in files) {
      final used = await (_db.select(_db.attachments)..where((a) => a.sha256.equals(f.sha256))).get();
      if (used.isNotEmpty) continue;
      final file = fileFor(f.sha256, f.fileName);
      if (file.existsSync()) await file.delete();
    }
  }
}

/// "1.2 MB" style size for a list row.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} kB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Collects the single digest a chunked hash conversion produces.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
