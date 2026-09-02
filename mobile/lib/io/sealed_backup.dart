/// The backup, with the lock on it if there is one, in one pass.
///
/// ── One place that decides, so nothing can forget ──────────────────────────
/// There are two ways a backup leaves this app — the share sheet and the
/// automatic write into a folder — and there will be more. If each of them
/// asked "is there a passphrase" for itself, then the day somebody adds a third
/// is the day one route starts writing plaintext, and nothing would say so.
///
/// So neither of them asks. They call this, and this decides.
///
/// ── And one isolate, because the file is large ─────────────────────────────
/// Locking a backup took eighty seconds, then twenty, on a phone whose cipher
/// was measured at 90 MB/s and whose key derivation costs 1.6 seconds once.
/// The work was never the problem. The problem was that the finished file
/// crossed a boundary six times on its way out:
///
///     zipped in an isolate, copied back to the main isolate, copied into a
///     second isolate to be encrypted, copied through a method channel to
///     javax.crypto, copied back, copied out, and only then written to disk.
///
/// Every one of those is the whole backup. So the zip, the encryption and the
/// write now happen in ONE isolate that is handed the records and given a path,
/// and nothing comes back at all. Reading does the same in reverse: the isolate
/// is handed a path and returns the parsed bundle, once.
///
/// That is the whole reason this file's functions take paths rather than bytes.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../db/backup.dart';
import '../db/tables.dart';
import '../logic/backup_progress.dart';
import '../logic/bundle.dart';
import '../logic/vault.dart';
import 'bundle_file.dart';
import 'vault.dart';

/* ------------------------------------------------------------------ out */

/// Gathers everything, seals it if there is a passphrase, and writes it to
/// [path]. Nothing is returned, because nothing needs to come back.
Future<void> exportSealedBackupToFile(
  StashDatabase db, {
  required String path,
  BackupWatcher? onStep,
}) async {
  // The one part that must be on the main isolate: it reads the database.
  final contents = await gatherBackup(db, onStep: onStep);

  final material = await lockingMaterial();

  onStep?.call(BackupProgress(
    material == null ? BackupStage.sealing : BackupStage.locking,
  ));

  await compute(_writeOut, (
    tables: contents.tables,
    blobs: contents.blobs,
    counts: contents.counts,
    path: path,
    salt: material?.salt,
    key: material?.key,
    nonce: material == null ? null : freshNonce(),
    token: RootIsolateToken.instance,
  ));

  await markBackedUp(db);
  onStep?.call(const BackupProgress(BackupStage.done));
}

/// Zip, encrypt, write. All of it here, on one isolate, with nothing returned.
Future<void> _writeOut(
  ({
    Map<String, Object?> tables,
    Map<String, List<int>> blobs,
    (int, int, int) counts,
    String path,
    Uint8List? salt,
    Uint8List? key,
    Uint8List? nonce,
    RootIsolateToken? token,
  }) work,
) async {
  final watch = Stopwatch()..start();

  final zipped = writeBundle(
    tables: work.tables,
    blobs: work.blobs,
    manifestOverrides: {
      'counts': {
        'items': work.counts.$1,
        'docs': work.counts.$2,
        'blobs': work.counts.$3,
      },
    },
  );
  final zippedAt = watch.elapsedMilliseconds;

  // Unlocked backups skip all of this and are written as they always were.
  final bytes = work.key == null
      ? flatBytes(zipped)
      : (await sealInIsolate((
          plain: flatBytes(zipped),
          salt: work.salt!,
          key: work.key!,
          nonce: work.nonce!,
          token: work.token,
        )))
          .bytes;
  final sealedAt = watch.elapsedMilliseconds;

  await File(work.path).writeAsBytes(bytes, flush: true);

  lastVaultTimings = 'wrote ${(bytes.length / 1024 / 1024).toStringAsFixed(1)}'
      ' MB\n  zip     $zippedAt ms'
      '\n  seal    ${sealedAt - zippedAt} ms'
      '\n  to disk ${watch.elapsedMilliseconds - sealedAt} ms'
      '\n  total   ${watch.elapsedMilliseconds} ms in one isolate';
}

/* ------------------------------------------------------------------- in */

/// A backup that has been opened, and whether it had to be.
class OpenedBackup {
  const OpenedBackup({required this.bundle, required this.wasLocked});

  final ParsedBundle bundle;

