/// The merged timeline, and the ring that sits above it.
///
///   dart test test/timeline_test.dart
///
/// Translated from `test/timeline.test.ts`. Everything here is about ordering.
/// The dashboard used to keep three separate "next up" rows, one per kind, each
/// sorted only against its own — so the question "what should I deal with" had
/// three answers and no way to compare them. These checks are the comparison.
library;

import 'package:stash_it/logic/dates.dart';
import 'package:stash_it/logic/timeline.dart';
import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// 17 August 2026.
///
/// The TypeScript pins `process.env.TZ = 'America/New_York'` at the top of this
/// suite, because a date test that passes in one zone and fails in another is
/// worse than no test. Dart has no equivalent knob — the VM takes the host's
/// zone and will not be told otherwise. That is fine here and only here: every
/// function under test builds its dates through the `DateTime` constructor,
/// which resolves to local midnight in whatever zone is running, so the
/// arithmetic is zone-relative on both sides of every comparison.
///
/// If a UTC conversion ever appears in the logic, this stops being true and
/// these tests start failing somewhere in the Pacific. That is the tripwire.
final now = DateTime(2026, 8, 17);

Item item({String id = 'i', String name = 'Thing'}) =>
    Item(id: id, name: name, propertyId: 'p');

/// An item bought `ago` days back, with a term in months.
Item warranted(String name, int months, int ago) {
  final bought = addDays(now, -ago);
  return Item(
    id: name,
    name: name,
    propertyId: 'p',
    purchaseDate: toIsoDate(bought),
    warranty:
        Warranty(months: months, unit: WarrantyUnit.months, amount: months),
  );
}

Subscription sub({
  String id = 's',
  String name = 'Netflix',
  Cadence cadence = Cadence.monthly,
  String anchorDate = '2026-08-22',
  int amountCents = 1549,
  int? remindDays,
}) =>
    Subscription(
      id: id,
      propertyId: 'p',
      name: name,
      cadence: cadence,
      anchorDate: anchorDate,
      amountCents: amountCents,
      currency: 'USD',
      remindDays: remindDays,
    );

Paper paper({
  String id = 'd',
  PaperKind kind = PaperKind.passport,
  String label = 'Passport',
  String expiresOn = '2027-02-11',
  String? holder,
}) =>
    Paper(
      id: id,
      propertyId: 'p',
      kind: kind,
      label: label,
      expiresOn: expiresOn,
      holder: holder,
    );

List<String> keys(List<Entry> e) => e.map((x) => x.key).toList();

