/// The lines the dashboard says to you.
///
///   dart test test/nudges_test.dart
///
/// Translated from `test/nudges.test.ts`. Written because two settings were
/// doing nothing: "warn me before a warranty ends" wrote `reminderOffsetsDays`
/// and no code read it, and "remind me" wrote `backupReminderDays`, read only
/// by a hint behind the developer tools. Both could be set, by anyone, to no
/// effect whatsoever. A setting that writes to the database and changes
/// nothing is worse than a missing feature: it looks answered.
///
/// ── Assertions from the web suite that are deliberately not here ──────────
/// Four tested the tip jar, which is dropped from the port on request — see
/// the note in nudges.dart.
///
/// Three tested `nudgeClass`, which built a CSS class list. Flutter has no
/// global style namespace for a kind name to collide in, so the function is
/// gone and its guard is not needed — see the note in nudges.dart.
///
/// Two more tested that garbage in a timestamp field is treated as "never":
/// `reminderOffsetsDays: [NaN]`, and `lastBackupAt: 'not a date'`. **Neither
/// case can be constructed here.** A `List<int>` holds no NaN and a `DateTime?`
/// holds no prose. Those checks move to the backup importer in phase 2, which
/// is where a string from outside actually arrives.
///
/// A test that cannot fail is not a test, so they are removed rather than
/// rewritten into something that always passes.
library;

import 'package:stash_it/logic/nudges.dart';
import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/models/settings.dart';
import 'package:test/test.dart';

final now = DateTime(2026, 8, 12, 9);

DateTime daysAgo(int n) => now.subtract(Duration(days: n));

Settings settings({
  List<int> reminderOffsetsDays = const [30],
  DateTime? lastBackupAt,
  int backupReminderDays = 30,
}) =>
    Settings(
      reminderOffsetsDays: reminderOffsetsDays,
      lastBackupAt: lastBackupAt,
      backupReminderDays: backupReminderDays,
    );

