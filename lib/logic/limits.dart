/// The free tier, and how long the bin holds on.
///
/// Translated from the constants and guards in `src/db/repo.ts`. They are here
/// rather than in a repository because they are decisions, not queries — and
/// phase 1 has no database to hang them off.
library;

import '../models/settings.dart';

/// How many records the free tier holds, **when the cap is on**.
///
/// ── Twenty, not twenty-five ───────────────────────────────────────────────
/// Twenty is enough to hold a household's real paperwork — passports, the car,
/// the boiler, four appliances, the streaming services — and not enough to
/// hold a whole house. That is the line the tier is meant to sit on: somebody
/// who has entered twenty things has stopped evaluating the app and started
/// depending on it.
///
/// A round number also matters more than it should. "20 of 20" is a sentence
/// somebody can hold in their head; "23 of 25" is arithmetic.
const int freeItemLimit = 20;

/// ── The cap is on ─────────────────────────────────────────────────────────
///
/// It was off for most of the port — deliberately, and switched rather than
/// deleted. The rule, the gate on the save path, the exception and its wording
/// all stayed and stayed tested; what changed was this one boolean.
///
/// The reason to keep the machinery rather than rip it out: the hard part was
/// never the comparison, it was making sure **both** insert paths go through
/// it. Deleting that and rebuilding it later is how a cap comes back with a
/// hole in it — a restore from the bin that does not check, which is a gap you
/// could drive the whole tier through. That decision is what made turning it
/// on a one-line change today.
///
/// Tests that care flip it themselves.
bool capEnforced = true;

/// Whether another one can be saved.
///
/// ── What the cap counts, and why it counts all of it ──────────────────────
/// Items, subscriptions and documents together. That reverses two earlier
/// exemptions, whose reasoning was that the cap prices storage and neither a
/// subscription nor a document holds an attachment. True — and it left the
/// limit meaning "how many kettles" rather than "how much of this app you are
/// using". A free tier that allows forty subscriptions and thirty documents
/// but not a sixteenth kettle is a rule nobody can predict.
bool canAddItem(int count, Entitlements e) =>
    !capEnforced || e.proUnlock || count < freeItemLimit;

/// How many are left, or null when there is no limit to be near.
///
/// Null rather than a large number for the unlocked case, so a caller cannot
/// accidentally draw "999 left" — the answer for somebody who has paid is that
/// the question no longer applies.
int? remainingFree(int count, Entitlements e) {
  if (!capEnforced || e.proUnlock) return null;
  final left = freeItemLimit - count;
  return left < 0 ? 0 : left;
}

/*
  ── When to mention it ──────────────────────────────────────────────────────

  Not at one of twenty, and not only at twenty. A counter that appears on the
  first save is a shop, and one that appears only at the wall is an ambush —
  somebody who has just typed a passport into a form and pressed Save has
  earned better than being told the app is full.

  Five left is the point where the number becomes information rather than
  either noise or a surprise: enough room to finish what you are doing, and
  enough warning to decide before it matters.
*/
const int warnWhenLeft = 5;

bool shouldMentionCap(int count, Entitlements e) {
  final left = remainingFree(count, e);
  return left != null && left <= warnWhenLeft;
}

/// How long a deleted record waits in the bin before it is erased.
const int purgeAfterDays = 30;
