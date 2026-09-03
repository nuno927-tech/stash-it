/// The line above the search results.
///
///   flutter test test/search_counts_test.dart
///
/// ── Why a summary line needs testing at all ────────────────────────────────
/// The results are ranked together rather than grouped by kind, which is the
/// right call — somebody typing "golf" wants the closest match and does not
/// care which table it came from. It has exactly one cost: a list that opens
/// with four items looks like a search that found four things, and the
/// passport ranked fifth is below the fold.
///
/// This line is the whole mitigation. If it says the wrong number, or says
/// "0 subscriptions", or disappears when it should not, somebody concludes
/// their document is missing from a screen that is showing it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/search.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';

ItemHit anItem(String name) => ItemHit(
      Item(id: name, propertyId: 'p1', name: name),
      score: 10,
      fields: const [MatchField.name],
      title: name,
    );

PaperHit aPaper(String label) => PaperHit(
      Paper(
        id: label,
        propertyId: 'p1',
        kind: PaperKind.passport,
        label: label,
        expiresOn: '2029-06-01',
      ),
      score: 10,
      fields: const [MatchField.name],
      title: label,
    );

SubscriptionHit aSub(String name) => SubscriptionHit(
      Subscription(
        id: name,
        propertyId: 'p1',
        name: name,
        cadence: Cadence.monthly,
        anchorDate: '2026-08-22',
        amountCents: 100,
        currency: 'USD',
      ),
      score: 10,
      fields: const [MatchField.name],
      title: name,
    );

void main() {
  group('counting', () {
    test('nothing found is three zeroes', () {
      final many = countByKind(const []);

      expect(many.items, 0);
      expect(many.papers, 0);
      expect(many.subs, 0);
    });

    test('each kind lands in its own column', () {
      final many = countByKind([
        anItem('Bosch dishwasher'),
        aPaper('Passport'),
        anItem('Bosch drill'),
        aSub('Netflix'),
        aPaper('Driving licence'),
      ]);

      expect(many.items, 2);
      expect(many.papers, 2);
      expect(many.subs, 1);
    });

    test('the counts add up to the list', () {
      final hits = [
        for (var i = 0; i < 7; i++) anItem('item $i'),
        for (var i = 0; i < 3; i++) aPaper('paper $i'),
      ];

      final many = countByKind(hits);

      expect(many.items + many.papers + many.subs, hits.length);
    });
  });

  group('what the line says', () {
    test('nothing found says so in words', () {
      expect(foundLine(const []), 'Nothing matches that');
    });

    test('one of each, named and separated', () {
      expect(
        foundLine([anItem('a'), aPaper('b'), aSub('c')]),
        '1 item · 1 document · 1 subscription',
      );
    });

    test('plurals, because "1 items" is how an app looks unfinished', () {
      expect(
        foundLine([anItem('a'), anItem('b'), aPaper('c'), aPaper('d')]),
        '2 items · 2 documents',
      );
    });

    test('a kind with nothing in it is left out entirely', () {
      /*
        Not "0 subscriptions". A zero is not a result, and printing all three
        every time is how a summary line becomes furniture that nobody reads —
        including on the occasion it says something.
      */
      final line = foundLine([anItem('a'), aSub('b')]);

      expect(line, '1 item · 1 subscription');
      expect(line, isNot(contains('0')));
      expect(line, isNot(contains('document')));
    });

    test('items only reads like the list always did', () {
      expect(foundLine([anItem('a'), anItem('b')]), '2 items');
    });

    test('documents only, which is the case that prompted all this', () {
      // Typing "passport" used to return nothing at all.
      expect(foundLine([aPaper('Passport')]), '1 document');
    });
  });
}
