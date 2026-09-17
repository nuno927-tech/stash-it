/// The lines the dashboard says to you, and the honest shape of them.
///
/// Translated from `src/lib/nudges.ts`.
///
/// ── The premise this file opened with, and why it no longer holds ─────────
/// The web version began: *"There are no push notifications. This app has no
/// server, no account and no background process — nothing exists to wake the
/// phone up and say a warranty is ending. A reminder here is a line that
/// appears on the dashboard the next time you open the app, and calling it
/// anything else would be a promise the architecture can't keep."*
///
/// That was true, and then it stopped being true twice: once when the push
/// server was built, and again — properly — here, where the OS schedules
/// reminders and no server is involved at all. See `logic/reminders.dart`.
///
/// **So a nudge is no longer the only way anything reaches you, and that is a
/// design question rather than a win.** A warranty entering its window can now
/// produce a notification on the day *and* a card on the dashboard afterwards.
/// Two channels saying one thing is how people learn to ignore both. The
/// overlap is real and is left unresolved on purpose: it is a decision about
/// what a dashboard is for, and it wants the screens in front of it, which is
/// phase 3. Noted here so it is a decision and not an accident.
///
/// ── Why this file exists at all ───────────────────────────────────────────
/// Two settings were writing to the database and changing nothing anybody could
/// see. "Warn me before a warranty ends" set `reminderOffsetsDays`, which no
/// code read — the ending-soon threshold was a hard-coded constant. "Remind me"
/// set `backupReminderDays`, read in exactly one place: a hint inside a card
/// that later moved behind the developer tools. So a user could set both and
/// get nothing, forever.
///
/// A setting that writes to the database and changes nothing is worse than a
/// missing feature: it looks answered.
///
/// ── One function that did not survive the move ────────────────────────────
/// `nudgeClass` built the card's CSS class list. It existed because the card
/// was once written as `nudge ${kind}`, so the warranty reminder rendered as
/// `class="nudge warranty"` — and `.warranty` was the item page's ring block, a
/// flex row. That one card laid its text and buttons side by side and pushed
/// them off the edge; the other two were fine, because nothing was called
/// `.backup` or `.tip`.
///
/// **That bug cannot exist in Flutter.** There is no global namespace for a
/// kind name to collide in — a widget's styling is the widget. The function is
/// gone rather than ported, and the three tests that guarded it are gone with
/// it, which is the correct outcome for a guard whose hazard no longer exists.
library;

import '../models/settings.dart';
import 'format.dart';
import 'warranty.dart' show defaultEndingSoonDays;

enum NudgeKind { backup, warranty }

class Nudge {
  const Nudge({
    required this.kind,
    required this.title,
    required this.body,
    required this.action,
  });

  final NudgeKind kind;
  final String title;
  final String body;

  /// What the button says. Every nudge has exactly one thing to do about it.
  final String action;
}

/*
  The default lives in warranty.dart and is imported, not redeclared.

  There is one number, and the whole reason this file exists is that the
  setting and the threshold must agree — a second constant with the same name
  and the same value is exactly how they stop agreeing.
*/

/// How much notice the user asked for before a warranty ends.
///
/// Clamped rather than trusted: a restored backup written by a future version,
/// or a hand-edited record, must not be able to set the threshold to a million
/// days and paint the whole collection amber.
///
/// The TypeScript also had to defend against `NaN` and against a non-number
/// arriving in a `number[]`, because a parsed JSON backup can hold anything.
/// A Dart `List<int>` cannot, so that check is gone — but only from here. It
/// moves to the backup importer in phase 2, which is where the untrusted bytes
/// actually are.
int endingSoonDays(Settings? settings) {
  final asked = settings != null && settings.reminderOffsetsDays.isNotEmpty
      ? settings.reminderOffsetsDays.first
      : null;
  if (asked == null) return defaultEndingSoonDays;
  return asked.clamp(1, 365);
}

/// Whole days elapsed since a moment, or null if there is no moment.
///
/// ── The one place `.inDays` is the right answer ───────────────────────────
/// `dates.dart` says never to use `Duration.inDays` for calendar work, and that
/// still stands. **This is not calendar work.** "How long since the last
/// backup" is a question about elapsed time, not about how many midnights have
/// passed — a backup taken 23 hours ago is not "yesterday's backup" in any
/// sense worth acting on. Elapsed 24-hour periods, truncated, is exactly right,
/// and it is the same thing the TypeScript computed by dividing milliseconds.
int? _daysSince(DateTime? then, DateTime now) =>
    then == null ? null : now.difference(then).inDays;

