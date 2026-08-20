/// Calendar arithmetic.
///
///   dart test test/dates_test.dart
///
/// Translated from the date assertions in `test/subs.test.ts` and
/// `test/units.test.ts`. Most of these exist because something shipped wrong
/// once — read the failures as history rather than as pedantry.
///
/// ── The clock changes are the point ───────────────────────────────────────
/// The TypeScript suite pins the timezone with `process.env.TZ` so the DST
/// cases are real rather than dependent on whoever runs them. Dart has no
/// equivalent: `DateTime` uses the host zone and it cannot be overridden from
/// inside the test.
///
/// So the DST cases below are written to be *correct everywhere* — they assert
/// the calendar answer, which holds in every zone — and the specifically
/// American transitions are marked. Run them at least once with the machine
/// set to America/New_York, which is what the TypeScript suite pins.
library;

import 'package:stash_it/logic/dates.dart';
import 'package:test/test.dart';

void main() {
  group('startOfDay', () {
    test('drops the time', () {
      expect(startOfDay(DateTime(2026, 8, 17, 14, 30)), DateTime(2026, 8, 17));
    });

    test('and leaves a date alone', () {
      expect(startOfDay(DateTime(2026, 8, 17)), DateTime(2026, 8, 17));
    });
  });

  group('addDays', () {
    test('adds a day', () {
      expect(addDays(DateTime(2026, 8, 17), 1), DateTime(2026, 8, 18));
    });

    test('crosses a month', () {
      expect(addDays(DateTime(2026, 8, 31), 1), DateTime(2026, 9, 1));
    });

    test('crosses a year', () {
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    });

    test('goes backwards', () {
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });

    test('handles a leap day', () {
      expect(addDays(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
    });

    /*
      THE ONE THAT COST MONEY. In the JavaScript version this was
      `getTime() + 86400000`, and on the morning the clocks went back it landed
      at 23:00 the SAME day — so a weekly subscription anchored on a Monday
      renewed on Sundays for the whole winter, and a cursor loop stopped
      advancing and ran to its guard.

      `DateTime.add(Duration(days: 1))` is the identical bug in Dart. These two
      assertions fail if anyone ever writes it that way.
    */
    test('crosses the autumn clock change and lands on the next day', () {
      // 1 November 2026 is the US fall-back. The calendar answer is the 2nd.
      expect(addDays(DateTime(2026, 11, 1), 1), DateTime(2026, 11, 2));
    });

    test('and the spring one', () {
      // 8 March 2026 is the US spring-forward.
      expect(addDays(DateTime(2026, 3, 8), 1), DateTime(2026, 3, 9));
    });

    test('a week across the change is still seven calendar days', () {
      expect(addDays(DateTime(2026, 10, 29), 7), DateTime(2026, 11, 5));
    });
  });

  group('daysBetween', () {
    test('counts whole days', () {
      expect(daysBetween(DateTime(2026, 8, 17), DateTime(2026, 8, 24)), 7);
    });

    test('is negative backwards', () {
      expect(daysBetween(DateTime(2026, 8, 24), DateTime(2026, 8, 17)), -7);
    });

    test('is zero for the same day', () {
      expect(daysBetween(DateTime(2026, 8, 17), DateTime(2026, 8, 17)), 0);
    });

    /*
      `difference().inDays` would truncate here. Across the fall-back the gap
      between two local midnights is 25 hours, which floors to 1 — right by
      luck. Across the spring-forward it is 23 hours, which floors to 0 — a
      countdown that skips a day, once a year, silently.
    */
    test('one day across the spring change is one day, not zero', () {
      expect(daysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 1);
    });

    test('and one across the autumn change is one, not two', () {
      expect(daysBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 2)), 1);
    });

    test('a year is 365 days', () {
      expect(daysBetween(DateTime(2026, 1, 1), DateTime(2027, 1, 1)), 365);
    });

    test('and a leap year is 366', () {
      expect(daysBetween(DateTime(2028, 1, 1), DateTime(2029, 1, 1)), 366);
    });
  });

  group('daysUntil', () {
    test('ignores the time of day at both ends', () {
      final now = DateTime(2026, 8, 17, 23, 55);
      expect(daysUntil(DateTime(2026, 8, 18, 0, 5), now), 1);
    });

    test('today is zero', () {
      expect(daysUntil(DateTime(2026, 8, 17, 6), DateTime(2026, 8, 17, 22)), 0);
    });

    test('and yesterday is negative', () {
      expect(daysUntil(DateTime(2026, 8, 16), DateTime(2026, 8, 17)), -1);
    });
  });

  group('addMonthsClamped', () {
    test('adds a month', () {
      expect(addMonthsClamped(DateTime(2026, 1, 15), 1), DateTime(2026, 2, 15));
    });

    /*
      A subscription anchored on the 31st renews on the 30th in April and the
      28th in February — what the card issuer does. Rolling into the 1st of the
      next month puts the renewal in the wrong month and shifts every date
      after it.
    */
    test('clamps the 31st into February', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('and into a leap February', () {
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('and into a 30-day month', () {
      expect(addMonthsClamped(DateTime(2026, 3, 31), 1), DateTime(2026, 4, 30));
    });

    /*
      The clamp must not be sticky. Stepping from the ORIGINAL anchor each time
      is what brings the 31st back in March; stepping from the previous result
      would leave it on the 28th forever.
    */
    test('two months from the 31st comes back to the 31st', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
    });

    test('crosses a year', () {
      expect(addMonthsClamped(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
    });

    test('goes backwards', () {
      expect(addMonthsClamped(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 15));
    });

    test('twelve months is a year', () {
      expect(addMonthsClamped(DateTime(2026, 6, 10), 12), DateTime(2027, 6, 10));
    });
  });

  group('parseDate', () {
    test('reads a calendar date', () {
      expect(parseDate('2026-08-17'), DateTime(2026, 8, 17));
    });

    test('is local midnight, not UTC', () {
      expect(parseDate('2026-08-17')!.hour, 0);
    });

    /*
      Both `DateTime.parse` and the constructor roll 31 February forward into
      March without complaint, which turns a typo into a date the user never
      chose and a countdown to a day that means nothing.
    */
    test('rejects a date that does not exist', () {
      expect(parseDate('2026-02-31'), isNull);
    });

    test('rejects month thirteen', () {
      expect(parseDate('2026-13-01'), isNull);
    });

    test('rejects a malformed string', () {
      expect(parseDate('17/08/2026'), isNull);
    });

    test('rejects an empty one', () {
      expect(parseDate(''), isNull);
    });

    test('tolerates surrounding space', () {
      expect(parseDate('  2026-08-17 '), DateTime(2026, 8, 17));
    });

    test('accepts a real leap day', () {
      expect(parseDate('2028-02-29'), DateTime(2028, 2, 29));
    });

    test('and rejects a fake one', () {
      expect(parseDate('2026-02-29'), isNull);
    });
  });

  group('toIsoDate', () {
    test('pads the parts', () {
      expect(toIsoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('round-trips', () {
      expect(toIsoDate(parseDate('2026-11-01')!), '2026-11-01');
    });
  });
}
