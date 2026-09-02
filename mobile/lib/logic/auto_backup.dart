/// When an automatic backup is due, and which old ones to throw away.
///
/// ── Pure, because the alternative is untestable ────────────────────────────
/// The rest of this feature is a folder grant, a document provider in another
/// process and a file of several megabytes. None of that can be exercised
/// without a phone. These two rules can, and they are the two that decide
/// whether somebody's data survives their phone — so they live here, with a
/// test, rather than inside the thing that does the writing.
library;

import 'dates.dart';

/// How many backups to keep in the folder.
///
/// ── Why more than one ──────────────────────────────────────────────────────
/// A backup that overwrites itself protects against a lost phone and nothing
/// else. It does not protect against the case that actually happens: somebody
/// deletes a room full of items, does not notice for a fortnight, and by then
/// the only backup is a faithful copy of the mistake.
///
/// Five, at the default fortnightly cadence, is about two months of history for
/// a few hundred kilobytes each. Enough to go back past a mistake nobody
/// noticed, few enough not to fill somebody's Drive.
const int backupsToKeep = 5;

/// Whether to write one now.
///
/// ── Every guard here is one that was wanted ────────────────────────────────
///
///   No folder is off. Choosing one is what turns this on, and there is no
///   second switch — a feature with a switch AND a destination has two states
///   that mean "not doing it" and a person who cannot tell which they are in.
///
///   Zero days is off, the same reading `backupWakes` gives it. Somebody who
///   set the interval to nothing meant nothing.
///
///   Nothing stashed is nothing to back up. The first thing a new install
///   would otherwise do is write an empty file to somebody's cloud.
///
///   And never having backed up counts as due, which is the case that matters:
///   the interval is measured from the last backup, so with no last backup
///   there is nothing to measure and the answer is now.
bool autoBackupDue({
  required String? folder,
  required int everyDays,
  required int itemCount,
  required DateTime? lastAt,
  DateTime? now,
}) {
  if (folder == null || folder.trim().isEmpty) return false;
  if (everyDays <= 0) return false;
  if (itemCount <= 0) return false;
  if (lastAt == null) return true;

  final today = startOfDay(now ?? DateTime.now());
  return !today.isBefore(startOfDay(addDays(lastAt, everyDays)));
}

/// Which files in the folder are backups this app wrote.
///
/// Matched on the name the app gives them, and nothing else. The folder belongs
/// to the person, not to this app: it may hold their tax returns, and a prune
/// that guessed would be the worst bug this app could possibly have.
bool isOurBackup(String name) =>
    name.startsWith('stash-it-backup-') && name.contains('.stashit');

/// The files to delete, oldest first, once [keep] have been spared.
///
/// ── Sorted by the name, not by the modified date ───────────────────────────
/// The name carries the date the backup describes; the modified date is
/// whenever the provider happened to write it. Those are usually the same and
/// come apart in exactly the case that matters — a folder synced from another
/// device, where every file arrived at once and their timestamps say so.
///
/// The names sort correctly as text because the date in them is ISO. That is
/// the whole reason `backupFileName` is written that way round.
List<T> backupsToPrune<T>(
  List<T> files, {
  required String Function(T) nameOf,
  int keep = backupsToKeep,
}) {
  final ours = [
    for (final file in files)
      if (isOurBackup(nameOf(file))) file,
  ]..sort((a, b) => nameOf(b).compareTo(nameOf(a)));

  if (ours.length <= keep) return const [];
  return ours.sublist(keep);
}
