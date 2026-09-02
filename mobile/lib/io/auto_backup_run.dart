/// Writing the backup into the folder, when it falls due.
///
/// ── When this runs, and the honest limitation ──────────────────────────────
/// On launch and on resume, in the same breath as the widget mirror — see
/// `shell.dart`. Not at 3am on a timer.
///
/// That is a real limitation and worth stating plainly rather than hiding: a
/// phone whose owner does not open the app for a month gets no backups for a
/// month. The alternative is WorkManager, a background worker, a wakelock and a
/// scheduled job that Android is free to defer or drop on a doze-ing phone —
/// considerably more machinery for a guarantee it still would not give.
///
/// And the app already has the fallback: `backupWakes` sends a notification
/// when the interval passes without a backup. So somebody who never opens the
/// app is told to, which is the only thing that would have helped anyway.
///
/// ── Never throws, and never blocks anything ────────────────────────────────
/// A failed backup is a line in Settings, not an interruption. Every path here
/// records what happened and returns; nothing is shown, nothing is popped, and
/// the person finds out when they go looking — or when the overdue notification
/// arrives, because a failed automatic backup leaves `lastBackupAt` alone and
/// the nudge fires exactly as it would have.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/backup.dart';
import '../db/repository.dart';
import '../logic/auto_backup.dart';
import 'backup_folder.dart';
import 'sealed_backup.dart';

/// What happened, for the Settings line and for the developer probe.
class AutoBackupResult {
  const AutoBackupResult({required this.wrote, this.name, this.problem});

  /// True when a file landed in the folder.
  final bool wrote;

  /// The name it actually got, which is not always the name asked for — some
  /// providers add an extension of their own.
  final String? name;

  /// The sentence to show, or null when nothing went wrong. Set even when
  /// [wrote] is false for an ordinary reason, so "not due" and "could not
  /// write" are never confused.
  final String? problem;
}

/*
  ── Once per launch, whatever happens ───────────────────────────────────────

  This is called on launch and on every resume. Without a guard, an attempt
  that fails — or one killed halfway by the system — leaves the backup still
  due, so the next resume tries again, and the next, and the app spends its
  life doing the most expensive thing it knows how to do.

  That is not hypothetical. It is what a passphrase plus a slow seal produced:
  every return to the app started another one.

  A flag rather than a stored timestamp: "stop hammering this" is a fact about
  this run of the app, and writing it down would mean a phone that failed once
  waiting a fortnight to try again.
*/
bool _triedThisLaunch = false;

/// Runs one if the interval has passed. Cheap and silent when it has not.
Future<AutoBackupResult> autoBackupIfDue(Repository repo) async {
  if (_triedThisLaunch) return const AutoBackupResult(wrote: false);

  try {
    final settings = await repo.settings();
    final items = await repo.activeItems();

    if (!autoBackupDue(
      folder: settings.backupFolder,
      everyDays: settings.backupReminderDays,
      itemCount: items.length,
      lastAt: settings.lastAutoBackupAt,
    )) {
      return const AutoBackupResult(wrote: false);
    }

    // Set before the work, not after. The point is that a failure does not
    // come round again in thirty seconds.
    _triedThisLaunch = true;

    return backUpToFolder(repo);
  } catch (e) {
    // Reading the settings failed, which is not a backup problem and not worth
    // recording as one — the next launch tries again.
    return AutoBackupResult(wrote: false, problem: 'That did not work: $e');
  }
}

/// Runs one now, due or not.
///
/// The Settings card calls this for "Back up now", so that the manual button
/// and the automatic run are the same code down to the pruning. A button that
/// took a different path would be a button that proves nothing about whether
/// the automatic one works.
Future<AutoBackupResult> backUpToFolder(Repository repo) async {
  final settings = await repo.settings();
  final tree = settings.backupFolder;

  if (tree == null) {
    return const AutoBackupResult(
      wrote: false,
      problem: 'No folder chosen yet.',
    );
  }

  File? scratch;

  try {
    /*
      The grant, before the work.

      Building the bundle can take seconds and megabytes. Discovering
      afterwards that Android forgot the folder — which it does after a
      reinstall — would be that work thrown away, and the error is the same
      either way.
    */
    if (!await folderStillGranted(tree)) {
      return await _record(
        repo,
        const AutoBackupResult(
          wrote: false,
          problem: 'Android no longer has permission for that folder. '
              'Choose it again.',
        ),
      );
    }

    /*
      Straight to the scratch file, sealed on the way.

      `exportSealedBackupToFile` zips, encrypts and writes inside one isolate —
      nothing comes back here, which on a large backup is the difference
      between seconds and half a minute. See the note in that file.

      The scratch file is what the platform copies into the chosen folder, and
      it is deleted in the `finally` whatever happens.
    */
    final name = backupFileName();
    final dir = await getTemporaryDirectory();
    scratch = File(p.join(dir.path, name));

    await exportSealedBackupToFile(repo.db, path: scratch.path);

    final landed = await writeToBackupFolder(
      tree: tree,
      name: name,
      from: scratch.path,
    );

    if (landed == null) {
      return await _record(
        repo,
        const AutoBackupResult(
          wrote: false,
          problem: 'The folder would not take the file. If it is in the '
              'cloud, it may need a connection.',
        ),
      );
    }

    // Only after something actually landed. Pruning first would be an app that
    // deletes old backups on a phone that can no longer make new ones.
    await _prune(tree);

    /*
      `markBackedUp` as well as the automatic stamp.

      They mean different things — see the note on the columns — but a file
      that reached a folder outside this phone is a backup by any reading, and
      leaving the dashboard nudging somebody who is backed up automatically
      would teach them to ignore it.
    */
    await markBackedUp(repo.db);

    return await _record(repo, AutoBackupResult(wrote: true, name: landed));
  } catch (e) {
    return await _record(
      repo,
      AutoBackupResult(wrote: false, problem: 'That did not work: $e'),
    );
  } finally {
    if (scratch != null) {
      await scratch.delete().catchError((_) => scratch!);
    }
  }
}

/// Keeps the newest few and deletes the rest. Never touches a file this app
/// did not write — see `isOurBackup`.
Future<void> _prune(String tree) async {
  final there = await listBackupFolder(tree);

  for (final old in backupsToPrune(there, nameOf: (f) => f.name)) {
    await deleteInBackupFolder(old.uri);
  }
}

/// Writes the outcome where Settings can read it.
Future<AutoBackupResult> _record(Repository repo, AutoBackupResult r) async {
  final settings = await repo.settings();

  await repo.saveSettings(
    settings.copyWith(
      lastAutoBackupAt: r.wrote ? DateTime.now() : null,
      lastAutoBackupError: r.problem,
      clearAutoBackupError: r.problem == null,
    ),
  );

  return r;
}
