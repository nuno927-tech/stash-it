/// The tour: what it says, and when it is due.
///
/// Translated from `src/lib/tour.ts`.
///
/// A handful of screens, each answering a question someone would otherwise
/// have to discover by poking. The content lives here rather than in the
/// widget so it can be read as a script — a tour is writing, and writing that
/// is scattered through a widget tree stops being editable as prose.
///
/// ── One sentence each, and it took a rewrite to get there ─────────────────
/// These were three-clause paragraphs, and every clause was load-bearing to
/// whoever wrote it. Nobody reads them: a tour is swiped, not studied, and a
/// screen that needs eight seconds of reading gets one.
///
/// So the title carries the claim and the line under it carries at most one
/// qualification. Anything that survived being cut was either a promise — the
/// documents step's "never a document number" — or the one fact that makes the
/// screen worth stopping on.
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
  lounge,
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
/// ── Nine, and it was nearly fourteen ──────────────────────────────────────
/// Documents, subscriptions and reminders all arrived after this was written,
/// then automatic backups, reading a receipt and the claim pack after that.
/// The obvious move — a screen each, appended — would have made a fourteen-tap
/// introduction to an app whose whole pitch is that it is quick.
///
/// **A tour is a budget. Every screen added has to displace one, or it is not
/// worth the tap it costs.**
///
/// So none of the three newest got a screen. Reading a receipt replaced the
/// sentence in the adding step that described a thing this app never did; the
/// claim pack went into the step that asks somebody to keep the paperwork,
/// because that is the step that should say what keeping it buys; and
/// automatic backups rewrote the step that used to end by shrugging.
///
/// ── Two of these ask rather than tell ─────────────────────────────────────
/// The backup folder and the name. Both are skippable, both are offered again
/// in Settings, and neither blocks the Next button — a tour that will not let
/// you past a permission dialog is a tour people uninstall rather than
/// finish.
const List<TourStep> tourSteps = [
  TourStep(
    'what',
    ScoutPose.waving,
    'Everything you own, with its paperwork',
    'Warranties, documents and subscriptions, in one place.',
  ),
  /*
    ── This step used to promise something the app cannot do ─────────────────

    It said a receipt shared from your mail app arrives with the shop, date and
    price already filled in. That came over from the web version's script and
    was never true here: the only thing this app accepts by sharing is a
    `.stashcard` — see the manifest.

    A sentence like that is worse than a missing feature. It is on the second
    screen anybody sees, it describes the exact thing they are about to try,
    and the first thing they learn about the app is that it says things that
    are not so.

    What replaces it is the same promise made honestly. Scan a receipt reads
    the date, the total and the shop off the photograph, on this phone, and
    shows what it read before it fills anything in.
  */
  TourStep(
    'add',
    ScoutPose.receipt,
    'Point the camera at the receipt',
    'It reads the date, the price and the shop. You check them first.',
  ),
  /*
    The claim pack is the payoff, and it belongs here rather than on a screen
    of its own — this is the step that asks somebody to do the boring thing,
    so it is the step that should say what the boring thing buys.
  */
  TourStep(
    'paper',
    ScoutPose.folder,
    'Then stash the paper too',
    'When something breaks, Make a claim writes the letter — receipt '
        'attached.',
  ),

  /*
    The privacy sentence is not a footnote here. Anyone being asked to put a
    passport into an app is entitled to know what it will actually hold before
    they start. The honest answer is dates, a scan if they choose to take one,
    and never a document number — and the scan is the part that made the app
    insist on a backup passphrase.
  */
  TourStep(
    'papers',
    ScoutPose.clipboard,
    'Passports, licenses, insurance',
    // The privacy line stays whatever else goes. Anybody being asked to put a
    // passport into an app is entitled to know what it holds before they
    // start, and it is the shortest true sentence about it.
    "Dates, and a scan if you want one. I'll say when to start renewing.",
  ),
  TourStep(
    'subs',
    ScoutPose.calendar,
    'And what leaves your account each month',
    'What a month really costs, and what renews next.',
  ),
  TourStep(
    'watch',
    ScoutPose.report,
    'The dashboard is the short version',
    'The ring is how much is still in date. Under it, what needs you next.',
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
    'Your phone keeps the schedule itself. Nothing is sent anywhere.',
  ),
  /*
    ── The step that changed most, and the only one that protects anything ───

    It used to end at "the backup is on you", which was true and was also the
    app shrugging: a reminder to do something manually only works on people
    who act on reminders, and the ones who do not are exactly the ones who
    lose a phone with everything on it.

    Automatic backups are the answer and they need one thing the app cannot
    decide — a folder. So this step ASKS, the way the name step asks.

    Before the name step, deliberately: a folder is worth more than a
    greeting. Skippable like everything else here, and skipping costs nothing
    somebody cannot get back — Settings has the same card, and the overdue
    nudge still fires for anybody who never sets one.
  */
  TourStep(
    folderStepKey,
    ScoutPose.acorn,
    'Keep a copy somewhere else',
    'A lost phone is a lost stash. Pick a folder your cloud syncs and '
        'backups go there on their own.',
  ),

  /*
    ── The ninth step, and the only one that asks rather than tells ──────────

    A tour is a budget and every screen has to displace one. This one earns
    its place by not being a tour screen at all: the other eight explain the
    app, and this collects the single thing the app needs from you.

    Last, deliberately. Asking a stranger's name before showing them anything
    is a form the app has not earned yet; asking after eight screens of what
    it does is the end of an introduction. It also makes the final tap a
    completion rather than a dismissal.

    Skippable like every other step, and skipping costs nothing — the greeting
    falls back to the time of day on its own. See `greeting`.
  */
  TourStep(
    nameStepKey,
    ScoutPose.lounge,
    'What should I call you?',
    'Only to say hello. Change it in Settings whenever you like.',
  ),
];

/// The step that offers to set up automatic backups.
///
/// Named rather than positional, for the same reason as [nameStepKey]: the
/// script has to be reorderable without a button turning up on the wrong
/// screen.
const String folderStepKey = 'safe';

/// The step that carries a text field rather than only words.
///
/// Named here rather than matched on its position so the script can be
/// reordered without the widget quietly rendering a field on the wrong screen.
const String nameStepKey = 'name';

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

/*
  ── Whether to show it at all, on this launch ───────────────────────────────

  This is the question that had no answer for sixty versions.

  `tourDue` was written, tested, and never called; so were `remindLater` and
  `TourState`. The whole scheduling half existed as logic with no trigger, and
  `showTour` was reachable from exactly one place — the "Take the tour" row in
  Settings, which is the one route that only somebody who already knows about
  the tour would ever take.

  Two ways in, and they are different questions:

    Never onboarded and never skipped — a fresh install. Show it. This is the
    case that was broken: the app opened straight onto an empty dashboard and
    explained nothing.

    Skipped, and the three days are up. Show it again, once.

  Anybody who finished it, and anybody who skipped it less than three days
  ago, is left alone.
*/
bool tourOnLaunch(TourState state, [DateTime? now]) {
  if (state.doneAt != null) return false;
  if (state.remindAt == null) return true;
  return tourDue(state, now);
}

DateTime remindLater([DateTime? now, int days = remindDays]) =>
    (now ?? DateTime.now()).add(Duration(days: days));

/// Where a step sits in the sequence, for the dots and the button label.
bool isLastStep(int index) => index >= tourSteps.length - 1;

TourStep stepAt(int index) => tourSteps[index.clamp(0, tourSteps.length - 1)];
