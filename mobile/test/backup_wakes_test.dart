/// Telling somebody their backup is overdue, while the app is shut.
///
///   flutter test test/backup_wakes_test.dart
///
/// Every other reminder in this app is derived from a record with a date on
/// it. This one is derived from an ABSENCE — the backup that has not happened —
/// which makes it the only reminder that can be wrong by simply never firing.
/// There is no row anywhere to look at and notice it is missing.
///
/// So the dates are worked out in pure Dart and pinned here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/dates.dart';
import 'package:stash_it/logic/reminders.dart';

/// 1 March 2026, as everywhere else in these tests.
final today = DateTime(2026, 3, 1);

List<String> daysOf(List<Wake> wakes) => [for (final w in wakes) w.on];

void main() {
  group('when it says nothing at all', () {
    test('the interval set to zero means never', () {
      // Somebody went into Settings and turned this off. Zero must not be read
      // as "every zero days", which is the reading that produces a notification
      // every single day for ever.
      expect(
        backupWakes(everyDays: 0, itemCount: 10, lastBackupAt: today, now: today),
        isEmpty,
      );
    });

    test('an empty stash is left alone', () {
      /*
        Nagging somebody to back up nothing is how a reminder teaches people to
        ignore reminders — and the first thing a new user would meet is a
        warning about protecting data they have not entered yet.

        Same rule as `backupNudge` on the dashboard, deliberately.
      */
      expect(
        backupWakes(everyDays: 30, itemCount: 0, lastBackupAt: null, now: today),
        isEmpty,
      );
    });

    test('a recent backup is not chased', () {
      final wakes = backupWakes(
        everyDays: 30,
        itemCount: 10,
        lastBackupAt: addDays(today, -3),
        now: today,
      );

      expect(wakes.first.on, isNot(toIsoDate(today)));
    });
  });

  group('when the interval falls due', () {
    test('counted from the last backup, not from today', () {
      /*
        The cycle has to be anchored to the backup, because the schedule is
        rebuilt on every launch. Anchored to "today" it would move forward a
        day every time somebody opened the app, and the reminder would never
        arrive on a phone in daily use — which is every phone.
      */
      final wakes = backupWakes(
        everyDays: 30,
        itemCount: 10,
        lastBackupAt: addDays(today, -10),
        now: today,
      );

      expect(wakes.first.on, toIsoDate(addDays(today, 20)));
    });

    test('and keeps asking on the same interval', () {
      // The user chose "once, then every N days again". A single warning that
      // is missed is a warning that did not happen.
      final wakes = backupWakes(
        everyDays: 30,
        itemCount: 10,
        lastBackupAt: today,
        now: today,
      );

      expect(
        daysOf(wakes),
        [
          toIsoDate(addDays(today, 30)),
          toIsoDate(addDays(today, 60)),
        ],
      );
    });

    test('nothing beyond the horizon the OS is handed', () {
      final wakes = backupWakes(
        everyDays: 7,
        itemCount: 10,
        lastBackupAt: today,
        now: today,
        horizon: 20,
      );

      expect(daysOf(wakes), [
        toIsoDate(addDays(today, 7)),
        toIsoDate(addDays(today, 14)),
      ]);
    });
  });

  group('when it is already overdue', () {
    test('it says so today rather than waiting for the next multiple', () {
      /*
        The case that matters most, and the one a naive implementation gets
        wrong. A backup 100 days old on a 30-day interval has missed the wakes
        at 30, 60 and 90 — every one of them in the past. Stepping to the next
        multiple would say nothing for another 20 days, about a phone that is
        already the only copy of everything.
      */
      final wakes = backupWakes(
        everyDays: 30,
        itemCount: 10,
        lastBackupAt: addDays(today, -100),
        now: today,
      );

      expect(wakes.first.on, toIsoDate(today));
    });

    test('then resumes the cycle without repeating today', () {
      final wakes = backupWakes(
        everyDays: 30,
        itemCount: 10,
        lastBackupAt: addDays(today, -100),
        now: today,
      );

      // 120 days after the backup, which is 20 days from today.
      expect(daysOf(wakes), [
        toIsoDate(today),
        toIsoDate(addDays(today, 20)),
        toIsoDate(addDays(today, 50)),
      ]);
    });

    test('exactly due today is said once, not twice', () {
      // The off-by-one that a boundary invites: the cycle lands on today AND
      // the overdue branch adds today.
      final wakes = backupWakes(
        everyDays: 30,
        itemCount: 10,
        lastBackupAt: addDays(today, -30),
        now: today,
      );

      expect(
        daysOf(wakes).where((on) => on == toIsoDate(today)),
        hasLength(1),
      );
    });

    test('never backed up at all is overdue by definition', () {
      // There is no date to count from, and nothing anywhere but this phone.
      final wakes = backupWakes(
        everyDays: 30,
        itemCount: 10,
        lastBackupAt: null,
        now: today,
      );

      expect(wakes.first.on, toIsoDate(today));
    });
  });

  group('what it actually says', () {
    test('no names, no counts, nothing out of the records', () {
      /*
        A notification can be read off a lock screen. This one has no reason to
        name anything: what is overdue is the backup, and the sentence is the
        same whether there are four records or four hundred.
      */
      final wake = backupWakes(
        everyDays: 30,
        itemCount: 137,
        lastBackupAt: null,
        now: today,
      ).first;

      expect(wake.title, isNot(contains('137')));
      expect(wake.body, isNot(contains('137')));
      expect(wake.detail, isNot(contains('137')));
    });

    test('the expanded line says what to actually do', () {
      // Collapsed says there is a problem; expanded is where somebody who
      // pulled it down finds the two taps that fix it.
      final wake = backupWakes(
        everyDays: 30,
        itemCount: 10,
        lastBackupAt: null,
        now: today,
      ).first;

      expect(wake.detail, isNot(wake.body));
      expect(wake.detail.toLowerCase(), contains('settings'));
    });
  });
}
