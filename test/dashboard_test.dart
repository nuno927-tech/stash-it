/// Dashboard figures.
///
///   dart test test/dashboard_test.dart
///
/// Translated from `test/gaps.test.ts` and the metrics half of the dashboard
/// suite. Every figure here answers a question someone would actually ask
/// about their own things, so the assertions are about meaning rather than
/// arithmetic: which items count as covered, which count as missing proof, and
/// which problem gets listed first.
library;

import 'package:stash_it/logic/dashboard.dart';
import 'package:stash_it/logic/dates.dart';
import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/models/types.dart';
import 'package:test/test.dart';

final now = DateTime(2026, 8, 17);

Item item(
  String id, {
  int? months,
  int ago = 30,
  int? priceCents,
  String? currency,
  String? thumbBlobId,
  bool dated = true,
  DateTime? createdAt,
  DateTime? deletedAt,
}) =>
    Item(
      id: id,
      name: id,
      propertyId: 'p',
      purchaseDate: dated ? toIsoDate(addDays(now, -ago)) : null,
      warranty: months == null
          ? null
          : Warranty(months: months, unit: WarrantyUnit.months, amount: months),
      purchasePriceCents: priceCents,
      currency: currency,
      thumbBlobId: thumbBlobId,
      createdAt: createdAt,
      deletedAt: deletedAt,
    );

Doc doc(String id, String itemId, DocKind kind, {DateTime? deletedAt}) =>
    Doc(id: id, itemId: itemId, kind: kind, deletedAt: deletedAt);

