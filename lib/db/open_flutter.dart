/// Opening the encrypted database on a phone.
///
/// ── The whole encryption decision, in one file ────────────────────────────
/// SQLCipher is SQLite with encryption compiled in. Same SQL, same Drift, same
/// migrations, same tests. The only difference is which native library gets
/// loaded and one statement issued before the first read — which is why
/// `tables.dart`, `mapping.dart`, `repository.dart` and every test know
/// nothing about any of this.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'tables.dart';

const _keyName = 'stash-it-db-key-v1';
const _fileName = 'stash-it.db';

/// Points `package:sqlite3` at SQLCipher rather than the system SQLite.
///
/// Must run before anything opens a database. Called by `openEncrypted`, and
/// safe to call twice.
/// Android only for now — the iOS override is a one-liner and belongs with the
/// first iOS build, not before it.
void useSqlCipher() {
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
}

/// The database, encrypted, with its key from the platform keystore.
///
/// ── What "lost key, lost data" actually means ─────────────────────────────
/// The key is generated once, on this device, and written to the Android
/// Keystore or the iOS Keychain. It never leaves the phone — that is the point
/// — and it means a factory reset, an uninstall, or a restore onto a new
/// handset produces a database file **nobody can open, including us**.
///
/// The backup file is the only way back, which makes "have you backed up"
/// load-bearing in a way it was not before. `backupStatus` in nudges.dart is
/// the line on the dashboard that says so, and it never goes away.
Future<StashDatabase> openEncrypted() async {
  useSqlCipher();

  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, _fileName));

  final key = await _keyHex();

  return StashDatabase(NativeDatabase(
    file,
    setup: (raw) {
      /*
        A raw hex key, not a passphrase.

        `PRAGMA key = 'something'` runs a key derivation over the string, which
        is right when a human typed it and pointless when 32 random bytes came
        out of a keystore. The `x'...'` form takes the bytes as the key
        directly — and, more usefully here, it contains no character that could
        need quoting.
      */
      raw.execute("PRAGMA key = \"x'$key'\";");

      /*
        THE CHECK THAT MATTERS MOST IN THIS FILE.

        If the SQLCipher library failed to load, `package:sqlite3` falls back
        to the system SQLite, which accepts `PRAGMA key` as an unknown pragma
        and **ignores it silently**. The database then works perfectly and is
        completely unencrypted, and nothing anywhere would ever say so.

        `cipher_version` returns a row only on a real SQLCipher build. No row
        means stop.
      */
      final version = raw.select('PRAGMA cipher_version;');
      if (version.isEmpty) {
        throw StateError(
          'SQLCipher did not load — the database would be written unencrypted. '
          'Refusing to open it.',
        );
      }
    },
  ));
}

/// The key, made once and kept in hardware-backed storage from then on.
Future<String> _keyHex() async {
  const store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final existing = await store.read(key: _keyName);
  if (existing != null && existing.length == 64) return existing;

  // 32 bytes, from the platform's cryptographic source. `Random.secure()`
  // throws rather than falling back to a predictable generator if none is
  // available, which is the behaviour worth having here.
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  await store.write(key: _keyName, value: hex);
  return hex;
}

/// Only used to prove a point in the developer tools: the raw bytes of the
/// file, so someone can see for themselves that it does not begin with
/// `SQLite format 3`.
Future<String> databaseHeader() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, _fileName));
  if (!file.existsSync()) return 'no database yet';

  final head = file.openSync().readSync(16);
  return base64Encode(head);
}
