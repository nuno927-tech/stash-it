/// The free tier, and how long the bin holds on.
///
/// Translated from the constants and guards in `src/db/repo.ts`. They are here
/// rather than in a repository because they are decisions, not queries — and
/// phase 1 has no database to hang them off.
library;

import '../models/settings.dart';

/// How many records the free tier holds, **when the cap is on**.
const int freeItemLimit = 25;

/// ── The cap is off ────────────────────────────────────────────────────────
///
/// Switched off deliberately, not deleted. The rule, the gate on the save
/// path, the exception and its wording all still exist and are still tested —
/// what changed is one boolean.
///
/// The reason to keep the machinery rather than rip it out: the hard part was
/// never the comparison, it was making sure **both** insert paths go through
/// it. Deleting that and rebuilding it later is how a cap comes back with a
/// hole in it — a restore from the bin that does not check, which is a gap you
/// could drive the whole tier through.
///
/// Turning it back on is this line. Tests that care flip it themselves.
bool capEnforced = false;

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

/// How long a deleted record waits in the bin before it is erased.
const int purgeAfterDays = 30;
