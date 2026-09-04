/// When, if ever, to ask somebody to rate the app.
///
/// ── The whole feature is the refusal ──────────────────────────────────────
/// Every rule in this file exists to say no. An app that asks for five stars
/// on the second launch is asking somebody to vouch for something they have
/// not used, and the honest answer to that is one star. So the question is
/// only put once the app has demonstrably done its job, and it is put twice in
/// a lifetime at most.
///
/// ── Play's own sheet, and Play's own quota ────────────────────────────────
/// The prompt is Google's in-app review flow. It never leaves the app, and
/// Play throttles it on top of everything here — which means it sometimes
/// shows nothing at all. Nothing in the app may claim it appeared, thank
/// anybody for rating, or treat "we asked" as "they rated". We cannot know.
///
/// Google's policy also rules out the pattern this file might otherwise have
/// grown: no "Do you like Stash it?" first, no sentiment gate, no diverting
/// unhappy people somewhere else. The sheet goes to everybody who reaches it
/// or to nobody.
///
/// ── Pure, so the cadence can be argued about in a test ────────────────────
/// Every threshold below is a judgement, and judgements that live inside a
/// widget get changed by accident. `timeToAsk` takes facts and returns a bool.
library;

/// How long somebody has to have had the app.
///
/// Two weeks. Long enough that a warranty reminder has plausibly fired and a
/// backup has run; short enough that the app is still something they chose
/// recently rather than something they have forgotten they installed.
const int reviewMinDaysInstalled = 14;

/// Distinct DAYS the app has been opened, not launches.
///
/// A launch count rewards an app that is hard to use — five trips back in
/// because something did not save is five launches and no evidence of
/// anything. Five separate days is a habit.
const int reviewMinDaysUsed = 5;

/// Records saved. A stash with three things in it has not been adopted yet,
/// and the person filling it has nothing to rate.
const int reviewMinRecords = 10;

/// Nothing may be asked within a week of the app falling over on them.
///
/// The prompt lands on whatever the app last made somebody feel. A crash a
/// fortnight ago is history; a crash on Tuesday is the reason they would leave
/// two stars and mean it.
const Duration reviewQuietAfterCrash = Duration(days: 7);

/// The gap before a second and final ask.
///
/// Four months, which is long enough that the app has changed and that
/// somebody who ignored the first one is not being pestered by the second.
const Duration reviewGap = Duration(days: 120);

/// Twice, ever.
///
/// Not "twice per version" and not "once a year, forever". Somebody who has
/// declined twice has answered the question, and an app that keeps asking is
/// telling them their answer did not count.
const int reviewMaxAsks = 2;

/// What the decision is made of.
///
/// All of it is already recorded for other reasons — the install date, the day
/// count, what is in the stash, whether backups work, what crashed. Nothing
/// here is collected FOR this, which is the standard the rest of the app is
/// held to and this is not exempt from.
class ReviewFacts {
  const ReviewFacts({
    required this.installedAt,
    required this.daysUsed,
    required this.records,
    required this.backedUpAt,
    this.lastCrashAt,
    this.askedAt,
    this.asks = 0,
  });

  /// Null on an install old enough to predate the column, which reads as "not
  /// yet known" and therefore as "do not ask".
  final DateTime? installedAt;

  final int daysUsed;
  final int records;

  /// When a backup last succeeded. Null means never, and never means the app
  /// has not yet done the one thing it promises hardest.
  final DateTime? backedUpAt;

  final DateTime? lastCrashAt;

  /// When the sheet was last requested, and how many times ever.
  final DateTime? askedAt;
  final int asks;
}

/// Whether to put the question now.
///
/// Every clause is a veto. There is no scoring and no "two out of three",
/// because a prompt that arrives on a technicality is exactly the prompt this
/// file exists to prevent.
bool timeToAsk(ReviewFacts f, {DateTime? now}) {
  final at = now ?? DateTime.now();

  // Asked and answered, twice.
  if (f.asks >= reviewMaxAsks) return false;

  // Not yet, if the last time was recent.
  final asked = f.askedAt;
  if (asked != null && at.difference(asked) < reviewGap) return false;

  // Old enough to have an opinion.
  final installed = f.installedAt;
  if (installed == null) return false;
  if (at.difference(installed).inDays < reviewMinDaysInstalled) return false;

  // Used enough to have formed one.
  if (f.daysUsed < reviewMinDaysUsed) return false;
  if (f.records < reviewMinRecords) return false;

  // And the app has actually delivered: a backup exists, so their records are
  // somewhere other than this phone.
  if (f.backedUpAt == null) return false;

  // Nothing on the back of a bad week.
  final crashed = f.lastCrashAt;
  if (crashed != null && at.difference(crashed) < reviewQuietAfterCrash) {
    return false;
  }

  return true;
}
