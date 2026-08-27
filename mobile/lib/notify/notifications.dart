/// Handing the reminder schedule to the operating system.
///
/// ── Where this sits ───────────────────────────────────────────────────────
/// `logic/reminders.dart` decides **which days earn a wake and what is said on
/// them**, and it does that with no plugin, no platform and no clock it did not
/// receive as an argument — which is why it has a test suite. This file is the
/// part that cannot be tested on a laptop: the plugin call, the permission
/// prompt, the time zone.
///
/// Keeping the seam here is the whole point. Everything above it is decidable;
/// everything below it is the OS's business.
///
/// ── The web version's entire push stack has no counterpart ────────────────
/// No VAPID keys, no Firebase function, no Firestore row, no service worker, no
/// weekly sync. A native app hands a list of local instants to the scheduler on
/// the same device that computed them, so the property the web design worked
/// hardest for — that nothing about your possessions crosses a network — is
/// true here by construction rather than by effort.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'pending_link.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/reminders.dart';

/// One channel, because there is one kind of notification.
///
/// Android shows channels in system settings as separate switches. Splitting
/// warranties, documents and subscriptions into three would let somebody mute
/// one — which sounds like a feature until you notice the app already has that
/// control, per record, in a place where they can see what they are muting.
const String _channelId = 'stash-it-reminders';
const String _channelName = 'Reminders';
const String _channelDescription =
    'Warranties ending, documents to renew, and subscriptions you asked to be '
    'told about.';