void main() {
  // The app's own "ending soon" window, so the fixtures and the dashboard
  // agree about which warranties are worth mentioning.
  setUp(() => setEndingSoonDays(30));
  tearDown(() => setEndingSoonDays(defaultEndingSoonDays));

  group('the ordering, in full', () {
    /*
      THE CASE THE FILE EXISTS FOR. Chronologically this list runs Netflix (5
      days), the inspection (already gone), the passport (already needed
      starting). By date the direct debit leads and the cancelled holiday is
      third.
    */
    List<Entry> line() => buildTimeline(
          [warranted('Headphones', 24, 710)], // 20 days of cover left
          [sub(id: 'nflx', name: 'Netflix', anchorDate: '2026-08-22')],
          [
            paper(
              id: 'mot',
              kind: PaperKind.vehicle,
              label: 'Inspection',
              holder: 'Golf',
              expiresOn: '2026-07-10',
            ),
            paper(
                id: 'pp',
                label: 'Passport',
                holder: 'Nuno',
                expiresOn: '2027-02-11'),
          ],
          now,
        );

    test('everything lands in one list', () {
      expect(line().length, 4, reason: keys(line()).join(' → '));
    });

    test('the expired document leads', () {
      expect(line().first.key, 'paper:mot');
    });

    test('then the one that needs starting', () {
      expect(line()[1].key, 'paper:pp');
    });

    test('and the direct debit comes after both, despite being sooner', () {
      expect(keys(line()).indexOf('sub:nflx'), greaterThan(1));
    });

    /*
      Which is only interesting because it IS sooner. If the ranking were
      chronological this assertion would be the other way round.
    */
    test('the inspection is further from today than Netflix is', () {
      final l = line();
      final nflx = l.firstWhere((e) => e.key == 'sub:nflx');
      final mot = l.firstWhere((e) => e.key == 'paper:mot');
      expect(mot.days, -38);
      expect(nflx.days, 5);
      expect(mot.days.abs(), greaterThan(nflx.days));
    });

    test('and the fixtures really are the ages they claim', () {
      final l = line();
      // 24 months from 6 Sep 2024. If this drifts, every bucket above it is
      // being asserted against a warranty that is not where the comment says.
      expect(l.firstWhere((e) => e.key == 'item:Headphones').days, 20);
      expect(l.firstWhere((e) => e.key == 'paper:pp').days, -62);
    });
  });

  group('flagging', () {
    test('overdue and needs-starting are flagged, an ordinary renewal is not',
        () {
      final l = buildTimeline(
        [],
        [sub(id: 'nflx')],
        [
          paper(id: 'mot', expiresOn: '2026-07-10'),
          paper(id: 'pp', expiresOn: '2027-02-11'),
        ],
        now,
      );
      expect(l.where((e) => e.flagged).map((e) => e.key).toSet(),
          {'paper:mot', 'paper:pp'});
      expect(flaggedCount(l), 2);
    });

    /*
      A reminder is the only thing that lifts a renewal out of the ordinary run
      of them, and it does it by moving the row rather than by adding a second
      card higher up the page.
    */
    test('a reminder due promotes the row and flags it', () {
      final l = buildTimeline([], [sub(id: 'r', remindDays: 7)], [], now);
      expect(l.first.urgency, Urgency.now);
      expect(l.first.flagged, isTrue);
    });

    test('a reminder not yet due does neither', () {
      // Renews in 5 days; the reminder asks for 1.
      final l = buildTimeline([], [sub(id: 'q', remindDays: 1)], [], now);
      expect(l.first.urgency, isNot(Urgency.now));
      expect(l.first.flagged, isFalse);
    });

    test('and no reminder at all is the default', () {
      expect(buildTimeline([], [sub()], [], now).first.flagged, isFalse);
    });
  });

  group('the right-hand column', () {
    test('an overdue row says how late', () {
      expect(whenLabel(Urgency.overdue, -38), '38 days late');
    });

    test('a countdown counts',
        () => expect(whenLabel(Urgency.soon, 5), '5 days'));

    test('and a far one gets its comma', () {
      // A passport five years out. Four bare digits read as a serial number,
      // on a screen where the money beside them is grouped.
      expect(whenLabel(Urgency.later, 1804), '1,804 days');
    });
    test('one day is named',
        () => expect(whenLabel(Urgency.soon, 1), 'tomorrow'));
    test('and today is', () => expect(whenLabel(Urgency.soon, 0), 'today'));

    /*
      THE ONE A REALISTIC LIST CAUGHT. A passport inside its lead time passed
      its renew-by months ago, so `days` is a large negative number — and the
      obvious `days <= 0 ? 'today'` printed "today" beside a document that
      needed starting in June. "62 days late" is no better: the passport does
      not expire until February, so nothing is actually late. The window is
      open, which is a state and not a duration.
    */
    test('a wide-open window is not a countdown', () {
      expect(whenLabel(Urgency.now, -62), 'now');
      expect(whenLabel(Urgency.now, 0), 'now');
    });

    /*
      ── Two forms of one answer ───────────────────────────────────────────

      The dashboard sets the number large and the unit small, which needs them
      apart — a column of "14 days" at one size is a column of phrases, and
      the whole point of it is being compared down the page at a glance.

      Split in the logic rather than in the widget so they cannot drift.
      Anything `whenParts` says has to reassemble into what `whenLabel` says,
      which is what this checks rather than checking each in isolation.
    */
    test('whenParts reassembles into whenLabel', () {
      const cases = [
        (Urgency.overdue, -38),
        (Urgency.overdue, -1),
        (Urgency.now, -62),
        (Urgency.soon, 0),
        (Urgency.soon, 1),
        (Urgency.soon, 5),
        (Urgency.later, 90),
      ];

      for (final (urgency, days) in cases) {
        final (big, unit) = whenParts(urgency, days);
        final joined = unit == null ? big : '$big $unit';
        expect(joined, whenLabel(urgency, days), reason: '$urgency $days');
      }
    });

    /*
      The wordy cases have no number, and must not pretend to. "now" is a
      state rather than a duration — see the note on `whenLabel` — and setting
      it in 21pt digits would be inventing a measurement.
    */
    test('and the wordy answers carry no unit', () {
      expect(whenParts(Urgency.now, -62).$2, isNull);
      expect(whenParts(Urgency.soon, 0).$2, isNull);
      expect(whenParts(Urgency.soon, 1).$2, isNull);
    });

    test('one day late is singular', () {
      expect(whenParts(Urgency.overdue, -1), ('1', 'day late'));
    });

    test('and a real passport takes that path', () {
      final l = buildTimeline([], [], [paper(id: 'w', holder: 'Nuno')], now);
      expect(l.first.days, lessThan(0),
          reason: 'the renew-by really has passed');
      expect(whenLabelFor(l.first), 'now');
    });
  });

  group('what is left out', () {
    /*
      A lapsed warranty is not an action. The cover is gone and the item is
      still yours; putting every one at the top would bury the things that are
      still saveable under the things that aren't. A lapsed PASSPORT is a
      problem you still have to solve, so that one does appear — the asymmetry
      is the point.
    */
    test('a lapsed warranty is not in the list', () {
      expect(buildTimeline([warranted('Old kettle', 12, 900)], [], [], now),
          isEmpty);
    });

    test('but a lapsed document is', () {
      final l =
          buildTimeline([], [], [paper(id: 'x', expiresOn: '2026-01-01')], now);
      expect(l.length, 1);
      expect(l.first.urgency, Urgency.overdue);
    });

    test('cover that runs for years is not news', () {
      expect(
          buildTimeline([warranted('Fridge', 60, 30)], [], [], now), isEmpty);
    });

    test('a renewal past the horizon is out', () {
      final far = sub(cadence: Cadence.yearly, anchorDate: '2027-06-01');
      expect(buildTimeline([], [far], [], now), isEmpty);
    });

    test('so is a document with years of runway', () {
      final far = paper(kind: PaperKind.insurance, expiresOn: '2028-06-01');
      expect(buildTimeline([], [], [far], now), isEmpty);
    });

    // An unreadable date can't be placed on a timeline, and inventing a
    // position for it would put it somewhere confident and wrong.
    test('a document with no date is skipped', () {
      expect(buildTimeline([], [], [paper(expiresOn: '')], now), isEmpty);
    });
  });

  group('naming', () {
    test('a document says whose it is', () {
      final l = buildTimeline([], [], [paper(holder: 'Nuno')], now);
      expect(l.first.title, 'Passport — Nuno');
    });

    test('and drops the dash when nobody is named', () {
      final l =
          buildTimeline([], [], [paper(id: 'n', expiresOn: '2026-09-01')], now);
      expect(l.first.title, 'Passport');
    });

    test('a blank holder is nobody', () {
      expect(buildTimeline([], [], [paper(holder: '  ')], now).first.title,
          'Passport');
    });
  });

  group('the second line', () {
    /*
      Fixed American formatting, not the browser locale the TypeScript defers
      to. See the note on `dayMonth` — a hand-rolled month table pretending to
      be locale-aware would be worse than one honest format.
    */
    test('a renewal names its date', () {
      expect(buildTimeline([], [sub()], [], now).first.detail, 'Renews Aug 22');
    });

    test('an expired document says when it went', () {
      final l = buildTimeline([], [], [paper(expiresOn: '2026-07-10')], now);
      expect(l.first.detail, 'Expired Jul 10');
    });

    test('one inside its window says to start, and when it runs out', () {
      final l = buildTimeline([], [], [paper()], now);
      expect(l.first.detail, 'Start now · expires Feb 11');
    });

    test('and one still ahead names the day to begin', () {
      // Expires 1 Sep 2027, 240 days of runway → start 4 Jan 2027.
      final l = buildTimeline([], [], [paper(expiresOn: '2027-09-01')], now);
      expect(l, isEmpty, reason: 'still beyond the 30-day horizon');
      final soon = buildTimeline(
        [],
        [],
        [paper(expiresOn: '2027-04-20')], // start 23 Aug 2026, six days out
        now,
      );
      expect(soon.first.detail, 'Start Aug 23');
      expect(soon.first.urgency, Urgency.soon);
      expect(soon.first.flagged, isFalse);
    });
  });

  group('stability', () {
    /*
      Two entries in the same bucket on the same day must not swap places
      between renders. A list that reorders itself while you look at it reads
      as broken.
    */
    test('ties break alphabetically', () {
      final tied = buildTimeline(
        [],
        [sub(id: 'b', name: 'Bravo'), sub(id: 'a', name: 'Alpha')],
        [],
        now,
      );
      expect(tied.map((e) => e.title), ['Alpha', 'Bravo']);
    });

    test('and sorting is idempotent', () {
      final tied = buildTimeline(
        [],
        [sub(id: 'b', name: 'Bravo'), sub(id: 'a', name: 'Alpha')],
        [],
        now,
      );
      expect(keys(sortTimeline(sortTimeline(tied))), keys(tied));
    });

    test('sorting leaves the original list alone', () {
      final one = Entry(
        key: 'z',
        kind: TimelineKind.item,
        id: 'z',
        title: 'Zulu',
        detail: '',
        urgency: Urgency.later,
        days: 9,
        flagged: false,
      );
      final two = Entry(
        key: 'a',
        kind: TimelineKind.item,
        id: 'a',
        title: 'Alpha',
        detail: '',
        urgency: Urgency.overdue,
        days: -1,
        flagged: true,
      );
      final list = [one, two];
      sortTimeline(list);
      expect(keys(list), ['z', 'a']);
    });
  });

  group('the ring', () {
    /*
      SUBSCRIPTIONS ARE NOT IN THE RING, and the signature is the proof — it
      does not take them. A subscription cannot lapse: it renews, and renews
      again. Counting nine as nine healthy units would make the score rise when
      you take on a service and fall when you cancel one, which is backwards.
    */
    DatedTally tally() => datedTally(
          [
            warranted('Fridge', 60, 30), // covered
            warranted('Headphones', 24, 710), // ending soon
            warranted('Old kettle', 12, 900), // lapsed
            item(id: 'blank', name: 'Lamp'), // no term at all
          ],
          [
            paper(id: 'ok', expiresOn: '2031-01-01'),
            paper(id: 'due', expiresOn: '2026-10-01'),
            paper(id: 'gone', expiresOn: '2026-01-01'),
            paper(id: 'nodate', expiresOn: ''),
          ],
          now,
        );

    test('in date counts both kinds', () => expect(tally().inDate, 2));
    test('so does needs-starting', () => expect(tally().needsStarting, 2));
    test('and lapsed', () => expect(tally().lapsed, 2));
    test('undated records are counted separately',
        () => expect(tally().noDate, 2));

    /*
      The divisor is the tracked three, not everything. Including blanks would
      mean the score DROPS when you add a record with a date missing —
      punishing the one behaviour the app is trying to encourage — and the
      green wedge would stop matching the headline number.
    */
    test('the percentage divides by what is tracked', () {
      expect(tally().percent, 33);
    });

    test('adding an undated record cannot lower the score', () {
      final before = datedTally([warranted('Fridge', 60, 30)], [], now).percent;
      final after = datedTally(
        [warranted('Fridge', 60, 30), item(id: 'z', name: 'Lamp')],
        [],
        now,
      ).percent;
      expect(after, before);
    });

    test('nothing tracked is zero, not a divide by zero', () {
      expect(datedTally([], [], now).percent, 0);
    });

    test('and it reports the raw counts too', () {
      expect(tally().items, 4);
      expect(tally().papers, 4);
    });
  });

  group('where a chip should go', () {
    /*
      THE BUG THIS EXISTS FOR. Every chip under the ring opened the items list
      with a filter, and both counts span two kinds. A house whose "action
      needed" is two passports tapped an accurate number and landed on an empty
      items screen — the count was right, the destination was wrong, and the
      app looked as though it had mislaid them.
    */
    test('the splits add back up', () {
      final t = datedTally(
        [
          warranted('Headphones', 24, 710),
          warranted('Old kettle', 12, 900),
          item(id: 'b')
        ],
        [
          paper(id: 'due', expiresOn: '2026-10-01'),
          paper(id: 'nodate', expiresOn: '')
        ],
        now,
      );
      expect(t.needsStartingBy.total, t.needsStarting);
      expect(t.lapsedBy.total, t.lapsed);
      expect(t.noDateBy.total, t.noDate);
    });

    test('a documents-only count goes to documents', () {
      final t =
          datedTally([], [paper(id: 'due', expiresOn: '2026-10-01')], now);
      expect(destinationFor(t.needsStartingBy), Destination.papers);
    });

    test('an items-only count goes to items', () {
      final t = datedTally([warranted('Kettle', 12, 350)], [], now);
      expect(destinationFor(t.needsStartingBy), Destination.items);
    });

    // Mixed goes to items: the bigger list, and documents already sort anything
    // needing action to their own top.
    test('a mixed count goes to items', () {
      final t = datedTally(
        [warranted('Headphones', 24, 710)],
        [paper(id: 'due', expiresOn: '2026-10-01')],
        now,
      );
      expect(t.needsStartingBy.items, 1);
      expect(t.needsStartingBy.papers, 1);
      expect(destinationFor(t.needsStartingBy), Destination.items);
    });

    // The one that used to send you somewhere empty and now sends you nowhere.
    test('nothing to show means no destination', () {
      expect(destinationFor(const KindSplit(0, 0)), isNull);
    });
  });
  group('the year, when the year is news', () {
    final thisYear = DateTime(2026, 6, 1);

    test('is left off for something running out this year', () {
      expect(dayMonthMaybeYear(DateTime(2026, 4, 3), thisYear), 'Apr 3');
      expect(dayMonthMaybeYear(DateTime(2026, 12, 31), thisYear), 'Dec 31');
    });

    /*
      A passport is the case this exists for. "Expires Apr 3" on a document
      that runs out in 2031 is not merely incomplete — the reader supplies
      "this year", because that is what every other date on the screen means.
    */
    test('and shown for anything that is not', () {
      expect(dayMonthMaybeYear(DateTime(2031, 4, 3), thisYear), 'Apr 3, 2031');
      expect(
          dayMonthMaybeYear(DateTime(2024, 9, 16), thisYear), 'Sep 16, 2024');
    });

    // Not "within twelve months" — the calendar year. December 31st and
    // January 1st are one day apart and read completely differently, which is
    // the whole reason a year is worth printing.
    test('the boundary is the calendar, not twelve months', () {
      expect(dayMonthMaybeYear(DateTime(2027, 1, 1), DateTime(2026, 12, 31)),
          'Jan 1, 2027');
    });
  });
}
