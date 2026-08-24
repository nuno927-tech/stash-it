/// Coverage, countdowns and the colour an item earns.
///
///   dart test test/warranty_test.dart
///
/// Translated from `test/coverage.test.ts` and `test/units.test.ts`. The
/// ordering assertions are the ones that carry the feature: a couch with a
/// lifetime frame and twelve months on the fabric is not "covered for life" in
/// any sense the owner cares about.
library;

import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/models/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// 17 August 2026, matching the fixture date the TypeScript suites pin.
final now = DateTime(2026, 8, 17);

Coverage cover({
  String id = 'c',
  String label = 'Warranty',
  CoverageUnit unit = CoverageUnit.years,
  int amount = 1,
  String? startsOn,
}) =>
    Coverage(id: id, label: label, unit: unit, amount: amount, startsOn: startsOn);

Item item({
  String? purchaseDate,
  List<Coverage> coverages = const [],
  Warranty? warranty,
  Warranty? extendedWarranty,
  int? leadDays,
}) =>
    Item(
      id: 'x',
      name: 'Thing',
      propertyId: 'p',
      purchaseDate: purchaseDate,
      coverages: coverages,
      warranty: warranty,
      extendedWarranty: extendedWarranty,
      leadDays: leadDays,
    );

void main() {
  setUp(() => setEndingSoonDays(defaultEndingSoonDays));
  tearDown(() => setEndingSoonDays(defaultEndingSoonDays));

  group('terms', () {
    test('a unit and amount are the source of truth', () {
      final t = termOf(const Warranty(months: 24, unit: WarrantyUnit.days, amount: 90))!;
      expect(t.unit, WarrantyUnit.days);
      expect(t.amount, 90);
    });

    /*
      Records written before units existed only have `months`, and read back as
      months — which is what they meant.
    */
    test('a legacy record reads as months', () {
      final t = termOf(const Warranty(months: 24))!;
      expect(t.unit, WarrantyUnit.months);
      expect(t.amount, 24);
    });

    test('nothing at all is nothing', () {
      expect(termOf(const Warranty(months: 0)), isNull);
      expect(termOf(null), isNull);
    });

    test('years convert to months', () {
      expect(termToMonths(const WarrantyTerm(WarrantyUnit.years, 3)), 36);
    });

    test('and days round, never to zero', () {
      expect(termToMonths(const WarrantyTerm(WarrantyUnit.days, 90)), 3);
      expect(termToMonths(const WarrantyTerm(WarrantyUnit.days, 1)), 1);
    });
  });

  group('when a policy ends', () {
    test('days are exact', () {
      final end = coverageEnd(cover(unit: CoverageUnit.days, amount: 90), '2026-01-01');
      expect(end, DateTime(2026, 4, 1));
    });

    /*
      Calendar months, not 30-day counts. A 24-month warranty bought on 31
      January ends on 31 January, and passing through February must not shift
      it permanently.
    */
    test('months are calendar months', () {
      final end = coverageEnd(cover(unit: CoverageUnit.months, amount: 24), '2026-01-31');
      expect(end, DateTime(2028, 1, 31));
    });

    test('and clamp into a short month', () {
      final end = coverageEnd(cover(unit: CoverageUnit.months, amount: 1), '2026-01-31');
      expect(end, DateTime(2026, 2, 28));
    });

    test('years are twelve months each', () {
      final end = coverageEnd(cover(unit: CoverageUnit.years, amount: 2), '2026-08-17');
      expect(end, DateTime(2028, 8, 17));
    });

    test('lifetime never ends', () {
      expect(coverageEnd(cover(unit: CoverageUnit.lifetime), '2026-01-01'), isNull);
    });

    test('a policy with no start has no end', () {
      expect(coverageEnd(cover(), null), isNull);
    });

    test('its own start beats the purchase date', () {
      final end = coverageEnd(
        cover(unit: CoverageUnit.months, amount: 12, startsOn: '2026-06-01'),
        '2020-01-01',
      );
      expect(end, DateTime(2027, 6, 1));
    });

    test('an unreadable date is no date rather than a throw', () {
      expect(coverageEnd(cover(), 'not a date'), isNull);
    });
  });

  group('the schedule', () {
    /*
      THE ORDERING IS THE FEATURE. Sorted soonest-first, lifetime last, so the
      thing that will actually stop being covered is at the top of every screen
      that shows this list.
    */
    test('soonest first, lifetime last', () {
      final couch = item(purchaseDate: '2026-01-01', coverages: [
        cover(id: 'frame', label: 'Frame', unit: CoverageUnit.lifetime),
        cover(id: 'cushions', label: 'Cushions', unit: CoverageUnit.years, amount: 10),
        cover(id: 'fabric', label: 'Fabric', unit: CoverageUnit.years, amount: 1),
      ]);

      final order = coverageSchedule(couch, now).map((d) => d.coverage.id).toList();
      expect(order, ['fabric', 'cushions', 'frame']);
    });

    test('the countdown follows the fabric, not the frame', () {
      final couch = item(purchaseDate: '2026-01-01', coverages: [
        cover(id: 'frame', unit: CoverageUnit.lifetime),
        cover(id: 'fabric', unit: CoverageUnit.years, amount: 1),
      ]);
      expect(nextToLapse(couch, now)!.coverage.id, 'fabric');
      expect(effectiveExpiry(couch, now), DateTime(2027, 1, 1));
    });

    test('a lapsed policy is skipped for the countdown', () {
      final thing = item(purchaseDate: '2020-01-01', coverages: [
        cover(id: 'gone', unit: CoverageUnit.years, amount: 1),
        cover(id: 'live', unit: CoverageUnit.years, amount: 10),
      ]);
      expect(nextToLapse(thing, now)!.coverage.id, 'live');
    });
  });

  group('legacy records', () {
    test('a bare warranty reads as one policy', () {
      final old = item(purchaseDate: '2026-01-01', warranty: const Warranty(months: 24));
      expect(coveragesOf(old).length, 1);
      expect(coveragesOf(old).first.label, defaultCoverageLabel);
    });

    test('with an extended one, two', () {
      final old = item(
        purchaseDate: '2026-01-01',
        warranty: const Warranty(months: 12),
        extendedWarranty: const Warranty(months: 36),
      );
      expect(coveragesOf(old).length, 2);
    });

    test('and a real list wins over both', () {
      final both = item(
        purchaseDate: '2026-01-01',
        coverages: [cover(id: 'real')],
        warranty: const Warranty(months: 12),
      );
      expect(coveragesOf(both).map((c) => c.id), ['real']);
    });
  });

  group('the state', () {
    test('plenty of time is covered', () {
      final fridge = item(
        purchaseDate: '2026-08-01',
        coverages: [cover(unit: CoverageUnit.years, amount: 5)],
      );
      expect(warrantyState(fridge, now), WarrantyState.covered);
    });

    test('inside the window is ending soon', () {
      final kettle = item(
        purchaseDate: '2025-09-01',
        coverages: [cover(unit: CoverageUnit.months, amount: 12)],
      );
      expect(warrantyState(kettle, now), WarrantyState.endingSoon);
    });

    test('past the end is expired', () {
      final old = item(
        purchaseDate: '2020-01-01',
        coverages: [cover(unit: CoverageUnit.years, amount: 1)],
      );
      expect(warrantyState(old, now), WarrantyState.expired);
    });

    test('no policy at all is unknown', () {
      expect(warrantyState(item(purchaseDate: '2026-01-01'), now), WarrantyState.unknown);
    });

    /*
      A term with no purchase date to run from isn't expired, it's unanswered —
      and saying "expired" about it would send someone looking for cover they
      may well still have.
    */
    test('a term with no date is unknown, not expired', () {
      final dateless = item(coverages: [cover(unit: CoverageUnit.years, amount: 2)]);
      expect(warrantyState(dateless, now), WarrantyState.unknown);
    });

    test('a lifetime policy is never expired', () {
      final forever = item(
        purchaseDate: '2010-01-01',
        coverages: [
          cover(id: 'frame', unit: CoverageUnit.lifetime),
          cover(id: 'fabric', unit: CoverageUnit.years, amount: 1),
        ],
      );
      expect(warrantyState(forever, now), WarrantyState.covered);
    });
  });

  group('the per-item lead time', () {
    test('the default is the global window', () {
      setEndingSoonDays(30);
      expect(itemLeadDays(item()), 30);
    });

    test('and an item can say otherwise', () {
      expect(itemLeadDays(item(leadDays: 365)), 365);
    });

    /*
      Zero is a real answer — "tell me on the day" — so only null falls back.
      `||` in the JavaScript would have promoted it to thirty.
    */
    test('zero is an answer, not an absence', () {
      expect(itemLeadDays(item(leadDays: 0)), 0);
    });

    test('the setting is clamped rather than trusted', () {
      setEndingSoonDays(0);
      expect(getEndingSoonDays(), 1);
      setEndingSoonDays(99999);
      expect(getEndingSoonDays(), 365);
    });

    /*
      A roof with cover running to March 2027 — 196 days out. At the global
      thirty it is merely covered; with a year of notice it is amber today.
      Every surface in the app asks this one function, so the ring, the
      timeline, the list filter and the notification move together.
    */
    test('a year of notice turns a roof amber today', () {
      setEndingSoonDays(30);
      final roof = item(
        purchaseDate: '2026-03-01',
        coverages: [cover(unit: CoverageUnit.months, amount: 12)],
      );
      expect(warrantyState(roof, now), WarrantyState.covered);
      expect(warrantyState(item(
        purchaseDate: '2026-03-01',
        coverages: [cover(unit: CoverageUnit.months, amount: 12)],
        leadDays: 365,
      ), now), WarrantyState.endingSoon);
    });

    test('but the expiry itself never moves', () {
      final a = item(
        purchaseDate: '2026-03-01',
        coverages: [cover(unit: CoverageUnit.months, amount: 12)],
      );
      final b = item(
        purchaseDate: '2026-03-01',
        coverages: [cover(unit: CoverageUnit.months, amount: 12)],
        leadDays: 365,
      );
      expect(effectiveExpiry(a, now), effectiveExpiry(b, now));
    });

    test('and a long lead cannot revive a lapsed item', () {
      final gone = item(
        purchaseDate: '2020-01-01',
        coverages: [cover(unit: CoverageUnit.months, amount: 12)],
        leadDays: 365,
      );
      expect(warrantyState(gone, now), WarrantyState.expired);
    });
  });

  group('labels', () {
    test('a blank label falls back', () {
      expect(coverageLabel(cover(label: '   ')), defaultCoverageLabel);
    });

    test('and a real one is kept', () {
      expect(coverageLabel(cover(label: 'Fabric')), 'Fabric');
    });
  });
}