void main() {
  tearDown(() => setEndingSoonDays(defaultEndingSoonDays));

  group('the threshold', () {
    test('the default is thirty days', () {
      expect(endingSoonDays(settings()), 30);
      expect(defaultEndingSoonDays, 30);
    });

    test('a set value is honoured', () {
      expect(endingSoonDays(settings(reminderOffsetsDays: [7])), 7);
    });

    test('an empty list falls back', () {
      expect(endingSoonDays(settings(reminderOffsetsDays: [])), defaultEndingSoonDays);
    });

    test('so does a missing record', () {
      expect(endingSoonDays(null), defaultEndingSoonDays);
    });

    // A restored backup from a future version, or a hand-edited record, must
    // not be able to paint the whole collection amber.
    test('a wild value is clamped up', () {
      expect(endingSoonDays(settings(reminderOffsetsDays: [0])), 1);
    });

    test('and clamped down', () {
      expect(endingSoonDays(settings(reminderOffsetsDays: [99999])), 365);
    });

    /*
      The setting and the amber threshold must be the same number, or the
      dashboard and the list disagree about what "soon" means. There is one
      constant, imported rather than redeclared, and this is the assertion that
      keeps them tied together.
    */
    test('the warranty module takes the setting, and clamps it too', () {
      setEndingSoonDays(endingSoonDays(settings(reminderOffsetsDays: [7])));
      expect(getEndingSoonDays(), 7);

      setEndingSoonDays(9999);
      expect(getEndingSoonDays(), 365);
    });
  });

  group('the backup nudge', () {
    test('an overdue backup nudges, and says how long it has been', () {
      final n = backupNudge(
        lastBackupAt: daysAgo(40),
        everyDays: 30,
        itemCount: 5,
        now: now,
      );
      expect(n, isNotNull);
      expect(n!.title, 'Last backup was 40 days ago');
    });

    test('a recent one does not', () {
      expect(
        backupNudge(lastBackupAt: daysAgo(3), everyDays: 30, itemCount: 5, now: now),
        isNull,
      );
    });

    test('the day it comes due, it does', () {
      expect(
        backupNudge(lastBackupAt: daysAgo(30), everyDays: 30, itemCount: 5, now: now),
        isNotNull,
      );
    });

    test('never having backed up nudges, and counts what is at stake', () {
      final n = backupNudge(everyDays: 30, itemCount: 5, now: now);
      expect(n!.title, 'No backup yet');
      expect(n.body, contains('5 items live'));
    });

    test('and one item reads as one item', () {
      final n = backupNudge(everyDays: 30, itemCount: 1, now: now);
      expect(n!.body, contains('1 item lives'));
    });

    // "Never" is a choice, not an interval of zero days.
    test('never means never', () {
      expect(backupNudge(everyDays: 0, itemCount: 5, now: now), isNull);
    });

    // Nagging someone to back up nothing is how reminders get ignored.
    test('an empty collection is left alone', () {
      expect(backupNudge(everyDays: 30, itemCount: 0, now: now), isNull);
    });
  });

  group('the line on the dashboard', () {
    /*
      Separate from the nudge above, and the difference is the point. A nudge is
      a warning: it appears when the interval lapses and can be dismissed. This
      is a fact, and it never goes away — because between nudges the dashboard
      said nothing about backups at all, and a quiet screen reads as "fine".
    */
    test('a recent backup still says so, and stays quiet about it', () {
      final s = backupStatus(
        lastBackupAt: daysAgo(3),
        everyDays: 30,
        itemCount: 5,
        now: now,
      );
      expect(s!.label, 'Backed up 3 days ago');
      expect(s.tone, BackupTone.ok);
    });

    test('today is named, not counted', () {
      final s = backupStatus(
        lastBackupAt: daysAgo(0),
        everyDays: 30,
        itemCount: 5,
        now: now,
      );
      expect(s!.label, 'Backed up today');
    });

    test('and so is yesterday', () {
      final s = backupStatus(
        lastBackupAt: daysAgo(1),
        everyDays: 30,
        itemCount: 5,
        now: now,
      );
      expect(s!.label, 'Backed up yesterday');
    });

    test('a lapsed one goes amber', () {
      final s = backupStatus(
        lastBackupAt: daysAgo(40),
        everyDays: 30,
        itemCount: 5,
        now: now,
      );
      expect(s!.tone, BackupTone.due);
    });

    test('never is its own state', () {
      final s = backupStatus(everyDays: 30, itemCount: 5, now: now);
      expect(s!.tone, BackupTone.never);
      expect(s.days, isNull);
      expect(s.label, 'Never backed up');
    });

    /*
      Turning the reminder off is a decision about being interrupted, not a
      claim that a six-month-old backup is current. The line still colours; it
      just never grows into a nudge.
    */
    test('switching the reminder off does not make an old backup fresh', () {
      final s = backupStatus(
        lastBackupAt: daysAgo(200),
        everyDays: 0,
        itemCount: 5,
        now: now,
      );
      expect(s!.tone, BackupTone.due);
    });

    test('and the nudge stays silent for it', () {
      expect(
        backupNudge(lastBackupAt: daysAgo(200), everyDays: 0, itemCount: 5, now: now),
        isNull,
      );
    });

    // Nothing to protect, nothing to say — the same rule the nudge follows.
    test('an empty collection gets no line', () {
      expect(backupStatus(everyDays: 30, itemCount: 0, now: now), isNull);
    });
  });

  group('the warranty nudge', () {
    test('nothing ending means nothing said', () {
      expect(warrantyNudge(endingSoon: 0, days: 30), isNull);
    });

    test('one reads as singular, and offers to show it', () {
      final n = warrantyNudge(endingSoon: 1, days: 14);
      expect(n!.title, '1 warranty ends within 14 days');
      expect(n.action, 'See it');
    });

    test('several read as plural', () {
      final n = warrantyNudge(endingSoon: 4, days: 30);
      expect(n!.title, '4 warranties end within 30 days');
      expect(n.action, 'See them');
    });

    test('the window quoted is the one that was set', () {
      expect(warrantyNudge(endingSoon: 2, days: 90)!.title, contains('90 days'));
    });
  });

  group('all of it', () {
    test('both can be due at once, in the order that matters', () {
      final all = dueNudges(
        settings: settings(lastBackupAt: daysAgo(60)),
        itemCount: 9,
        endingSoon: 2,
        now: now,
      );

      // Backup leads — it is the one where waiting can cost you data.
      expect(all.map((n) => n.kind), [NudgeKind.backup, NudgeKind.warranty]);
    });

    test('a tidy collection says nothing', () {
      final quiet = dueNudges(
        settings: settings(lastBackupAt: daysAgo(1)),
        itemCount: 9,
        endingSoon: 0,
        now: now,
      );
      expect(quiet, isEmpty);
    });

    test('no settings, no nudges', () {
      expect(
        dueNudges(settings: null, itemCount: 9, endingSoon: 3, now: now),
        isEmpty,
      );
    });

    test('the warranty line quotes the setting, not the default', () {
      final all = dueNudges(
        settings: settings(reminderOffsetsDays: [90], lastBackupAt: daysAgo(1)),
        itemCount: 9,
        endingSoon: 2,
        now: now,
      );
      expect(all.single.title, contains('90 days'));
    });
  });

  group('the preview', () {
    // Armed from the developer card, read by the dashboard, cleared on leaving
    // it. Nothing persists it: a preview that survives a restart is a preview
    // somebody will eventually mistake for the real alarm.
    test('nothing is armed to begin with', () {
      clearNudgePreview();
      expect(nudgePreviewArmed(), isFalse);
    });

    test('arming shows, and leaving the screen clears it', () {
      armNudgePreview();
      expect(nudgePreviewArmed(), isTrue);
      clearNudgePreview();
      expect(nudgePreviewArmed(), isFalse);
    });

    test('clearing twice is harmless', () {
      clearNudgePreview();
      clearNudgePreview();
      expect(nudgePreviewArmed(), isFalse);
    });

    test('the developer preview has one of each, and they are the real ones', () {
      final samples = sampleNudges(now);
      expect(samples.map((n) => n.kind), [NudgeKind.backup, NudgeKind.warranty]);
      for (final n in samples) {
        expect(n.title, isNotEmpty);
        expect(n.body, isNotEmpty);
        expect(n.action, isNotEmpty);
      }
    });

    test('and the backup sample is the real copy, not sample text', () {
      expect(sampleNudges(now).first.title, 'Last backup was 120 days ago');
    });
  });
}
