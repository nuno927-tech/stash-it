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
  /*
    ── The bar must not finish before the work does ───────────────────────────

    `exportBackup` announces `done` when the zip is written, which was true
    before there was anything after it. With a passphrase set there is: the
    progress sheet closed on that announcement and the phone then spent fifteen
    seconds encrypting, with nothing on screen, before the share sheet arrived.

    So the announcement is caught and held. Everything up to `sealing` passes
    through untouched; `done` is swallowed, `locking` is said instead, and
    `done` is said again for real once the file is sealed.
  */
  final passphrase = await backupPassphrase();

  if (passphrase == null) {
    // Nothing to add, so nothing to intercept.
    return exportBackup(db, onStep: onStep);
  }

  final plain = await exportBackup(
    db,
    onStep: onStep == null
        ? null
        : (step) {
            if (step.stage != BackupStage.done) onStep(step);
          },
  );

  onStep?.call(const BackupProgress(BackupStage.locking));
  final sealed = await lockBackup(plain);

  onStep?.call(const BackupProgress(BackupStage.done));
  return sealed;
}

/// A backup that has been opened, and whether it had to be.
class OpenedBackup {
  const OpenedBackup({required this.bytes, required this.wasLocked});

  final List<int> bytes;

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

/// The bytes of a backup, whatever kind it is, ready for `parseBackupBytes`.
///
/// [ask] is called only when the file is sealed AND the passphrase on this
/// phone does not open it — which is the case that matters: a backup restored
/// onto a NEW phone, where nothing is stored yet and the person has to have
/// written it down. Returning null from [ask] means they gave up, and that
/// comes back as a [VaultProblem] rather than as a half-restore.
///
/// Throws [VaultProblem] with a sentence for a person.
Future<OpenedBackup> openBackupBytes(
  List<int> bytes, {
  required Future<String?> Function() ask,
}) async {
  // Every backup this app made before today, and every one made with the lock
  // off. Untouched, straight through.
  if (!looksEncrypted(bytes)) {
    return OpenedBackup(bytes: bytes, wasLocked: false);
  }

  /*
    The passphrase on this phone, tried first and silently.

    Restoring onto the same phone is the common case — somebody undoing a bad
    import, or moving back after a mistake — and asking them to type a
    passphrase the app is already holding would be theatre.
  */
  final mine = await backupPassphrase();
  if (mine != null) {
    try {
      return OpenedBackup(
        bytes: await unlockBackup(bytes, mine),
        wasLocked: true,
      );
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

  return OpenedBackup(
    bytes: await unlockBackup(bytes, typed),
    wasLocked: true,
  );
}
