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

/// Why a save or a restore was refused.
///
/// "Unlock", not "subscribe". There is no subscription — it is one payment,
/// once — and a message offering the wrong shape of deal is a message that
/// gets the answer to a question nobody asked.
///
/// The second half is the part that matters. Somebody who has just been told
/// they are full needs to know the thing they were trying to restore is not
/// lost, and that sentence has to arrive in the same breath as the refusal.
String restoreBlockedReason(int activeCount) =>
    "You're at $activeCount of $freeItemLimit saved things. Remove something "
    'or unlock, and this comes straight back — it stays here either way.';

/// "3 things" / "1 thing", for the entry row and the heading.
///
/// **"Things", not "items".** The bin holds all three kinds now, and "items"
/// is the name of a tab — "3 items in the bin" would read as three of the
/// records on that one screen, which is exactly the sort of small wrongness
/// that makes somebody open the bin to check whether their passport is really
/// still there.
String binCount(int n) => '$n ${n == 1 ? 'thing' : 'things'}';

/* --------------------------------------------------------------- entries */

enum BinKind { item, paper, subscription }

/// One row in the bin, whatever it used to be.
///
/// ── Why the bin flattens the three kinds ──────────────────────────────────
/// Every other screen in the app is organised by what a record *is*, because
/// that is what you are looking for. The bin is organised by what is about to
/// go, because that is the only question it answers — and a passport with two
/// days left belongs above a kettle with twenty regardless of which tab either
/// came from. Three separate lists would bury the urgent one under a heading.
class BinEntry {
  const BinEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.deletedAt,
  });

  final String id;
  final BinKind kind;

  /// What to call it on the row. Already includes the holder for a document,
  /// because "Passport" alone is four identical rows in a household.
  final String name;

  final DateTime? deletedAt;
}

/// Everything in the bin, soonest to go first.
///
/// The sort is on the deletion date rather than the name: the only question
/// this screen answers is "what am I about to lose", and the answer belongs at
/// the top. A missing date sorts last — see the note in `binSummary` on why it
/// is treated as freshly deleted rather than as overdue.
List<BinEntry> sortBin(List<BinEntry> entries) {
  final out = [...entries];
  out.sort((a, b) {
    final x = a.deletedAt;
    final y = b.deletedAt;
    if (x == null && y == null) return a.name.compareTo(b.name);
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  });
  return out;
}

/// The bin's own summary line: how many, and how long the most urgent one has.
///
/// Stating the soonest rather than an average — the only deadline that matters
/// is the next one.
String binSummary(List<BinEntry> entries, [DateTime? now]) {
  if (entries.isEmpty) return 'Nothing here';

  final at = now ?? DateTime.now();
  var soonest = purgeAfterDays;
  for (final e in entries) {
    final gone = e.deletedAt;
    // A live record in the bin list is a caller's bug, not a countdown. It gets
    // the full window rather than being hurried towards deletion.
    final left = gone == null ? purgeAfterDays : daysLeft(gone, at);
    if (left < soonest) soonest = left;
  }

  return '${binCount(entries.length)} · ${daysLeftLabel(soonest).toLowerCase()}';
}
