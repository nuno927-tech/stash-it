/// The tour: what it says, and when it is due.
///
/// Translated from `src/lib/tour.ts`.
///
/// A handful of screens, each answering a question someone would otherwise
/// have to discover by poking. The content lives here rather than in the
/// widget so it can be read as a script — a tour is writing, and writing that
/// is scattered through a widget tree stops being editable as prose.
///
/// The scheduling is the part with a rule in it. "Remind me later" has to mean
/// something specific or it means "never", and "never" is what most apps
/// quietly implement.
library;

/// Which drawing of Scout accompanies a step.
enum ScoutPose {
  waving,
  receipt,
  folder,
  clipboard,
  calendar,
  report,
  alert,
  acorn,
}

class TourStep {
  const TourStep(this.key, this.pose, this.title, this.body);
  final String key;
  final ScoutPose pose;
  final String title;
  final String body;
}

/// Ordered as a first week with the app, not as a feature list: what it is,
/// how to put something in, what to do with the paper it came with, the two
/// other things it tracks, what it tells you back, how it can reach you, and —
/// last, because it is the one that matters when things go wrong — how to make
/// sure you do not lose any of it.
///
/// The paper step sits third, immediately after adding, because that is the
/// minute the receipt is still in your hand. Told at the end it is advice; told
/// there it is an instruction you can act on.
///
/// ── Eight, and it was nearly eleven ───────────────────────────────────────
/// Documents, subscriptions and reminders all arrived after this was written,
/// and the obvious move — a screen each, appended — would have made a
/// fourteen-tap introduction to an app whose whole pitch is that it is quick.
/// So two of the originals were folded into their neighbours rather than kept.
///
/// **A tour is a budget. Every screen added has to displace one, or it is not
/// worth the tap it costs.**
const List<TourStep> tourSteps = [
  TourStep(
    'what',
    ScoutPose.waving,
    'Everything you own, with its paperwork',
    'Warranties, documents and subscriptions in one place — so the receipt is '
        'somewhere better than a drawer when a claim needs it, and nothing '
        'lapses because you forgot it existed.',
  ),
  TourStep(
    'add',
    ScoutPose.receipt,
    'Adding something takes a photo and a date',
    'Name it, photograph it, say when you bought it and how long the warranty '
        'runs. Or share a receipt straight from your mail app and the shop, '
        'date and price arrive already filled in.',
  ),
  TourStep(
    'paper',
    ScoutPose.folder,
    'Then stash the paper too',
    'A photo settles most claims. Some still want the original, so keep it in '
        "a folder somewhere dry — the app holds the copy, you hold the proof. "
        "Paper doesn't need charging.",
  ),

  /*
    The privacy sentence is not a footnote here. Anyone being asked to put a
    passport into an app is entitled to know what it will actually hold before
    they start, and the honest answer — dates, no scans, no numbers — is also
    the reason to trust the rest of it.
  */
  TourStep(
    'papers',
    ScoutPose.clipboard,
    'Passports, licenses, insurance',
    'The Documents tab watches the things that expire on you. Dates and '
        "general details only — no scans, no document numbers — and I'll tell "
        "you when to start renewing, not when it's too late.",
  ),
  TourStep(
    'subs',
    ScoutPose.calendar,
    'And what leaves your account each month',
    'Add the subscriptions you pay for and the Subscriptions tab shows what a '
        'month really costs, which months are the heavy ones, and what renews '
        'next.',
  ),
  TourStep(
    'watch',
    ScoutPose.report,
    'The dashboard is the short version',
    'The ring is how much is still in date, green to red. Under it, one list '
        "of everything coming up — ordered by what it costs to ignore, not by "
        "date — and a note of anything I'm missing.",
  ),

  /*
    ── This step's copy was rewritten, and it had to be ──────────────────────

    The web version said: "When you do, the only thing that leaves this phone
    is a delivery address and the days something is due — never what it's
    about." Every word of that was true and carefully argued, because web push
    needs a server that knows when to wake you.

    **Here it would be a lie in the app's own onboarding.** There is no server,
    no delivery address and no upload — the phone schedules its own reminders.
    Leaving the old sentence in would have been the port's most visible
    untruth, on the one screen written specifically to earn trust.
  */
  TourStep(
    'notify',
    ScoutPose.alert,
    'I can nudge you with the app closed',
    'Reminders are off until you turn them on. When you do, your phone keeps '
        'the schedule itself — nothing is sent anywhere, and no server is '
        'told what any of it is about.',
  ),
  TourStep(
    'safe',
    ScoutPose.acorn,
    'It all lives on this phone',
    'Nothing is uploaded and there is no account. That keeps it private and '
        'puts the backup on you: Back up now in Settings makes one file you '
        'can send to Drive, Files, or yourself.',
  ),
];

/* ---------------------------------------------------------------- when */

const int remindDays = 3;

class TourState {
  const TourState({this.doneAt, this.remindAt});

  /// Set when the tour was finished, or explicitly declined for good.
  final DateTime? doneAt;

  /// Set by "remind me later".
  final DateTime? remindAt;
}

/// Whether to offer the tour again.
///
/// Only ever offered when a reminder was actually asked for and has come due.
/// Someone who took the tour, or who has no reminder pending, is never
/// interrupted — the alternative is an app that periodically decides you would
/// like to be taught how to use it.
bool tourDue(TourState state, [DateTime? now]) {
  if (state.doneAt != null) return false;

  final at = state.remindAt;
  if (at == null) return false;

  return !(now ?? DateTime.now()).isBefore(at);
}

DateTime remindLater([DateTime? now, int days = remindDays]) =>
    (now ?? DateTime.now()).add(Duration(days: days));

/// Where a step sits in the sequence, for the dots and the button label.
bool isLastStep(int index) => index >= tourSteps.length - 1;

TourStep stepAt(int index) =>
    tourSteps[index.clamp(0, tourSteps.length - 1)];