/// Whether the stash holds anything the last backup does not.
///
/// ── The reminder used to be a calendar, and a calendar is not the question ─
/// "Thirty days since you exported" was the whole rule, so somebody whose
/// stash was finished — and most stashes finish, because you buy a washing
/// machine once — got a monthly instruction to write a file identical to the
/// one they already had. Every one of those is wrong, and a warning that is
/// wrong every time is a warning people learn to dismiss without reading.
/// Then it is wrong on the month it mattered.
///
/// So the interval says *when to look* and this says *whether there is
/// anything to look at*. Both have to agree before anybody is interrupted.
///
/// ── Two nulls, and they do not mean the same thing ────────────────────────
/// No backup is the loudest yes there is: nothing anywhere but this phone.
///
/// No change date is the app admitting it does not know — an install that
/// predates the column, or a stash that has not been touched since the upgrade
/// — and not knowing is a reason to go on asking. **Silence has to be earned
/// by a fact.** The alternative is an app that reasons its way into saying
/// nothing, which is the failure this whole file exists to avoid.
///
/// ── And a tie counts as new ───────────────────────────────────────────────
/// Both dates are stored to the second, so a change and a backup in the same
/// second are indistinguishable — and one of them really did happen after the
/// other. `!isBefore` rather than `isAfter` puts that one second on the side of
/// reminding, which is the same principle as the paragraph above: the app may
/// only be quiet about something it actually knows.
bool anythingNewToBackUp({DateTime? lastBackupAt, DateTime? changedAt}) {
  if (lastBackupAt == null) return true;
  if (changedAt == null) return true;
  return !changedAt.isBefore(lastBackupAt);
}

/// Time to export again.
///
/// Suppressed on an empty collection: nagging someone to back up nothing is how
/// a reminder teaches people to ignore reminders. `everyDays == 0` is the user
/// saying never, and must not be read as "every zero days".
Nudge? backupNudge({
  DateTime? lastBackupAt,
  DateTime? changedAt,
  required int everyDays,
  required int itemCount,
  DateTime? now,
}) {
  if (everyDays <= 0 || itemCount == 0) return null;

  // Nothing has changed, so the backup on file is still a complete copy —
  // however old it is. See `anythingNewToBackUp`.
  if (!anythingNewToBackUp(lastBackupAt: lastBackupAt, changedAt: changedAt)) {
    return null;
  }

  final since = _daysSince(lastBackupAt, now ?? DateTime.now());
  if (since != null && since < everyDays) return null;

  final plural = itemCount == 1 ? 'item lives' : 'items live';

  return Nudge(
    kind: NudgeKind.backup,
    title: since == null ? 'No backup yet' : 'Last backup was $since days ago',
    body: since == null
        ? 'Your $itemCount $plural on this phone and nowhere else. '
            'A backup is the only copy that survives losing it.'
        : 'Nothing syncs anywhere, so the file you export is the only copy '
            'that survives losing the phone.',
    action: 'Back up now',
  );
}

enum BackupTone { ok, due, never }

class BackupStatus {
  const BackupStatus(this.days, this.tone, this.label);

  /// Days since the last one, or null if there has never been one.
  final int? days;
  final BackupTone tone;
  final String label;
}

