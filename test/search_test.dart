/// Search matching and ranking.
///
///   dart test test/search_test.dart
///
/// Translated from `test/search.test.ts`. Pure functions over fixtures — no
/// database needed. The cases that matter are the ones a person actually hits:
/// half a serial read off a plate, an accent they didn't type, and two words
/// that live in different fields.
library;

import 'package:stash_it/logic/search.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';
import 'package:flutter_test/flutter_test.dart';

final rooms = [
  const Room(id: 'r-kitchen', propertyId: 'p1', name: 'Kitchen', sortOrder: 1),
  const Room(id: 'r-garage', propertyId: 'p1', name: 'Garage', sortOrder: 2),
];

final items = [
  Item(
    id: 'bosch-dishwasher',
    propertyId: 'p1',
    name: 'Bosch Dishwasher',
    brand: 'Bosch',
    model: 'SHXM4AY55N',
    serial: 'FD-9401-22817',
    retailer: "Lowe's",
    roomId: 'r-kitchen',
    warranty: const Warranty(months: 24, provider: 'Bosch Home', policyNumber: 'BH-77123'),
    notes: 'Installed by Kelly Plumbing',
  ),
  const Item(
    id: 'dewalt-table-saw',
    propertyId: 'p1',
    name: 'DeWalt Table Saw',
    brand: 'DeWalt',
    model: 'DWE7491RS',
    roomId: 'r-garage',
  ),
  const Item(
    id: 'series-8-oven',
    propertyId: 'p1',
    name: 'Séries 8 Oven',
    brand: 'Bosch',
    roomId: 'r-kitchen',
  ),
  Item(
    id: 'deleted-thing',
    propertyId: 'p1',
    name: 'Deleted Thing',
    deletedAt: DateTime(2026, 1, 1),
  ),
  const Item(id: 'kitchen-scales', propertyId: 'p1', name: 'Kitchen Scales'),
];

final docs = [
  const Doc(id: 'd1', itemId: 'dewalt-table-saw', title: 'Extended cover certificate'),
  Doc(
    id: 'd2',
    itemId: 'bosch-dishwasher',
    title: 'Gone receipt',
    deletedAt: DateTime(2026, 1, 1),
  ),
];

final papers = [
  const Paper(
    id: 'pp',
    propertyId: 'p1',
    kind: PaperKind.passport,
    label: 'Passport',
    holder: 'Nuno',
    authority: 'US Department of State',
    storedAt: 'Desk drawer',
    expiresOn: '2027-02-11',
  ),
  const Paper(
    id: 'insp',
    propertyId: 'p1',
    kind: PaperKind.vehicle,
    label: 'Inspection',
    holder: 'Golf',
    expiresOn: '2026-07-10',
  ),
  Paper(
    id: 'gone',
    propertyId: 'p1',
    kind: PaperKind.passport,
    label: 'Old passport',
    expiresOn: '2020-01-01',
    deletedAt: DateTime(2026, 1, 1),
  ),
];

final subs = [
  const Subscription(
    id: 'nflx',
    propertyId: 'p1',
    name: 'Netflix',
    cadence: Cadence.monthly,
    anchorDate: '2026-08-22',
    amountCents: 1549,
    currency: 'USD',
    notes: 'Shared with Kelly',
  ),
];

final input = SearchInput(
  items: items,
  docs: docs,
  rooms: rooms,
  papers: papers,
  subs: subs,
);

List<String> names(String q) => searchAll(q, input).map((h) => h.title).toList();

