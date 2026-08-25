/// One function, called from everywhere something changed.
///
/// ── Why rescheduling is not the form's job ────────────────────────────────
/// A reminder for a warranty depends on that item's purchase date, its cover,
/// and the ending-soon window in Settings. Editing any one of those three can
/// move a date that belongs to a different record entirely — change the window
/// from 30 days to 60 and every item in the app moves. So there is no useful
/// "update the reminder for this item"; there is only "work the whole thing out
/// again", which is cheap and cannot leave a stale entry behind.
///
/// Called on launch, and after every save, delete and restore.
library;

import '../db/repository.dart';
import '../logic/reminders.dart';
import 'notifications.dart';

/// The scheduler, shared. One object because the plugin underneath is one
/// object; making a second would not make a second notification tray.
final Notifications notifications = Notifications();

/// Rebuild the schedule from what is in the database and hand it to the OS.
///
/// Returns how many notifications are now pending, which is what the settings
/// screen shows — a number somebody can compare against what they expect is
/// worth more than a switch that claims to be on.
///
/// **Switched off means cancelled, not skipped.** Returning early would leave
/// whatever was scheduled before still pending, so the reminders would keep
/// arriving for up to sixty days after they were turned off. That is the bug
/// this early return is written to avoid.
Future<int> syncReminders(Repository repo) async {
  final settings = await repo.settings();

  if (settings.notifyEnabled != true) {
    await notifications.cancelAll();
    return 0;
  }

  // Asked-and-granted can still become revoked in system settings, months
  // later, with the app none the wiser. Checking here means the count on the
  // settings screen goes to zero rather than lying.
  if (!await notifications.permitted()) return 0;

  final schedule = reminderSchedule(
    await repo.activeItems(),
    await repo.activeSubscriptions(),
    await repo.activePapers(),
  );

  return notifications.reschedule(schedule);
}
