/// The free tier, and how long the bin holds on.
///
/// Translated from the constants and guards in `src/db/repo.ts`. They are here
/// rather than in a repository because they are decisions, not queries — and
/// phase 1 has no database to hang them off.
library;

import '../models/settings.dart';

/// How many records the free tier holds.
const int freeItemLimit = 25;

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
    e.proUnlock || count < freeItemLimit;

/// How long a deleted record waits in the bin before it is erased.
const int purgeAfterDays = 30;
