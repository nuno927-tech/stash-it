/// The backup, with the lock on it if there is one.
///
/// ── One place that decides, so nothing can forget ──────────────────────────
/// There are two ways a backup leaves this app — the share sheet and the
/// automatic write into a folder — and there will be more. If each of them
/// asked "is there a passphrase" for itself, then the day somebody adds a third
/// is the day one route starts writing plaintext, and nothing would say so.
///
/// So neither of them asks. They call this, and this decides.
///
/// ── And one that opens, whatever it is handed ──────────────────────────────
/// The same on the way back in. A restore is handed bytes from a file picker
/// and has no idea what they are: a plain zip from any version this app has
/// ever had, or a sealed file from this one. `openBackupBytes` sniffs the magic
/// and does the right thing, which is what keeps every backup ever made
/// openable by every version after it.
library;

import '../db/tables.dart';
import '../logic/backup_progress.dart';
import '../logic/vault.dart';
import 'bundle_file.dart';
import 'vault.dart';

/// Everything, sealed if a passphrase is set.
///
/// The progress callback belongs to the gathering, which is the slow part on a
/// collection with photographs in it. Encrypting a sealed backup adds a second
/// or two on top and gets no bar of its own — a bar that fills and then sits at
/// the end for a beat reads as a hang, and one that goes back to the beginning
/// reads as a fault.
Future<List<int>> exportSealedBackup(
  StashDatabase db, {
  BackupWatcher? onStep,
}) async {
  final plain = await exportBackup(db, onStep: onStep);

  final passphrase = await backupPassphrase();
  if (passphrase == null) return plain;

  return lockBackup(plain, passphrase);
}

/// The bytes of a backup, whatever kind it is, ready for `parseBackupBytes`.
///
/// [ask] is called only when the file is sealed AND the passphrase on this
/// phone does not open it — which is the case that matters: a backup restored
/// onto a NEW phone, where nothing is stored yet and the person has to have
/// written it down. Returning null from [ask] means they gave up, and that
/// comes back as a [VaultProblem] rather than as a half-restore.
///
/// Throws [VaultProblem] with a sentence for a person.
Future<List<int>> openBackupBytes(
  List<int> bytes, {
  required Future<String?> Function() ask,
}) async {
  // Every backup this app made before today, and every one made with the lock
  // off. Untouched, straight through.
  if (!looksEncrypted(bytes)) return bytes;

  /*
    The passphrase on this phone, tried first and silently.

    Restoring onto the same phone is the common case — somebody undoing a bad
    import, or moving back after a mistake — and asking them to type a
    passphrase the app is already holding would be theatre.
  */
  final mine = await backupPassphrase();
  if (mine != null) {
    try {
      return await unlockBackup(bytes, mine);
    } on VaultProblem {
      // Wrong one. Which is not an error yet: a backup from an older
      // passphrase, or from another phone, is a thing somebody may well be
      // restoring on purpose.
    }
  }

  final typed = await ask();
  if (typed == null || typed.trim().isEmpty) {
    throw const VaultProblem('That backup is locked and was not opened.');
  }

  return unlockBackup(bytes, typed);
}
