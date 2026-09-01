/// Reminders: which days wake the phone, and what is said when it does.
///
///   dart test test/reminders_test.dart
///
/// Translated from `test/push.test.ts`, minus everything about a server.
///
/// The web suite spent half its length proving that what got uploaded was
/// dates and nothing else — the payload keys pinned exactly, a loop asserting
/// that no item name, service, person or amount appeared on the wire. **None of
/// that has a counterpart here, because nothing is uploaded.** What survives is
/// the part that was always the actual feature: which days earn a wake, and
/// what a lock screen is allowed to say.
///
/// One of those assertions is kept anyway, in a weaker form — see
/// 'the dates carry no names'. It no longer guards a privacy boundary, but it
/// still guards a function whose name promises dates.
library;

import 'package:stash_it/logic/dates.dart';
import 'package:stash_it/logic/deep_link.dart';
import 'package:stash_it/logic/reminders.dart';
import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// 17 August 2026. See the note on timezones in timeline_test.dart.
final now = DateTime(2026, 8, 17);

/// An item bought `ago` days back, with a term in months.
Item warranted(String name, int months, int ago, {int? leadDays}) {
  return Item(
    id: name,
    name: name,
    propertyId: 'p',
    purchaseDate: toIsoDate(addDays(now, -ago)),
    warranty:
        Warranty(months: months, unit: WarrantyUnit.months, amount: months),
    leadDays: leadDays,
  );
}

Subscription sub({
  String id = 's',
  String name = 'Netflix',
  Cadence cadence = Cadence.monthly,
  String anchorDate = '2026-09-01',
  int? remindDays,
}) =>
    Subscription(
      id: id,
      propertyId: 'p',
      name: name,
      cadence: cadence,
      anchorDate: anchorDate,
      amountCents: 1549,
      currency: 'USD',
      remindDays: remindDays,
    );

Paper paper({
  String id = 'd',
  PaperKind kind = PaperKind.passport,
  String label = 'Passport',
  String expiresOn = '2027-06-15',
  String? holder,
  int? leadDays,
}) =>
    Paper(
      id: id,
      propertyId: 'p',
      kind: kind,
      label: label,
      expiresOn: expiresOn,
      holder: holder,
      leadDays: leadDays,
    );

