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
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

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

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

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

      try {
        await _plugin.zonedSchedule(
          id++,
          wake.title,
          wake.body,
          at,
          details,
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