void main() {
  setUp(() => setEndingSoonDays(30));
  tearDown(() => setEndingSoonDays(defaultEndingSoonDays));

  group('the counts', () {
    Metrics run() => metricsFor(
          [
            item('Fridge', months: 60), // covered
            item('Headphones', months: 24, ago: 710), // 20 days left
            item('Kettle', months: 12, ago: 900), // lapsed
            item('Lamp'), // no term at all
            item('Gone', months: 12, deletedAt: now), // in the bin
          ],
          [],
          now,
        );

    test('the bin is not counted', () => expect(run().total, 4));
    test('covered', () => expect(run().covered, 1));
    test('ending soon', () => expect(run().endingSoon, 1));
    test('lapsed', () => expect(run().expired, 1));
    test('and an item with no term is untracked, not expired', () {
      expect(run().untracked, 1);
    });

    test('the four states account for everything live', () {
      final m = run();
      expect(m.covered + m.endingSoon + m.expired + m.untracked, m.total);
    });

    test('the cover bar leaves untracked items out of the divisor', () {
      // Otherwise the score drops when you add a record with a date missing,
      // which punishes the one behaviour the app wants.
      final m = run();
      expect(coverShare(m), closeTo(2 / 3, 0.001));
    });

    test('nothing tracked is zero, not a divide by zero', () {
      expect(coverShare(metricsFor([], [], now)), 0);
    });
  });

  group('what lapses next', () {
    test('the soonest still-running policy wins', () {
      final m = metricsFor(
        [
          item('Later', months: 60),
          item('Sooner', months: 24, ago: 690),
        ],
        [],
        now,
      );
      expect(m.nextToExpire!.item.id, 'Sooner');
      expect(m.nextToExpire!.days, 40);
    });

    test('something already lapsed is not "next"', () {
      final m = metricsFor([item('Kettle', months: 12, ago: 900)], [], now);
      expect(m.nextToExpire, isNull);
    });

    test('and nothing at all is null', () {
      expect(metricsFor([item('Lamp')], [], now).nextToExpire, isNull);
    });
  });

  group('proof', () {
    /*
      A receipt or a warranty document is what a claim asks for. A manual is
      useful and is not evidence — counting it would tell somebody they are
      covered on the strength of a PDF nobody will ever ask to see.
    */
    test('a receipt counts as proof', () {
      final m = metricsFor(
        [item('A'), item('B')],
        [doc('d1', 'A', DocKind.receipt)],
        now,
      );
      expect(m.missingPaperwork, 1);
    });

    test('so does a warranty document', () {
      final m = metricsFor([item('A')], [doc('d1', 'A', DocKind.warranty)], now);
      expect(m.missingPaperwork, 0);
    });

    test('a manual does not', () {
      final m = metricsFor([item('A')], [doc('d1', 'A', DocKind.manual)], now);
      expect(m.missingPaperwork, 1);
    });

    test('nor does a deleted receipt', () {
      final m = metricsFor(
        [item('A')],
        [doc('d1', 'A', DocKind.receipt, deletedAt: now)],
        now,
      );
      expect(m.missingPaperwork, 1);
      expect(m.documents, 0);
    });
  });

  group('what it is worth', () {
    /*
      Never converted. An offline app has no exchange rates, and inventing one
      would produce a total that is confidently wrong and impossible to check.
    */
    test('totals are per currency, largest first', () {
      final totals = valueByCurrency([
        item('a', priceCents: 5000, currency: 'USD'),
        item('b', priceCents: 30000, currency: 'EUR'),
        item('c', priceCents: 1000, currency: 'USD'),
      ]);
      expect(totals.map((t) => t.currency), ['EUR', 'USD']);
      expect(totals.first.cents, 30000);
      expect(totals.last.cents, 6000);
    });

    test('a missing currency is assumed to be dollars', () {
      final totals = valueByCurrency([item('a', priceCents: 100)]);
      expect(totals.single.currency, 'USD');
    });

    test('items with no price are not zero, they are absent', () {
      expect(valueByCurrency([item('a')]), isEmpty);
    });

    test('and the bin does not count', () {
      final totals = valueByCurrency([
        item('a', priceCents: 100, deletedAt: now),
      ]);
      expect(totals, isEmpty);
    });

    test('the metrics use the same sum as the items list', () {
      final rows = [item('a', priceCents: 5000, currency: 'USD')];
      expect(
        metricsFor(rows, [], now).valueByCurrency.single.cents,
        valueByCurrency(rows).single.cents,
      );
    });
  });

  group('the short form', () {
    test('small amounts are exact', () {
      expect(shortMoney(const CurrencyTotal('USD', 499900)), r'$4,999');
    });

    test('large ones abbreviate', () {
      expect(shortMoney(const CurrencyTotal('USD', 1240000)), r'$12.4K');
    });

    test('and drop a trailing zero', () {
      expect(shortMoney(const CurrencyTotal('USD', 1200000)), r'$12K');
    });

    test('millions too', () {
      expect(shortMoney(const CurrencyTotal('USD', 250000000)), r'$2.5M');
    });

    test('an unknown currency falls back to its code', () {
      expect(shortMoney(const CurrencyTotal('XYZ', 10000)), 'XYZ100');
    });
  });

  group('the recently added', () {
    test('newest first, three at most', () {
      final m = metricsFor(
        [
          item('old', createdAt: DateTime(2026, 1, 1)),
          item('newest', createdAt: DateTime(2026, 8, 1)),
          item('middle', createdAt: DateTime(2026, 5, 1)),
          item('oldest', createdAt: DateTime(2025, 1, 1)),
        ],
        [],
        now,
      );
      expect(m.recent.map((i) => i.id), ['newest', 'middle', 'old']);
    });

    test('an item with no timestamp sinks rather than claiming to be newest', () {
      final m = metricsFor(
        [item('undated'), item('dated', createdAt: DateTime(2020, 1, 1))],
        [],
        now,
      );
      expect(m.recent.first.id, 'dated');
    });
  });

  group('the gaps', () {
    /*
      ORDERED BY WHAT IT COSTS YOU, NOT BY HOW MANY. A receipt is the one thing
      a claim will actually ask for and the one thing you cannot recreate later
      — a shop will not reissue a receipt from 2023. A photo you can take this
      afternoon. Sorting by count would put the cheap problem at the top on
      most people's data.
    */
    test('a single missing receipt outranks nine missing photos', () {
      // Nine items with receipts and terms and dates, missing only a photo.
      final rows = [
        for (var i = 0; i < 9; i++) item('photoless$i', months: 24),
        item('receiptless', months: 24, thumbBlobId: 'b'),
      ];
      final receipts = [
        for (var i = 0; i < 9; i++) doc('d$i', 'photoless$i', DocKind.receipt),
      ];

      final gaps = gapsFor(rows, receipts);

      expect(gaps.map((g) => g.kind), [GapKind.receipt, GapKind.photo]);
      expect(gaps.first.count, 1);
      expect(gaps.last.count, 9);
    });

    test('and the full order is the ranking, not the tally', () {
      final gaps = gapsFor([item('bare', dated: false)], const []);
      expect(gaps.map((g) => g.kind), gapOrder);
    });

    test('a gap with a count of zero is not listed', () {
      final rows = [item('all-good', months: 24, thumbBlobId: 'b')];
      final kinds = gapsFor(rows, [doc('d', 'all-good', DocKind.receipt)])
          .map((g) => g.kind);
      expect(kinds, isNot(contains(GapKind.receipt)));
      expect(kinds, isNot(contains(GapKind.warranty)));
      expect(kinds, isNot(contains(GapKind.date)));
      expect(kinds, isNot(contains(GapKind.photo)));
    });

    test('a tidy collection has no gaps at all', () {
      final rows = [item('fine', months: 24, thumbBlobId: 'b')];
      expect(gapsFor(rows, [doc('d', 'fine', DocKind.receipt)]), isEmpty);
    });

    /*
      Warranty *length*, not the document. An item can have the paperwork
      attached and still no term entered — and it is the term that drives every
      countdown and every warning in the app.
    */
    test('a warranty document is not a warranty length', () {
      final rows = [item('papered', thumbBlobId: 'b')];
      final gaps = gapsFor(rows, [
        doc('d1', 'papered', DocKind.receipt),
        doc('d2', 'papered', DocKind.warranty),
      ]);
      expect(gaps.map((g) => g.kind), [GapKind.warranty]);
    });

    // "No warranty length" is the wrong thing to nag someone about on a couch
    // whose frame is covered forever.
    test('a lifetime policy is a warranty length', () {
      final couch = Item(
        id: 'couch',
        name: 'Couch',
        propertyId: 'p',
        purchaseDate: '2026-01-01',
        thumbBlobId: 'b',
        coverages: const [
          Coverage(id: 'frame', label: 'Frame', unit: CoverageUnit.lifetime, amount: 0),
        ],
      );
      final gaps = gapsFor([couch], [doc('d', 'couch', DocKind.receipt)]);
      expect(gaps, isEmpty);
    });

    test('one reads singular, several do not', () {
      final one = gapsFor([item('a', months: 24, thumbBlobId: 'b')], const []);
      expect(one.single.label, '1 item has no receipt');

      final two = gapsFor([
        item('a', months: 24, thumbBlobId: 'b'),
        item('b', months: 24, thumbBlobId: 'b'),
      ], const []);
      expect(two.single.label, '2 items have no receipt');
    });

    test('and every gap explains why it matters', () {
      for (final g in gapsFor([item('bare', dated: false)], const [])) {
        expect(g.why, isNotEmpty, reason: '${g.kind}');
        expect(g.why.length, greaterThan(30), reason: '${g.kind}');
      }
    });

    test('the bin is not nagged about', () {
      expect(gapsFor([item('gone', deletedAt: now)], const []), isEmpty);
    });
  });
}
