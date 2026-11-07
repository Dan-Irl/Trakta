import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the encrypted database.
///
/// SQLite3MultipleCiphers is selected by `hooks: user_defines: sqlite3:
/// source: sqlite3mc` in the workspace pubspec. A random 256-bit key is
/// created on first launch and kept in Keychain/Keystore. The app refuses to
/// open the file if the cipher is missing, so it can never silently fall back
/// to an unencrypted database.
QueryExecutor openEncryptedDatabase() {
  return LazyDatabase(() async {
    final key = await DatabaseKeyStore().getOrCreateKey();
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'trakta.db'));
    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        final cipher = db.select('PRAGMA cipher;');
        if (cipher.isEmpty) {
          throw StateError('SQLite3MultipleCiphers is not available. Refusing to open an unencrypted database.');
        }
        // The key is hex, so it cannot break out of the string literal.
        db.execute("PRAGMA key = '$key';");
        // Fails with "file is not a database" if the key is wrong.
        db.execute('SELECT count(*) FROM sqlite_master;');
      },
    );
  });
}

/// Keeps the database key in the platform's secure storage.
class DatabaseKeyStore {
  DatabaseKeyStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'trakta_db_key_v1';
  final FlutterSecureStorage _storage;

  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      // Never replace an existing key: that would make the database unreadable.
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(existing)) {
        throw StateError('Stored database key has an unexpected format.');
      }
      return existing;
    }
    final rnd = Random.secure();
    final key = List.generate(32, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}