/// The backup, said on the dashboard whether or not it is overdue.
///
/// ── Why this is separate from the nudge above ─────────────────────────────
/// `backupNudge` is a warning: it appears when the interval has lapsed and is
/// dismissible, which is correct for a warning and wrong for a fact. Between
/// nudges the dashboard said nothing at all about backups, so the honest
/// reading of a quiet screen was "fine" — and the state it was quietest about
/// was a phone whose only copy of everything was itself.
///
/// So this never goes away and cannot be dismissed. It is one line, and most of
/// the time it is a reassuring one; the point is that the day it stops being
/// reassuring, nothing has to appear for you to notice.
///
/// Returns null only when there is nothing to protect — the same rule the
/// nudge follows.
BackupStatus? backupStatus({
  DateTime? lastBackupAt,
  DateTime? changedAt,
  required int everyDays,
  required int itemCount,
  DateTime? now,
}) {
  if (itemCount == 0) return null;

  final days = _daysSince(lastBackupAt, now ?? DateTime.now());
  if (days == null) {
    return const BackupStatus(null, BackupTone.never, 'Never backed up');
  }

  final when = days == 0
      ? 'today'
      : days == 1
          ? 'yesterday'
          : '${grouped(days)} days ago';

  /*
    ── An old backup and a stale backup are different things ────────────────

    This line used to go amber on age alone, which quietly equated "written a
    while ago" with "missing something". For a stash that has not changed
    since, those are opposites: the file on disk is a complete copy, and the
    number beside it is just how long ago the person finished.

    So a stash with nothing new says so and stays green, and the age is still
    printed — the point is not to hide it, it is to stop it being read as a
    problem when it is not one.
  */
  if (!anythingNewToBackUp(lastBackupAt: lastBackupAt, changedAt: changedAt)) {
    return BackupStatus(days, BackupTone.ok, 'Backed up $when · up to date');
  }

  /*
    "Due" follows the interval the user chose, and falls back to a month when
    they chose never. Turning the reminder off is a decision about being
    interrupted, not a claim that a six-month-old backup is current — so the
    line still goes amber, it just never grows into a nudge.
  */
  final every = everyDays > 0 ? everyDays : 30;
  final tone = days >= every ? BackupTone.due : BackupTone.ok;

  return BackupStatus(days, tone, 'Backed up $when');
}

/// Warranties inside the window the user asked to be warned about.
Nudge? warrantyNudge({required int endingSoon, required int days}) {
  if (endingSoon == 0) return null;

  return Nudge(
    kind: NudgeKind.warranty,
    title: endingSoon == 1
        ? '1 warranty ends within $days days'
        : '$endingSoon warranties end within $days days',
    body: 'While cover is still running you can claim, extend, or decide not '
        'to bother. After it ends, none of those are on the table.',
    action: endingSoon == 1 ? 'See it' : 'See them',
  );
}

/*
  ── The tip jar is not here, and that is a product decision ────────────────

  The web app had a third nudge: a monthly reminder to drop something in a
  Venmo link, because Venmo cannot schedule a payment and "monthly" was only
  ever a reminder the app gave itself.

  It is dropped from the port, on request. It was also the odd one out on its
  own terms — the two above offer you something, and this one asked. With a
  paid tier in the plan, an app that charges and also passes a hat is asking
  the same person twice for the same thing.
*/

/// Everything worth saying today, in the order it matters.
///
/// Backup first: it is the only one where waiting can cost you data.
List<Nudge> dueNudges({
  Settings? settings,
  required int itemCount,
  required int endingSoon,
  DateTime? changedAt,
  DateTime? now,
}) {
  final s = settings;
  if (s == null) return [];

  return [
    backupNudge(
      lastBackupAt: s.lastBackupAt,
      changedAt: changedAt,
      everyDays: s.backupReminderDays,
      itemCount: itemCount,
      now: now ?? DateTime.now(),
    ),
    warrantyNudge(endingSoon: endingSoon, days: endingSoonDays(s)),
  ].whereType<Nudge>().toList();
}

/* ------------------------------------------------------------ the preview */

/// Whether the dashboard should draw the samples instead of the real thing.
///
/// A library-level flag, not a setting and not a database field, because it
/// must not survive anything: not a reload, not a restore, and not walking away
/// from the screen. Armed from the developer card, read once when the dashboard
/// is built, and cleared when the dashboard is left.
///
/// The preview belongs on the dashboard rather than under the button that
/// triggers it. A reminder is a card in a particular place, competing with the
/// greeting and the ring for the same attention; rendered inside a settings
/// card it looks fine and tells you nothing about whether it works there.
bool _previewArmed = false;

void armNudgePreview() => _previewArmed = true;
bool nudgePreviewArmed() => _previewArmed;
void clearNudgePreview() => _previewArmed = false;

/// One of each, forced, for the developer card. Real copy from the real
/// functions — a preview that renders its own sample text is a preview of
/// nothing.
List<Nudge> sampleNudges([DateTime? now]) {
  final at = now ?? DateTime.now();
  final longAgo = at.subtract(const Duration(days: 120));

  return [
    backupNudge(lastBackupAt: longAgo, everyDays: 30, itemCount: 12, now: at)!,
    warrantyNudge(endingSoon: 3, days: 30)!,
  ];
}