class Notifications {
  Notifications({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  /// Safe to call more than once; the second call does nothing.
  ///
  /// Never throws. A phone that will not give us its time zone, or a plugin
  /// that fails to initialise, must not stop the app opening — the dashboard
  /// carries the same information the notification would have, and an app that
  /// refuses to start because it could not set a reminder has its priorities
  /// backwards.
  Future<void> init() async {
    if (_ready) return;

    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Falls back to UTC, which is wrong by up to half a day. The reschedule
      // below still runs; a reminder at the wrong hour beats no reminder, and
      // the next launch in a working state fixes it.
    }

    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        // A tap while the app is running or merely backgrounded. The cold
        // case is handled below, and needs a different question entirely.
        onDidReceiveNotificationResponse: (response) =>
            rememberLink(response.payload),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }

    /*
      ── The tap that WAS the launch ─────────────────────────────────────────

      `onDidReceiveNotificationResponse` only fires for a tap that reaches a
      running process. A reminder at nine in the morning, tapped from a lock
      screen on a phone where the app was killed overnight, starts the app —
      and the callback never runs, because there was nothing to call.

      That is the common case rather than the edge one, and it is the half
      that gets missed: everything works in testing, because in testing the
      app is always already open.

      Asked once, here, and only on the launch it belongs to. The plugin keeps
      answering the same thing for the life of the process, so calling it
      later would re-open the same record every time `init` ran.
    */
    if (_ready && !_askedLaunch) {
      _askedLaunch = true;
      try {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          rememberLink(launch?.notificationResponse?.payload);
        }
      } catch (_) {
        // A phone that will not say why it launched is a phone that opens on
        // the dashboard, which is where it would have opened anyway.
      }
    }
  }

  /// Whether the launch reason has already been read. See `init`.
  bool _askedLaunch = false;

  /// Android 13 and up. Returns whether we may actually post anything.
  ///
  /// Below 13 there is no prompt and permission is implicit, which the plugin
  /// reports as null — read as yes.
  Future<bool> ask() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? true;
  }

  Future<bool> permitted() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.areNotificationsEnabled() ?? true;
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /*
    ── What is actually scheduled ──────────────────────────────────────────────

    Read-only, and the answer to the hardest question this app gets asked
    remotely: "the reminders aren't working."

    That sentence covers four different faults — nothing scheduled, scheduled
    for the wrong instant, the OS holding them, or the person having declined
    permission — and from an email they are indistinguishable. This separates
    the first two from the rest.

    Never throws: a phone that will not answer returns nothing, which reads on
    the diagnostics sheet as "none" and is the truthful thing to say.
  */
  Future<List<PendingNotificationRequest>> scheduled() async {
    await init();
    if (!_ready) return const [];

    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const [];
    }
  }

  /// The time zone the schedule is being built in.
  ///
  /// Worth surfacing on its own. Everything here is zoned rather than local —
  /// a phone that crossed a time zone must not fire a 9am reminder at 4am —
  /// so a wrong answer here is a wrong answer everywhere, and `init` falls
  /// back to UTC silently when the platform will not say.
  String get zone => _ready ? tz.local.name : 'not initialised';

  /*
    ── One notification, now ───────────────────────────────────────────────────

    Answers a different question from `scheduled`: whether the OS will deliver
    anything at all. A phone can have sixty perfectly good pending entries and
    still show nothing, because the channel is muted, the app is in a
    battery-restricted bucket, or Do Not Disturb is on — and none of that is
    visible from inside the app.

    Deliberately harmless: it says what it is, it is delivered immediately, and
    it schedules nothing. Somebody who presses it out of curiosity gets one
    notification and no lasting change.
  */
  Future<bool> sendTest() async {
    await init();
    if (!_ready) return false;

    try {
      /*
        A deliberately absurd id, so a test can never collide with a real
        reminder. `reschedule` numbers from zero upwards and cancels the lot
        each time; nothing it writes will ever reach this.
      */
      await _plugin.show(
        999000,
        'Scout checking in',
        'Notifications are working.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            visibility: NotificationVisibility.private,
          ),
        ),
        payload: 'home',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancel everything, then schedule the whole list again.
  ///
  /// ── Why not diff it ───────────────────────────────────────────────────────
  /// Because a diff needs stable ids, and the only stable id available is the
  /// date — which changes the moment somebody edits a purchase date, at which
  /// point the old notification is orphaned and fires anyway. Sixty days of a
  /// busy household is a handful of entries; rebuilding the lot costs
  /// milliseconds and cannot leave a stale one behind.
  ///
  /// Anything already in the past is skipped rather than fired. Scheduling
  /// 9am today at 3pm this afternoon would deliver immediately, which reads as
  /// a bug to the person holding the phone.
  Future<int> reschedule(List<Wake> schedule, {int hour = defaultSendHour}) async {
    await init();
    if (!_ready) return 0;

    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var id = 0;

    for (final wake in pending(schedule)) {
      final parts = wake.on.split('-');
      if (parts.length != 3) continue;

      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year == null || month == null || day == null) continue;

      final at = tz.TZDateTime(tz.local, year, month, day, hour);
      if (!at.isAfter(now)) continue;

      /*
        ── Built per notification, because the expanded text differs ──────────

        `BigTextStyleInformation` is what makes a notification expandable: the
        collapsed line stays one truncated row and pulling it down reveals
        every record on that day with its date. Two different jobs that were
        being done by one string — see `compose`.

        `NotificationVisibility.private` is the other half, and it is the
        setting that lets the detail exist at all. Android redacts a private
        notification on a locked phone and shows it in full once unlocked, so
        "Passport — Nuno · expires Feb 11" is never readable over somebody's
        shoulder on a table. The old design wrote vaguer text instead, which
        protected the lock screen by also hiding the detail from the owner.
      */
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          visibility: NotificationVisibility.private,
          styleInformation: BigTextStyleInformation(
            wake.detail,
            contentTitle: wake.title,
          ),
        ),
      );

      try {
        await _plugin.zonedSchedule(
          id++,
          wake.title,
          wake.body,
          at,
          details,
          // Where the tap should land. Held by the OS until then — which may
          // be sixty days and an app update away, so it is an id rather than
          // anything that could go stale. See logic/deep_link.dart.
          payload: wake.payload,
          /*
            INEXACT, and this is a decision rather than a default.

            An exact alarm on Android 13+ needs SCHEDULE_EXACT_ALARM, which
            Google Play grants to alarm clocks and calendars and refuses to
            most other things — asking for it is a plausible way to fail
            review. Inexact means the OS delivers within a window of its own
            choosing, batched with whatever else it is waking for.

            For "your passport needs starting" that costs nothing. The whole
            schedule is already rounded to a day; being an hour out on a
            warning measured in months is not a defect.
          */
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // One bad instant must not cost the rest of the schedule.
      }
    }

    return id;
  }
}
