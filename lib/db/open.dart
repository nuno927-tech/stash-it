/// Opening the database, and where the encryption lives.
///
/// ── The whole design, in one sentence ─────────────────────────────────────
/// **Nothing above this file knows whether the database is encrypted.** The
/// tables, the queries, the migrations and every test are identical either
/// way; SQLCipher is the same SQLite with a `PRAGMA key` and a different
/// binary, so the difference is which library gets loaded and one statement
/// issued before the first read.
///
/// That is why this is its own file, and why it is short.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

/// A database that exists only for the length of a test.
///
/// `setUp` gets a clean one, `tearDown` throws it away, and nothing touches a
/// disk — which is what makes it reasonable to open a real database in a unit
/// test rather than mocking one.
StashDatabase openInMemory() {
  /*
    Drift warns when a database class is constructed twice, because two
    instances sharing one executor race each other and can corrupt the file.

    That is not what is happening here. Every call makes its own
    `NativeDatabase.memory()` — a fresh, private, disk-less executor — so there
    is nothing shared to race over. The warning is correct in general and noise
    in this one place, and it is loud enough to bury the actual failure in a
    test run.

    Set here rather than in each test file so the reason lives next to the
    thing it is about.
  */
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return StashDatabase(NativeDatabase.memory());
}

/// A database in a file, unencrypted.
///
/// For desktop runs and for the command-line tools. **Not what the phone
/// uses** — see below.
StashDatabase openFile(String path) => StashDatabase(NativeDatabase(File(path)));

/*
  ── What the phone will do instead, and why it is not written yet ─────────

  The encrypted opener needs three things this package does not have, because
  all three are Flutter:

    sqlcipher_flutter_libs   the engine, with encryption compiled in
    flutter_secure_storage   the key, held in the Android Keystore / Keychain
    path_provider            somewhere to put the file

  It arrives with the app shell in phase 3, and looks like this:

      final key = await secureStorage.read(key: 'db-key') ?? _newKey();
      return StashDatabase(NativeDatabase(
        file,
        setup: (raw) => raw.execute("PRAGMA key = '\$key'"),
      ));

  ── Three things that will need deciding then, not now ────────────────────

  **A lost key is lost data.** The key lives in hardware-backed storage and
  never leaves the phone, which is the point — and it means an uninstall, a
  factory reset, or a restore onto a new handset produces a database nobody
  can open, including us. The backup file is the answer, which makes "have you
  backed up" load-bearing in a way it was not before. The nudge that says so
  is already written.

  **Android's auto-backup will happily copy the database off the device** and
  restore it somewhere the key does not exist, producing exactly that
  unopenable file. The manifest has to exclude it.

  **The first open after upgrading an existing install has to migrate.** Any
  user who already has a plaintext database needs it read, re-keyed and
  rewritten once. SQLCipher's `sqlcipher_export` does it in a few statements,
  but it is a one-way door and wants its own test before anyone runs it on
  data they care about.
*/
