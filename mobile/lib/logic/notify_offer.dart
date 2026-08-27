/// Asking, once, whether reminders should arrive as notifications.
///
/// Translated from `src/lib/notifyOffer.ts`.
///
/// ── Why it is offered here and not on the settings screen ─────────────────
/// The switch has always existed in Settings, where nobody goes. The moment the
/// feature means anything is the moment someone saves the first thing with a
/// date on it: until then a reminder has nothing to remind them about, and the
/// offer is noise. One second later they have a warranty that runs out in
/// fourteen months and no plan for remembering it.
///
/// ── Why exactly once ──────────────────────────────────────────────────────
/// A prompt that returns is a prompt that gets dismissed reflexively, and after
/// the second time the dismissal is muscle memory rather than an answer. So the
/// date is written whether they say yes or no, and this never opens again. The
/// switch in Settings is the way back in, for anyone who changes their mind.
///
/// **This matters more on a phone than it did on the web.** iOS asks the
/// permission question once per install and remembers the answer forever; a
/// reflexive "no" there is not recoverable inside the app, only in system
/// settings. Getting the moment right is the whole feature.
///
/// ── Why "no" is not a failure state ───────────────────────────────────────
/// Everything still works. The dashboard carries the same information the
/// notification would have, and someone who opens the app has no need of a
/// reminder to open the app. Declining costs them nothing, and the copy should
/// not imply otherwise.
library;

/// Whether the device could actually deliver a reminder.
///
/// ── Three of the five web verdicts were web problems ──────────────────────
/// The TypeScript had five: `ready`, `unsupported`, `needs-install`, `no-key`
/// and `denied`.
///
///  - `unsupported` — a browser without a push API. Every phone that can run
///    this app can schedule a local notification.
///  - `no-key` — a build shipped without a VAPID public key. There are no keys
///    and no sender.
///  - `needs-install` — on iOS, web push only existed for a PWA added to the
///    Home Screen. It was the one failure deliberately allowed through to the
///    dialog, because "add it to your Home Screen" is a real instruction a
///    person can follow. A native app just asks.
///
/// What is left is the only question that was ever about the person rather
/// than the platform: have they said no already.
enum NotifyVerdict { ready, denied }

class OfferInput {
  const OfferInput({
    required this.asked,
    required this.enabled,
    required this.verdict,
    required this.dated,
  });

  /// Whether the question has already been put, either way.
  final bool asked;

  /// The switch, as the database has it.
  final bool enabled;

  /// Whether the OS would let us.
  final NotifyVerdict verdict;

  /// Whether the thing just saved has a date worth waking someone for.
  final bool dated;
}

/// Every reason not to ask, and there are still more of them than reasons to.
bool shouldOffer(OfferInput o) {
  if (o.asked || o.enabled || !o.dated) return false;
  return o.verdict == NotifyVerdict.ready;
}

/// Whether a saved thing is worth waking someone for.
///
/// A warranty with no purchase date, or a document with no expiry, generates no
/// reminder — so offering notifications on the strength of one would be
/// offering an empty schedule.
///
/// The check is deliberately the crude one: **does it have a date at all.**
/// Working out whether that date falls inside the horizon would mean an item
/// bought last week and covered for three years does not count, which is
/// exactly backwards — that is the one most worth a reminder, because it is the
/// one nobody will still be thinking about.
bool datedSave({String? expiresOn, String? purchaseDate, bool hasCover = false}) {
  if (expiresOn != null && expiresOn.trim().isNotEmpty) return true;
  return purchaseDate != null && purchaseDate.trim().isNotEmpty && hasCover;
}

/* --------------------------------------------------------------- the flag */

/// Armed by the form that just saved, read by the app shell.
///
/// Library state rather than the database, exactly as the nudge preview works.
/// The offer belongs to this run of the app: an intent that survived a restart
/// would surface days later, attached to nothing the person remembers doing.
bool _armed = false;

void armNotifyOffer() => _armed = true;
bool notifyOfferArmed() => _armed;
void clearNotifyOffer() => _armed = false;
