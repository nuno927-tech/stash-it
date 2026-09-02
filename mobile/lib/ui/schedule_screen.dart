/// Every reminder that is going to fire, and when.
///
/// ── Why this exists ────────────────────────────────────────────────────────
/// Notifications are the one part of the app that cannot be observed. They are
/// scheduled now and arrive days later, on a phone that may have been off,
/// after an OS that is free to delay them. When one fails to turn up there is
/// nothing to look at: no log, no list, no way to tell "never scheduled" from
/// "scheduled and swallowed".
///
/// This is that list. It is behind the developer tools because it is a
/// diagnostic rather than a feature — somebody who wants to know what the app
/// will tell them can read the dashboard.
///
/// ── Derived, not asked for ─────────────────────────────────────────────────
/// The obvious implementation asks the plugin for its pending notifications.
/// That answer is thinner than it looks: it gives ids and text but not the
/// instant each one fires at, which is the single thing this screen exists to
/// show.
///
/// So it recomputes the schedule from the database — the same call
/// `syncReminders` makes — and shows that. The honest caveat is written on the
/// screen: this is what the app WOULD schedule, and it matches what the OS
/// holds because both come from the same function, but it is not a readout of
/// the OS's own list.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/dates.dart';
import '../logic/reminders.dart';
import '../notify/sync.dart';
import 'theme.dart';

/// What the screen needs: the schedule, and enough context to read it.
class _Planned {
  const _Planned({
    required this.wakes,
    required this.hour,
    required this.enabled,
    required this.permitted,
    required this.pending,
  });

  final List<Wake> wakes;
  final int hour;
  final bool enabled;
  final bool permitted;

  /// What the OS says it is holding. A different number from `wakes.length`
  /// is the interesting case and the reason both are shown.
  final int pending;
}

Future<void> showSchedule(BuildContext context, Repository repo) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (context) => ScheduleScreen(repo: repo)),
    );

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({required this.repo, super.key});

  final Repository repo;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<_Planned> _data = _gather();

  Future<_Planned> _gather() async {
    final settings = await widget.repo.settings();
    final items = await widget.repo.activeItems();

    final wakes = [
      ...reminderSchedule(
        items,
        await widget.repo.activeSubscriptions(),
        await widget.repo.activePapers(),
      ),
      ...backupWakes(
        everyDays: settings.backupReminderDays,
        itemCount: items.length,
        lastBackupAt: settings.lastBackupAt,
      ),
    ]..sort((a, b) => a.on.compareTo(b.on));

    return _Planned(
      wakes: wakes,
      hour: settings.reminderHour ?? defaultSendHour,
      // Null is on. Same rule as `syncReminders`, and worth repeating here
      // rather than reading as "off" — a screen that disagreed with the
      // scheduler about whether reminders are on would be worse than no screen.
      enabled: settings.notifyEnabled != false,
      permitted: await notifications.permitted(),
      pending: (await notifications.scheduled()).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Scaffold(
      backgroundColor: c.slate900,
      appBar: AppBar(
        backgroundColor: c.slate900,
        title: Text(
          'Scheduled reminders',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.6,
            color: c.text,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Recalculate',
            icon: Icon(Icons.refresh, color: c.muted),
            onPressed: () => setState(() => _data = _gather()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<_Planned>(
          future: _data,
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _Summary(data: data, c: c),
                const SizedBox(height: 18),
                if (data.wakes.isEmpty)
                  Text(
                    'Nothing scheduled. With reminders on, that means nothing '
                    'in the next $horizonDays days needs you — which is the '
                    'answer this screen exists to distinguish from a fault.',
                    style: hintStyle(c),
                  )
                else
                  for (final wake in data.wakes) _Row(wake: wake, data: data),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The state of the machinery, above the list it produced.
///
/// All four lines matter and each explains a different empty list: switched
/// off, not permitted, nothing due, or scheduled-but-the-OS-disagrees.
class _Summary extends StatelessWidget {
  const _Summary({required this.data, required this.c});

  final _Planned data;
  final StashColors c;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Reminders', data.enabled ? 'on' : 'off'),
      ('Permission', data.permitted ? 'granted' : 'not granted'),
      ('Delivery hour', '${data.hour.toString().padLeft(2, '0')}:00'),
      ('Days worked out', '$horizonDays'),
      ('This screen counts', '${data.wakes.length}'),
      /*
        The one comparison worth having.

        These two should match. When they do not, the app and the OS disagree
        about what is going to happen, and that is a real fault rather than a
        display quirk — the cap in `maxPending`, a permission revoked since the
        last sync, or a reschedule that never ran.
      */
      ('The phone is holding', '${data.pending}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 13,
                      color: c.muted,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: fontMono,
                    fontFeatures: tabularFigures,
                    fontSize: 13,
                    color: data.wakes.length != data.pending &&
                            label == 'The phone is holding'
                        ? c.ember
                        : c.text,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One reminder: the day it fires, at what time, and what it will say.
class _Row extends StatelessWidget {
  const _Row({required this.wake, required this.data});

  final Wake wake;
  final _Planned data;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final on = parseDate(wake.on);
    final away = on == null ? null : daysUntil(on);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.slate800,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${wake.on} at '
                  '${data.hour.toString().padLeft(2, '0')}:00',
                  style: TextStyle(
                    fontFamily: fontMono,
                    fontFeatures: tabularFigures,
                    fontSize: 12.5,
                    color: c.text,
                  ),
                ),
              ),
              if (away != null)
                Text(
                  away <= 0 ? 'today' : 'in $away ${away == 1 ? 'day' : 'days'}',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12,
                    color: c.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            wake.title,
            style: TextStyle(
              fontFamily: fontBody,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: c.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(wake.body, style: hintStyle(c)),

          /*
            The expanded body, when it differs.

            Android shows the short line collapsed and this one when somebody
            pulls the notification down. They are different strings for a
            reason, and a screen that showed only one of them could not tell
            you which of the two was wrong.
          */
          if (wake.detail != wake.body) ...[
            const SizedBox(height: 6),
            Text(
              wake.detail,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 12,
                height: 1.35,
                color: c.muted,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'opens: ${wake.payload}',
            style: TextStyle(
              fontFamily: fontMono,
              fontFeatures: tabularFigures,
              fontSize: 11,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}
