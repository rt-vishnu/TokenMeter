import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/services/secure_storage_config.dart';

const _dbEncryptionKeyName = 'db_encryption_key';
const _dbFileName = 'token_meter.sqlite';

/// Returns the path where the encrypted database is stored (Application Support).
Future<String> databaseFilePath() async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, _dbFileName);
}

/// Opens an encrypted [NativeDatabase], migrating a legacy plaintext file if needed.
Future<NativeDatabase> openEncryptedDatabase() async {
  final path = await databaseFilePath();
  final file = File(path);
  final key = await _ensureDbEncryptionKey(appSecureStorage);

  await _migrateLegacyPlaintextIfNeeded(file, key);

  return NativeDatabase(
    file,
    setup: (rawDb) {
      _assertCipherAvailable(rawDb);
      rawDb.execute("PRAGMA key = '${_escapeSqlString(key)}';");
      // Verify the key before drift uses the database.
      rawDb.execute('SELECT count(*) FROM sqlite_master');
    },
  );
}

Future<String> _ensureDbEncryptionKey(FlutterSecureStorage secure) async {
  final existing = await secure.read(key: _dbEncryptionKeyName);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = base64UrlEncode(bytes);
  await secure.write(key: _dbEncryptionKeyName, value: key);
  return key;
}

/// Moves an unencrypted DB from Documents → Support and encrypts it in place.
Future<void> _migrateLegacyPlaintextIfNeeded(File target, String key) async {
  if (await target.exists()) return;

  final docsDir = await getApplicationDocumentsDirectory();
  final legacy = File(p.join(docsDir.path, _dbFileName));
  if (!await legacy.exists()) return;

  await target.parent.create(recursive: true);
  await legacy.copy(target.path);
  await _encryptPlaintextFile(target, key);
  await legacy.delete();
}

Future<void> _encryptPlaintextFile(File file, String key) async {
  final tmp = File('${file.path}.encrypting');
  if (await tmp.exists()) await tmp.delete();

  final plain = sqlite3.open(file.path);
  try {
    plain.execute("VACUUM INTO '${_escapeSqlString(tmp.path)}';");
  } finally {
    plain.close();
  }

  final encrypted = sqlite3.open(tmp.path);
  try {
    encrypted.execute("PRAGMA rekey = '${_escapeSqlString(key)}';");
  } finally {
    encrypted.close();
  }

  await file.delete();
  await tmp.rename(file.path);
}

void _assertCipherAvailable(Database database) {
  if (database.select('PRAGMA cipher;').isEmpty) {
    throw StateError(
      'Encrypted SQLite (sqlite3mc) is not available. '
      'Check pubspec hooks: sqlite3 source must be sqlite3mc.',
    );
  }
}

String _escapeSqlString(String source) => source.replaceAll("'", "''");