void main() {
  group('normalising', () {
    test('accents fold', () => expect(normalize('Séries'), 'series'));

    test('terms split on whitespace', () {
      expect(terms('  bosch   kitchen '), ['bosch', 'kitchen']);
    });

    test('an empty query returns nothing', () {
      expect(searchAll('   ', input), isEmpty);
    });

    /*
      The limit of the fold table, asserted so it is a known boundary rather
      than a surprise. Dart has no `String.normalize`, so this is a Latin table
      — see the note on `_fold`. Greek folds to itself and still matches
      exactly; it just is not accent-insensitive.
    */
    test('the fold table covers Latin and says so', () {
      expect(normalize('Æbleskiver'), 'aebleskiver');
      expect(normalize('Straße'), 'strasse');
      // Outside the table: the tonos survives, so it matches exactly and not
      // accent-insensitively. Known, bounded, and fixed by `diacritic` later.
      expect(normalize('ομέγα').contains('έ'), isTrue);
    });
  });

  group('the basics', () {
    test('finds by name', () => expect(names('dishwasher').first, 'Bosch Dishwasher'));
    test('finds by brand', () => expect(names('dewalt').first, 'DeWalt Table Saw'));
    test('finds by model', () => expect(names('DWE7491').first, 'DeWalt Table Saw'));
    test('is case-insensitive', () => expect(names('BOSCH').length, 2));

    test('accented names answer to unaccented queries', () {
      expect(names('series').first, 'Séries 8 Oven');
    });
  });

  group('serials', () {
    test('a partial serial matches', () {
      expect(names('22817').first, 'Bosch Dishwasher');
    });

    test('serial punctuation is ignored', () {
      expect(names('fd940122817').first, 'Bosch Dishwasher');
    });

    test('model punctuation is ignored', () {
      expect(names('shxm-4ay55n').first, 'Bosch Dishwasher');
    });
  });

  group('the other fields', () {
    test('finds by room', () => expect(names('garage').first, 'DeWalt Table Saw'));
    test('finds by retailer', () => expect(names('lowe').first, 'Bosch Dishwasher'));
    test('finds by notes', () => expect(names('kelly').first, 'Bosch Dishwasher'));

    test('finds by warranty provider', () {
      expect(names('BH-77123').first, 'Bosch Dishwasher');
    });

    test('finds by document title', () {
      expect(names('certificate').first, 'DeWalt Table Saw');
    });

    test('a deleted document does not match', () {
      expect(names('gone receipt'), isEmpty);
    });
  });

  group('AND terms', () {
    test('two terms across two fields', () {
      expect(names('bosch kitchen').length, 2);
    });

    test('every term must match', () {
      expect(names('bosch garage'), isEmpty);
    });

    test('name plus room narrows', () {
      expect(names('dishwasher kitchen'), ['Bosch Dishwasher']);
    });
  });

  group('what never appears', () {
    test('soft-deleted items', () => expect(names('deleted'), isEmpty));

    test('and soft-deleted documents, whatever table they are in', () {
      expect(names('old passport').contains('Old passport'), isFalse);
    });
  });

  group('ranking', () {
    // "kitchen" hits one item's name and two others' room. The name must win.
    test('a name match outranks a room match', () {
      expect(names('kitchen').first, 'Kitchen Scales');
    });

    test('an exact brand match outranks a substring', () {
      expect(searchAll('bosch', input).first.title, 'Bosch Dishwasher');
    });

    test('scores descend', () {
      final hits = searchAll('bosch', input);
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i].score, lessThanOrEqualTo(hits[i - 1].score));
      }
    });
  });

  group('the why-line', () {
    test('a name-only match explains nothing', () {
      expect(matchSummary(searchAll('dishwasher', input).first), isNull);
    });

    test('a serial match says so', () {
      expect(matchSummary(searchAll('22817', input).first), 'Matched on serial number');
    });

    test('a document match says so', () {
      expect(matchSummary(searchAll('certificate', input).first), 'Matched on a document');
    });

    test('and a document field is named properly', () {
      expect(matchSummary(searchAll('drawer', input).first), 'Matched on where it is kept');
    });
  });

  group('safety', () {
    /*
      Regex metacharacters are literal. Someone searching "a.*" means those
      three characters — treating it as a pattern would return the whole
      database, and a lone bracket would throw inside a keystroke handler.
    */
    test('metacharacters are not wildcards', () {
      expect(searchAll('a.*', input), isEmpty);
      expect(searchAll('.*', input), isEmpty);
    });

    test('a lone bracket does not throw', () {
      expect(searchAll('[', input), isEmpty);
    });

    test('a lone backslash does not throw', () {
      // Written escaped, not raw: a Dart raw string cannot end in a backslash.
      expect(searchAll('\\', input), isEmpty);
    });

    test('short punctuation-stripped terms do not run wild', () {
      expect(searchAll('n-', input), isEmpty);
    });
  });

  group('all three kinds', () {
    /*
      THE GAP THIS CLOSED. The one search field in the app lived on the Items
      tab and only ever looked at items, which was right until the app grew two
      more tables. Typing "passport" returned nothing — and an empty result does
      not read as "wrong tab", it reads as the app having lost your passport.
    */
    test('a document is findable at all', () {
      expect(names('passport'), contains('Passport'));
    });

    test('by the kind, not just the label', () {
      // The row is called "Inspection"; its kind is shown as "Vehicle".
      expect(names('vehicle'), contains('Inspection'));
    });

    test('by who it belongs to', () => expect(names('nuno'), contains('Passport')));

    test('by who issued it', () {
      expect(names('department of state'), contains('Passport'));
    });

    test('and by where it is kept', () {
      expect(names('drawer'), contains('Passport'));
    });

    test('a subscription is findable', () => expect(names('netflix'), contains('Netflix')));

    test('and an item by its notes', () {
      expect(names('kelly plumbing'), contains('Bosch Dishwasher'));
    });

    /*
      ONE LIST, RANKED TOGETHER, not three lists stacked. Someone searching a
      word wants the closest match to it and neither knows nor cares which
      table it came from — "golf" is the car's inspection, and it beats the
      notes of a dishwasher.
    */
    test('kinds compete on the same scale', () {
      final golf = searchAll('golf', input);
      expect(golf.first.title, 'Inspection');
    });

    test('and each result knows what it is', () {
      expect(searchAll('golf', input).first, isA<PaperHit>());
      expect(searchAll('netflix', input).first, isA<SubscriptionHit>());
      expect(searchAll('dishwasher', input).first, isA<ItemHit>());
    });

    // A word that hits two kinds returns both, so the badge in the UI is the
    // only thing telling them apart — which is why it exists.
    test('a word can match across kinds', () {
      final kelly = searchAll('kelly', input);
      expect(kelly.whereType<ItemHit>(), isNotEmpty);
      expect(kelly.whereType<SubscriptionHit>(), isNotEmpty);
    });

    // Every term still has to land, whatever mix of kinds is in play.
    test('two words that never co-occur find nothing', () {
      expect(searchAll('passport netflix', input), isEmpty);
    });

    test('but two words on one document do', () {
      expect(names('passport nuno'), contains('Passport'));
    });
  });
}