  /// True when the file was encrypted — whether or not anybody was asked for
  /// the passphrase.
  ///
  /// ── Silence is not an answer ─────────────────────────────────────────────
  /// Restoring on the same phone opens a locked backup without asking, because
  /// the passphrase is already held. That is the right behaviour and it looks
  /// exactly like restoring a file that was never locked — so the app says
  /// which it was afterwards, rather than leaving somebody to wonder whether
  /// the lock is working at all.
  final bool wasLocked;
}

/// Reads a `.stashit` from [path], opening it if it is locked, and parses it.
///
/// [ask] is called only when the file is sealed AND the passphrase on this
/// phone does not open it — which is the case that matters: a backup restored
/// onto a NEW phone. Returning null from [ask] means they gave up, and that
/// comes back as a [VaultProblem] rather than as a half-restore.
///
/// Throws [VaultProblem] or [BundleError], both with a sentence for a person.
Future<OpenedBackup> openBackupFile(
  String path, {
  required Future<String?> Function() ask,
}) async {
  /*
    ── The first forty-two bytes decide everything ────────────────────────────

    Whether the file is locked, and whether this phone's own key opens it, are
    both answered by the header. Reading the whole file to find that out — and
    then handing it to an isolate that reads it again — is what the old shape
    did, and the file is the expensive thing in this feature.
  */
  final head = await _firstBytes(path, vaultHeaderBytes);
  final locked = looksEncrypted(head);

  Uint8List? key;
  String passphrase = '';

  if (locked) {
    final header = readVaultHeader(head);
    final mine = await lockingMaterial();

    if (mine != null && _sameBytes(mine.salt, header.salt)) {
      // This phone made it. No derivation, no question.
      key = mine.key;
    } else {
      /*
        Either it came from another phone, or the passphrase has changed since.
        Ask, and derive inside the isolate from the salt in the file.

        `backupPassphrase` is tried first even though the salt did not match:
        somebody may have set the same passphrase again after a reinstall, in
        which case a fresh salt means a different key but the same words.
      */
      passphrase = await backupPassphrase() ?? '';

      if (passphrase.isEmpty) {
        final typed = await ask();
        if (typed == null || typed.trim().isEmpty) {
          throw const VaultProblem(
            'That backup is locked and was not opened.',
          );
        }
        passphrase = typed;
      }
    }
  }

  try {
    return OpenedBackup(
      bundle: await compute(_readIn, (
        path: path,
        key: key,
        passphrase: passphrase,
        token: RootIsolateToken.instance,
      )),
      wasLocked: locked,
    );
  } on VaultProblem {
    // The stored passphrase was the wrong one after all. One more chance, with
    // the words rather than the key.
    if (!locked) rethrow;

    final typed = await ask();
    if (typed == null || typed.trim().isEmpty) {
      throw const VaultProblem('That backup is locked and was not opened.');
    }

    return OpenedBackup(
      bundle: await compute(_readIn, (
        path: path,
        key: null,
        passphrase: typed,
        token: RootIsolateToken.instance,
      )),
      wasLocked: true,
    );
  }
}

/// Read, decrypt, unzip, hash, parse. All of it here, on one isolate.
Future<ParsedBundle> _readIn(
  ({
    String path,
    Uint8List? key,
    String passphrase,
    RootIsolateToken? token,
  }) work,
) async {
  final watch = Stopwatch()..start();

  final raw = await File(work.path).readAsBytes();
  final readAt = watch.elapsedMilliseconds;

  final plain = looksEncrypted(raw)
      ? (await openInIsolate((
          sealed: raw,
          passphrase: work.passphrase,
          key: work.key,
          token: work.token,
        )))
          .bytes
      : raw;
  final openedAt = watch.elapsedMilliseconds;

  final bundle = parseBackupBytes(plain);

  lastVaultTimings = 'read ${(raw.length / 1024 / 1024).toStringAsFixed(1)}'
      ' MB\n  from disk $readAt ms'
      '\n  unlock    ${openedAt - readAt} ms'
      '\n  parse     ${watch.elapsedMilliseconds - openedAt} ms'
      '\n  total     ${watch.elapsedMilliseconds} ms in one isolate';

  return bundle;
}

/* -------------------------------------------------------------- plumbing */

/// The first [count] bytes of a file, without reading the rest of it.
Future<Uint8List> _firstBytes(String path, int count) async {
  final handle = await File(path).open();

  try {
    return await handle.read(count);
  } finally {
    await handle.close();
  }
}

/// Whether two byte strings are the same. Only ever used on salts, which are
/// not secret — a constant-time compare would be theatre here.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}