void main() {
  setUp(() => setEndingSoonDays(30));
  tearDown(() => setEndingSoonDays(defaultEndingSoonDays));

  group('what earns a wake', () {
    /*
      A DOCUMENT wakes you on its renew-by date — the day it stops being fine
      and starts being "start now". Not its expiry: by then the point has gone,
      which is the mistake the whole documents feature exists to avoid.
    */
    test('a document wakes you on its renew-by, not its expiry', () {
      final s = reminderSchedule(
        [],
        [],
        [paper(expiresOn: '2026-10-01', leadDays: 30)],
        now,
      );
      expect(s.first.on, '2026-09-01');
      expect(s.any((w) => w.on == '2026-10-01'), isFalse);
    });

    /*
      A WARRANTY wakes you the day it enters the ending-soon window — the same
      threshold the ring and the list use, so the dashboard and the
      notification can never disagree about what counts as soon.

      Headphones: bought 690 days ago with 24 months of cover, so cover ends 26
      Sep 2026 — forty days of runway, turning amber in ten.
    */
    test('a warranty wakes you when it turns amber', () {
      final s =
          reminderSchedule([warranted('Headphones', 24, 690)], [], [], now);
      expect(s.length, 1);
      expect(s.first.on, '2026-08-27');
    });

    /*
      A SUBSCRIPTION WAKES YOU ONLY IF YOU ASKED. Nine monthly services would
      otherwise mean nine notifications a month for money that leaves whether
      you know or not — which is how people learn to swipe reminders away.
    */
    test('a plain renewal wakes nobody', () {
      expect(reminderSchedule([], [sub()], [], now), isEmpty);
    });

    test('but one with a reminder does', () {
      final s = reminderSchedule([], [sub(remindDays: 3)], [], now);
      expect(s.first.on, '2026-08-29');
    });

    test('and a zero reminder is no reminder', () {
      expect(reminderSchedule([], [sub(remindDays: 0)], [], now), isEmpty);
    });
  });

  group('the window', () {
    test('nothing beyond the horizon', () {
      final s = reminderSchedule([], [], [paper(expiresOn: '2030-01-01')], now);
      expect(s, isEmpty);
    });

    test('and the default passport is already past it', () {
      // Expires 15 Jun 2027, 240 days of runway → start 18 Oct 2026, which is
      // 62 days out. The horizon is 60. This is the fixture, not a bug.
      expect(reminderSchedule([], [], [paper()], now), isEmpty);
    });

    // Yesterday's threshold has already passed; the dashboard is carrying it.
    test('nothing already behind us', () {
      final s = reminderSchedule(
        [],
        [],
        [paper(id: 'g', expiresOn: '2026-08-16', leadDays: 0)],
        now,
      );
      expect(s, isEmpty);
    });

    // Today does count — something crossing this morning is what a reminder
    // is for.
    test('but today does', () {
      final s = reminderSchedule(
        [],
        [],
        [paper(id: 't', expiresOn: '2026-08-17', leadDays: 0)],
        now,
      );
      expect(s.first.on, '2026-08-17');
    });

    test('an unreadable date is skipped', () {
      expect(reminderSchedule([], [], [paper(expiresOn: '')], now), isEmpty);
    });
  });

  group('the words', () {
    Due due(String label, [String why = 'expires Feb 11']) =>
        Due(label, why, const DeepLink.home());

    test('one thing is named, and says what is happening to it', () {
      final n = compose([due('Passport — Nuno', 'expires Feb 11')]);
      expect(n.title, 'Passport — Nuno');
      // It used to say "Needs a look in Stash it." on every single one. See
      // the note on `compose` for why the detail can live here now.
      expect(n.body, 'Expires Feb 11.');
    });

    test('two are counted and both named', () {
      final n = compose([due('Inspection — Golf'), due('Passport — Nuno')]);
      expect(n.title, '2 things need you');
      expect(n.body, 'Inspection — Golf and Passport — Nuno');
    });

    /*
      ── The expanded body is where the detail goes ────────────────────────

      Collapsed is one truncated line and has to survive being cut off.
      Expanded is what somebody sees after deliberately pulling the
      notification down, which is a different audience: whoever is holding
      the phone.
    */
    test('and the expanded body lists every one with its reason', () {
      final n = compose([
        due('Inspection — Golf', 'expires Mar 2'),
        due('Passport — Nuno', 'expires Feb 11'),
      ]);

      expect(
          n.detail,
          'Inspection — Golf · expires Mar 2\n'
          'Passport — Nuno · expires Feb 11');
    });

    test('a single one expands too, rather than repeating its own title', () {
      final n = compose([due('Passport — Nuno', 'expires Feb 11')]);
      expect(n.detail, 'Passport — Nuno · expires Feb 11');
    });

    /*
      Two named and the rest counted. A lock screen truncates, so five names
      become three and an ellipsis — which is a worse version of saying "and 3
      more" deliberately.
    */
    test('five are two and a count', () {
      expect(
        compose([due('E'), due('D'), due('C'), due('B'), due('A')]).body,
        'A, B and 3 more',
      );
    });

    test('sorted, so the same day reads the same twice', () {
      expect(compose([due('B'), due('A')]).body,
          compose([due('A'), due('B')]).body);
      expect(compose([due('B'), due('A')]).body, 'A and B');
    });

    test('and an empty day still has something to say', () {
      // Unreachable through reminderSchedule, which never makes an empty day —
      // but a composer that can throw is one bad refactor from a crash inside
      // a notification callback, where nothing will ever show the stack trace.
      expect(compose([]).title, isNotEmpty);
    });

    test('a document is named with its holder', () {
      final s = reminderSchedule(
        [],
        [],
        [paper(expiresOn: '2026-10-01', leadDays: 30, holder: 'Nuno')],
        now,
      );
      expect(s.first.title, 'Passport — Nuno');
    });

    /*
      ── This test used to assert the opposite ─────────────────────────────

      It checked that no digit appeared anywhere in the notification, because
      the design said names and nothing else — a lock screen is readable by
      anybody holding the phone.

      That reasoning was right about the lock screen and wrong about
      everything else: it also stripped the detail from the notification shade
      on an UNLOCKED phone, where nobody but the owner is looking. The lock
      screen is handled by `NotificationVisibility.private` now, which is what
      should have been doing the job all along; vaguer text was standing in
      for a setting.

      So the assertion inverts: the date has to be there.
    */
    test('and says when, now that the lock screen is redacted properly', () {
      final s = reminderSchedule(
        [],
        [],
        [paper(expiresOn: '2026-10-01', leadDays: 30, holder: 'Nuno')],
        now,
      );

      expect(s.first.body, contains('Oct'));
      expect(s.first.detail, contains('Passport — Nuno'));
      expect(s.first.detail, contains('Oct'));
    });
  });

  /*
    ── Where the tap lands ───────────────────────────────────────────────────

    A day holding one record can open that record. A day holding four cannot:
    the notification is a summary, and opening the alphabetically-first of them
    would be arbitrary in a way somebody would notice — it was named first for
    a reason that has nothing to do with which one they care about.
  */
  group('where a reminder points', () {
    test('a lone record on a day opens that record', () {
      final s = reminderSchedule(
        [],
        [],
        [paper(expiresOn: '2026-10-01', leadDays: 30, holder: 'Nuno')],
        now,
      );

      final link = parseLink(s.first.payload);
      expect(link?.kind, LinkKind.paper);
      expect(link?.id, isNotEmpty);
    });

    test('a day with several opens the dashboard', () {
      // Two documents sharing a start date.
      final s = reminderSchedule(
        [],
        [],
        [
          paper(expiresOn: '2026-10-01', leadDays: 30, holder: 'Nuno'),
          paper(expiresOn: '2026-10-01', leadDays: 30, holder: 'Ana'),
        ],
        now,
      );

      expect(s, hasLength(1), reason: 'same day, so one notification');
      expect(parseLink(s.first.payload), const DeepLink.home());
    });

    test('and every wake carries something readable', () {
      final s = reminderSchedule(
        [warranted('Headphones', 24, 690)],
        [sub(name: 'Netflix', remindDays: 3)],
        [paper(expiresOn: '2026-10-01', leadDays: 30, holder: 'Nuno')],
        now,
      );

      for (final wake in s) {
        expect(parseLink(wake.payload), isNotNull, reason: wake.on);
      }
    });
  });

  group('a busy day', () {
    List<Wake> mixed() => reminderSchedule(
          [warranted('Headphones', 24, 690)], // 27 Aug
          [sub(name: 'Netflix', remindDays: 3)], // 29 Aug
          [
            paper(expiresOn: '2026-10-01', leadDays: 30, holder: 'Nuno')
          ], // 1 Sep
          now,
        );

    test('three sources land on three days, in order', () {
      expect(wakeDates(mixed()), ['2026-08-27', '2026-08-29', '2026-09-01']);
    });

    test('two things on one day are one notification', () {
      final s = reminderSchedule(
        [warranted('Headphones', 24, 690)],
        // Anchored so its reminder falls on 27 Aug too.
        [sub(name: 'Netflix', anchorDate: '2026-08-30', remindDays: 3)],
        [],
        now,
      );
      expect(s.length, 1);
      expect(s.first.title, '2 things need you');
      expect(s.first.body, 'Headphones and Netflix');
    });

    /*
      This no longer guards a privacy boundary — nothing is uploaded, so there
      is no wire to keep clean. It guards a promise in a function name: if
      `wakeDates` ever starts returning anything but bare dates, whatever reads
      it is being handed something it did not ask for.
    */
    test('the dates carry no names', () {
      final dates = wakeDates(mixed());
      expect(dates.every((d) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)),
          isTrue);
      final asText = dates.join(' ');
      for (final secret in ['Headphones', 'Netflix', 'Passport', 'Nuno']) {
        expect(asText.contains(secret), isFalse, reason: secret);
      }
    });

    test('and no times, only days', () {
      final asText = wakeDates(mixed()).join(' ');
      expect(asText.contains('T'), isFalse);
      expect(asText.contains(':'), isFalse);
    });

    test('today’s note is found, and a quiet day has none', () {
      expect(noteFor(mixed(), DateTime(2026, 9, 1))?.on, '2026-09-01');
      expect(noteFor(mixed(), DateTime(2026, 9, 2)), isNull);
    });
  });

  group('handing it to the scheduler', () {
    test('a date becomes nine in the morning, locally', () {
      final at = wakeTimes([const Wake('2026-09-04', 't', 'b')]).first;
      expect(at.hour, 9);
      expect(at.year, 2026);
      expect(at.month, 9);
      expect(at.day, 4);
    });

    test('and the hour can be asked for', () {
      expect(
          wakeTimes([const Wake('2026-09-04', 't', 'b')], 18).first.hour, 18);
    });

    test('they come back sorted', () {
      final at = wakeTimes([
        const Wake('2026-09-04', 't', 'b'),
        const Wake('2026-08-30', 't', 'b'),
      ]);
      expect(at.first.isBefore(at.last), isTrue);
    });

    test('an unreadable day is dropped rather than throwing', () {
      expect(wakeTimes([const Wake('soon', 't', 'b')]), isEmpty);
    });

    /*
      iOS holds 64 pending notifications per app and silently drops the rest,
      so the trimming has to happen here rather than being discovered as
      "reminders stop working in November".
    */
    // Real consecutive dates, crossing two month ends, so the trimming is
    // asserted against the calendar rather than against string arithmetic.
    List<Wake> ninety() => [
          for (var i = 0; i < 90; i++)
            Wake(toIsoDate(addDays(DateTime(2026, 9, 1), i)), 't', 'b'),
        ];

    test('a long schedule is trimmed to what iOS will hold', () {
      expect(ninety().length, 90);
      expect(pending(ninety()).length, maxPending);
    });

    test('and it keeps the nearest ones', () {
      final kept = pending(ninety());
      expect(kept.first.on, '2026-09-01');
      // 1 Sep plus 63 more days.
      expect(kept.last.on,
          toIsoDate(addDays(DateTime(2026, 9, 1), maxPending - 1)));
      expect(kept.last.on, '2026-11-03');
    });

    test('the trimming survives an unsorted list', () {
      final shuffled = ninety().reversed.toList();
      expect(pending(shuffled).first.on, '2026-09-01');
    });

    test('a short one is left alone', () {
      final few = [const Wake('2026-09-01', 't', 'b')];
      expect(pending(few).length, 1);
    });
  });

  group('an item’s own lead time', () {
    /*
      The wake has to move with the item's lead, or the phone buzzes on a day
      the dashboard says nothing is happening — and the dashboard is the thing
      people check to find out whether the notification was real.
    */
    test('the default lead schedules one wake', () {
      expect(
          reminderSchedule([warranted('Headphones', 24, 690)], [], [], now)
              .length,
          1);
    });

    /*
      A year of notice on cover that ends in forty days puts the wake in the
      past, and the past is not scheduled — the dashboard is already carrying
      it, which is exactly right for something you asked to hear about a year
      ahead and are now three hundred days late seeing.
    */
    test('a lead longer than the runway wakes nobody', () {
      final kit = warranted('Headphones', 24, 690, leadDays: 365);
      expect(reminderSchedule([kit], [], [], now), isEmpty);
    });

    test('and a shorter lead moves the wake nearer the end', () {
      final late = reminderSchedule(
        [warranted('Headphones', 24, 690, leadDays: 3)],
        [],
        [],
        now,
      );
      final defaulted =
          reminderSchedule([warranted('Headphones', 24, 690)], [], [], now);
      expect(late.length, 1);
      expect(late.first.on, '2026-09-23');
      expect(late.first.on.compareTo(defaulted.first.on), greaterThan(0));
    });
  });
}
