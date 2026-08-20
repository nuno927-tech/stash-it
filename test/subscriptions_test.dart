/// Renewal dates and what they cost.
///
///   dart test test/subscriptions_test.dart
///
/// Translated from `test/subs.test.ts`. Every assertion about a clamped month
/// or a clock change is here because the JavaScript got it wrong first.
library;

import 'package:stash_it/logic/subscriptions.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:test/test.dart';

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

void main() {
  group('nextRenewal', () {
    test('an anchor in the future is the answer', () {
      final at = nextRenewal(sub(anchorDate: '2026-09-01'), DateTime(2026, 8, 17));
      expect(at, DateTime(2026, 9, 1));
    });

    test('today counts as due, not passed', () {
      final at = nextRenewal(sub(anchorDate: '2026-08-17'), DateTime(2026, 8, 17));
      expect(at, DateTime(2026, 8, 17));
    });

    test('a monthly plan steps to the next month', () {
      final at = nextRenewal(sub(anchorDate: '2026-01-10'), DateTime(2026, 8, 17));
      expect(at, DateTime(2026, 9, 10));
    });

    test('a quarterly plan steps three', () {
      final at = nextRenewal(
        sub(cadence: Cadence.quarterly, anchorDate: '2026-01-10'),
        DateTime(2026, 8, 17),
      );
      expect(at, DateTime(2026, 10, 10));
    });

    test('a yearly plan steps a year', () {
      final at = nextRenewal(
        sub(cadence: Cadence.yearly, anchorDate: '2026-03-01'),
        DateTime(2026, 8, 17),
      );
      expect(at, DateTime(2027, 3, 1));
    });

    /*
      THE CLAMP, AND THE RECOVERY FROM IT. An anchor on the 31st visits the
      28th in February and must come back to the 31st in March. That only works
      because every step is taken from the ORIGINAL anchor — stepping from the
      previous result would leave it stuck on the 28th for the rest of time.
    */
    test('the 31st clamps into February', () {
      final at = nextRenewal(sub(anchorDate: '2026-01-31'), DateTime(2026, 2, 5));
      expect(at, DateTime(2026, 2, 28));
    });

    test('and comes back to the 31st in March', () {
      final at = nextRenewal(sub(anchorDate: '2026-01-31'), DateTime(2026, 3, 1));
      expect(at, DateTime(2026, 3, 31));
    });

    test('and to the 30th in April', () {
      final at = nextRenewal(sub(anchorDate: '2026-01-31'), DateTime(2026, 4, 1));
      expect(at, DateTime(2026, 4, 30));
    });

    /*
      Weekly is stepped by the calendar, not by milliseconds. Done the other
      way, every weekly renewal moved a day earlier for the winter half of the
      year — a Monday plan renewing on Sundays, silently, from November.
    */
    test('a weekly plan lands on the same weekday', () {
      final at = nextRenewal(
        sub(cadence: Cadence.weekly, anchorDate: '2026-08-03'),
        DateTime(2026, 8, 17),
      );
      expect(at, DateTime(2026, 8, 17));
      expect(at!.weekday, DateTime.monday);
    });

    test('and still does across the autumn clock change', () {
      // 26 October 2026 is a Monday; 1 November is the US fall-back.
      final at = nextRenewal(
        sub(cadence: Cadence.weekly, anchorDate: '2026-10-26'),
        DateTime(2026, 11, 3),
      );
      expect(at, DateTime(2026, 11, 9));
      expect(at!.weekday, DateTime.monday);
    });

    test('an unreadable anchor is null rather than a throw', () {
      expect(nextRenewal(sub(anchorDate: 'soon'), DateTime(2026, 8, 17)), isNull);
      expect(nextRenewal(sub(anchorDate: '2026-02-31'), DateTime(2026, 8, 17)), isNull);
    });
  });

  group('daysUntilRenewal', () {
    test('counts the days', () {
      expect(daysUntilRenewal(sub(anchorDate: '2026-08-22'), DateTime(2026, 8, 17)), 5);
    });

    test('today is zero', () {
      expect(daysUntilRenewal(sub(anchorDate: '2026-08-17'), DateTime(2026, 8, 17)), 0);
    });
  });

  group('what it costs', () {
    test('a monthly plan is itself', () {
      expect(monthlyCents(sub(amountCents: 1549)), 1549);
    });

    test('a yearly plan is a twelfth', () {
      expect(monthlyCents(sub(cadence: Cadence.yearly, amountCents: 12000)), 1000);
    });

    test('a quarterly plan is a third', () {
      expect(monthlyCents(sub(cadence: Cadence.quarterly, amountCents: 3000)), 1000);
    });

    /*
      Weekly is 52.18 weeks a year, not four weeks a month. Four undercounts by
      about 8%, which is the kind of error that makes a total look believable
      and wrong.
    */
    test('a weekly plan is more than four times itself', () {
      expect(monthlyCents(sub(cadence: Cadence.weekly, amountCents: 1000)), 4348);
    });

    test('nonsense costs nothing rather than throwing', () {
      expect(monthlyCents(sub(amountCents: 0)), 0);
      expect(monthlyCents(sub(amountCents: -500)), 0);
    });

    test('totals add up', () {
      final all = [
        sub(id: 'a', amountCents: 1000),
        sub(id: 'b', cadence: Cadence.yearly, amountCents: 12000),
      ];
      expect(totalMonthlyCents(all), 2000);
      expect(totalYearlyCents(all), 24000);
    });

    test('the biggest is by the monthly figure, not the sticker price', () {
      final all = [
        sub(id: 'small-yearly', cadence: Cadence.yearly, amountCents: 12000),
        sub(id: 'big-monthly', amountCents: 2000),
      ];
      expect(biggest(all)!.id, 'big-monthly');
    });

    test('and nothing has no biggest', () {
      expect(biggest([]), isNull);
    });
  });

  group('what is about to happen', () {
    /*
      Real charges on real dates, not a normalised figure. A yearly plan
      renewing on the 14th belongs in this number at its FULL price, and
      contributes a twelfth of itself to the monthly total.
    */
    test('a yearly renewal counts at full price', () {
      final all = [sub(cadence: Cadence.yearly, anchorDate: '2026-08-20', amountCents: 12000)];
      final due = dueWithin(all, 7, DateTime(2026, 8, 17));
      expect(due.count, 1);
      expect(due.cents, 12000);
    });

    test('and one outside the window does not', () {
      final all = [sub(anchorDate: '2026-09-30')];
      expect(dueWithin(all, 7, DateTime(2026, 8, 17)).count, 0);
    });
  });

  group('renewalsBetween', () {
    test('a weekly plan hits four or five times in a month', () {
      final hits = renewalsBetween(
        sub(cadence: Cadence.weekly, anchorDate: '2026-08-03'),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 31),
      );
      expect(hits.length, inInclusiveRange(4, 5));
    });

    test('a monthly plan hits once', () {
      final hits = renewalsBetween(
        sub(anchorDate: '2026-08-22'),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 31),
      );
      expect(hits, [DateTime(2026, 8, 22)]);
    });

    /*
      A yearly plan returns nothing at all in eleven months of twelve. That is
      the entire point of drawing the chart.
    */
    test('a yearly plan hits in one month of twelve', () {
      final annual = sub(cadence: Cadence.yearly, anchorDate: '2026-11-14');
      expect(renewalsBetween(annual, DateTime(2026, 10, 1), DateTime(2026, 10, 31)), isEmpty);
      expect(renewalsBetween(annual, DateTime(2026, 11, 1), DateTime(2026, 11, 30)).length, 1);
    });

    test('both ends are inclusive', () {
      final hits = renewalsBetween(
        sub(anchorDate: '2026-08-01'),
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 1),
      );
      expect(hits, [DateTime(2026, 8, 1)]);
    });
  });

  group('spendByMonth', () {
    /*
      THE FINDING THE CHART EXISTS FOR. Three annual plans landing in the same
      month make that month cost several times its neighbours, and the monthly
      average says nothing about it.
    */
    test('an annual renewal makes one month heavy', () {
      final all = [
        sub(id: 'm', amountCents: 1000),
        sub(id: 'a', cadence: Cadence.yearly, anchorDate: '2026-11-14', amountCents: 12000),
      ];
      final spend = spendByMonth(all, 6, DateTime(2026, 8, 17));

      expect(spend.length, 6);
      expect(spend.first.year, 2026);
      expect(spend.first.month, 8, reason: 'months are 1-based in Dart, 0-based in the TS');

      final november = spend.firstWhere((m) => m.month == 11);
      expect(november.cents, 13000);

      final october = spend.firstWhere((m) => m.month == 10);
      expect(october.cents, 1000);

      expect(heaviest(spend)!.month, 11);
    });

    test('nothing at all has no heaviest month', () {
      expect(heaviest(spendByMonth([], 6, DateTime(2026, 8, 17))), isNull);
    });

    test('the run crosses a year end', () {
      final spend = spendByMonth([], 6, DateTime(2026, 11, 1));
      expect(spend.last.year, 2027);
      expect(spend.last.month, 4);
    });
  });

  group('dailyCents', () {
    test('a year of spend, per day', () {
      // $120/year → about 32.85 cents a day.
      final all = [sub(cadence: Cadence.yearly, amountCents: 12000)];
      expect(dailyCents(all), closeTo(32.85, 0.01));
    });

    test('nothing costs nothing', () {
      expect(dailyCents([]), 0);
    });
  });
}
