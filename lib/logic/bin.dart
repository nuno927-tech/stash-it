/// The bin: how long a deleted item has left, and whether it can come back.
///
/// Translated from `src/lib/bin.ts`.
///
/// This exists because the delete dialog made a promise — "it goes to the bin
/// for 30 days, so you can change your mind" — that nothing in the app kept.
/// `restoreItem` had been sitting in the repository since the beginning, called
/// from nowhere. Items were being soft-deleted, counted down, and purged, and
/// the only observable part of that was that they vanished. **A recovery window
/// nobody can reach is a thirty-day delay, not a safety net.**
///
/// The arithmetic is here rather than in the screen because both halves of it
/// are easy to get wrong by one: whether the day you delete something counts,
/// and whether "0 days left" means today or means gone.
library;

import '../models/settings.dart';
import '../models/types.dart';
import 'limits.dart';

/// Whole days until this item is erased.
///
/// ── Elapsed time, not calendar days, and that is on purpose ───────────────
/// Counted from the moment of deletion rather than from midnight, because the
/// purge itself runs on elapsed time — anything else would print a number the
/// sweep disagrees with. This is the second of the two places in the port where
/// `Duration` is the right tool and the calendar is not; see `_daysSince` in
/// nudges.dart for the first, and the header of dates.dart for the rule they
/// are both exceptions to.
///
/// Never negative: an item past its date goes on the next launch, and "-2 days
/// left" is not a thing to tell somebody.
int daysLeft(DateTime deletedAt, [DateTime? now, int retain = purgeAfterDays]) {
  final at = now ?? DateTime.now();
  final gone = deletedAt.add(Duration(days: retain));
  final left = gone.difference(at);
  if (left.isNegative) return 0;

  // Rounded up: any part of a day remaining is still a day you have.
  final whole = left.inMilliseconds / Duration.millisecondsPerDay;
  return whole.ceil();
}

/// The countdown as it is written on the row.
String daysLeftLabel(int days) {
  if (days <= 0) return 'Goes today';
  if (days == 1) return 'Last day';
  return '$days days left';
}

/// Whether a deleted item can come back.
///
/// ── Restoring is subject to the cap, and it has to be ─────────────────────
/// Deleting frees a slot immediately — that is deliberate, so someone at the
/// limit can make room — but it means an unchecked restore would be a hole you
/// could drive the whole tier through: fill up, delete the lot, fill up again,
/// restore the lot. Fifty items on a twenty-five item tier, by pressing undo.
///
/// Nothing is lost either way. The item stays in the bin, and its own countdown
/// is the only thing that can remove it.
bool canRestore(int activeCount, Entitlements e) => canAddItem(activeCount, e);

String restoreBlockedReason(int activeCount) =>
    "You're at $activeCount of $freeItemLimit saved things. Remove something, "
    'or subscribe, and this comes straight back — it stays here either way.';

/// "3 items" / "1 item", for the entry row and the heading.
String binCount(int n) => '$n ${n == 1 ? 'item' : 'items'}';

/// The bin's own summary line: how many, and how long the most urgent one has.
///
/// Stating the soonest rather than an average — the only deadline that matters
/// is the next one.
String binSummary(List<Item> items, [DateTime? now]) {
  if (items.isEmpty) return 'Nothing here';

  final at = now ?? DateTime.now();
  var soonest = purgeAfterDays;
  for (final i in items) {
    final gone = i.deletedAt;
    // A live item in the bin list is a caller's bug, not a countdown. It gets
    // the full window rather than being hurried towards deletion.
    final left = gone == null ? purgeAfterDays : daysLeft(gone, at);
    if (left < soonest) soonest = left;
  }

  return '${binCount(items.length)} · ${daysLeftLabel(soonest).toLowerCase()}';
}
