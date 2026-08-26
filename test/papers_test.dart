/// Documents that expire, and when to start.
///
///   dart test test/papers_test.dart
///
/// Translated from `test/papers.test.ts`. The ordering assertions are the
/// feature: sorted by the printed date these come out backwards, and coming
/// out backwards is the mistake a calendar reminder makes.
library;

import 'package:stash_it/logic/papers.dart';
import 'package:stash_it/models/paper.dart';
import 'package:flutter_test/flutter_test.dart';

/// 17 August 2026, matching the fixture date the TypeScript suites pin.
final now = DateTime(2026, 8, 17);

Paper paper({
  String id = 'd',
  PaperKind kind = PaperKind.passport,
  String label = 'Passport',
  String expiresOn = '2027-02-11',
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
  group('the lead time', () {
    test('a passport gets eight months', () {
      expect(leadDaysFor(PaperKind.passport, null), 240);
    });

    test('a lease gets its notice period', () {
      expect(leadDaysFor(PaperKind.lease, null), 90);
    });

    test('and an override wins', () {
      expect(leadDaysFor(PaperKind.passport, 30), 30);
    });

    /*
      Zero is a real answer — "don't warn me early, tell me on the day" — and
      the obvious `leadDays || DEFAULT` would silently replace it with 240.
    */
    test('zero is a lead time, not a missing one', () {
      expect(leadDaysFor(PaperKind.passport, 0), 0);
    });

    test('every kind has one', () {
      for (final k in PaperKind.values) {
        expect(defaultLeadDays[k], isNotNull, reason: '$k has no default lead');
        expect(kindLabel[k], isNotNull, reason: '$k has no label');
      }
    });
  });

  group('renew by', () {
    test('counts back from the printed date', () {
      // 11 Feb 2027 minus 240 days.
      expect(renewBy(paper(expiresOn: '2027-02-11')), DateTime(2026, 6, 16));
    });

    test('an unreadable date has none', () {
      expect(renewBy(paper(expiresOn: '')), isNull);
      expect(renewBy(paper(expiresOn: '2026-02-31')), isNull);
    });

    test('a zero lead is the printed date itself', () {
      expect(renewBy(paper(expiresOn: '2027-02-11', leadDays: 0)), DateTime(2027, 2, 11));
    });
  });

  group('the state', () {
    test('plenty of runway is valid', () {
      expect(paperState(paper(expiresOn: '2030-01-01'), now), PaperState.valid);
    });

    /*
      THE STATE THE FEATURE EXISTS FOR. A passport expiring in February 2027 is
      perfectly valid today and needed starting in June — there is still time,
      and there will not be for long.
    */
    test('inside the lead time needs renewing', () {
      expect(paperState(paper(expiresOn: '2027-02-11'), now), PaperState.renew);
    });

    test('past the printed date is expired', () {
      expect(paperState(paper(expiresOn: '2026-07-10'), now), PaperState.expired);
    });

    test('today is not yet expired', () {
      expect(paperState(paper(expiresOn: '2026-08-17', leadDays: 0), now), PaperState.renew);
    });

    /*
      An unreadable date is not an expired document. Saying "expired" about a
      record whose date failed to parse would be inventing bad news.
    */
    test('an unreadable date is valid, not expired', () {
      expect(paperState(paper(expiresOn: 'soon'), now), PaperState.valid);
    });
  });

  group('sorting', () {
    /*
      THE CASE THE FILE EXISTS FOR. The passport expires LATER than the license
      and needs starting FIRST, because one needs eight months of runway and
      the other needs two. Sorted by the printed date they come out backwards.
    */
    test('by when to start, not by when they run out', () {
      final passport = paper(id: 'pp', label: 'Passport', expiresOn: '2027-05-01');
      final license = paper(
        id: 'dl',
        kind: PaperKind.licence,
        label: 'Driving license',
        expiresOn: '2026-12-01',
      );

      expect(expiryOf(passport)!.isAfter(expiryOf(license)!), isTrue,
          reason: 'the passport really does expire later');

      final order = sortPapers([license, passport], now).map((p) => p.id).toList();
      expect(order, ['pp', 'dl']);
    });

    test('a dateless document sinks to the bottom', () {
      final dated = paper(id: 'a', expiresOn: '2027-02-11');
      final undated = paper(id: 'z', expiresOn: '');
      expect(sortPapers([undated, dated], now).map((p) => p.id), ['a', 'z']);
    });

    test('ties break by name, so the order never jitters', () {
      final b = paper(id: 'b', label: 'Bravo', expiresOn: '2027-02-11');
      final a = paper(id: 'a', label: 'Alpha', expiresOn: '2027-02-11');
      expect(sortPapers([b, a], now).map((p) => p.id), ['a', 'b']);
    });

    test('the original list is left alone', () {
      final list = [paper(id: 'b', expiresOn: '2028-01-01'), paper(id: 'a', expiresOn: '2027-01-01')];
      sortPapers(list, now);
      expect(list.map((p) => p.id), ['b', 'a']);
    });
  });

  group('what needs doing', () {
    test('renew and expired both count, valid does not', () {
      final all = [
        paper(id: 'fine', expiresOn: '2030-01-01'),
        paper(id: 'due', expiresOn: '2027-02-11'),
        paper(id: 'gone', expiresOn: '2026-01-01'),
      ];
      expect(needsRenewing(all, now).map((p) => p.id).toSet(), {'due', 'gone'});
    });

    test('next up skips anything already overdue', () {
      final all = [
        paper(id: 'due', expiresOn: '2027-02-11'),
        paper(id: 'fine', expiresOn: '2030-01-01'),
      ];
      expect(nextUp(all, now)!.id, 'fine');
    });

    test('and is null when everything needs doing', () {
      expect(nextUp([paper(expiresOn: '2027-02-11')], now), isNull);
    });
  });

  group('naming from the tile', () {
    test('a tile names itself', () {
      expect(renameForKind(PaperKind.licence, '', PaperKind.passport), 'Drivers license');
    });

    test('and replaces the previous tile’s name', () {
      expect(
          renameForKind(PaperKind.licence, 'Passport', PaperKind.passport), 'Drivers license');
    });

    /*
      ANYTHING TYPED SURVIVES. A household has four passports and they get
      called "Nuno's passport". Correcting the tile must not throw that away.
    */
    test('but never something the user typed', () {
      expect(
        renameForKind(PaperKind.licence, "Nuno's passport", PaperKind.passport),
        "Nuno's passport",
      );
    });

    test('Other names nothing', () {
      expect(renameForKind(PaperKind.other, 'Passport', PaperKind.passport), '');
    });
  });

  group('holders', () {
    test('are deduplicated and sorted', () {
      final all = [
        paper(id: '1', holder: 'Nuno'),
        paper(id: '2', holder: 'Leo'),
        paper(id: '3', holder: 'Nuno'),
      ];
      expect(holders(all), ['Leo', 'Nuno']);
    });

    test('and blank ones cost nothing', () {
      expect(holders([paper(holder: '   '), paper(id: '2')]), isEmpty);
    });
  });
}
