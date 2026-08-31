/// The filter predicates, which the dashboard counts with and the list shows.
///
///   flutter test test/item_filter_test.dart
///
/// These exist because the same idea was implemented twice — once as a `where`
/// inside a dashboard tally and once as a `where` inside the Items tab — and
/// the two drifted. A figure read 3 and opened a list of 21.
///
/// The bug that prompted them is not in this file, though: the filter was
/// being delivered through a `ValueNotifier` the tab read once and cleared, so
/// it was lost whenever the tab was built twice. That is now a constructor
/// argument and cannot be tested here. What CAN be pinned is the half that is
/// pure — that each name means one thing — so the next time the two ends
/// disagree it is not because a predicate quietly changed under one of them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/dashboard.dart';
import 'package:stash_it/logic/item_filter.dart';
import 'package:stash_it/models/types.dart';

Item item({
  String id = 'i1',
  String? purchaseDate,
  List<Coverage> coverages = const [],
  String? thumbBlobId,
}) =>
    Item(
      id: id,
      name: 'Thing',
      propertyId: 'p1',
      purchaseDate: purchaseDate,
      coverages: coverages,
      thumbBlobId: thumbBlobId,
    );

/// A purchase date `days` ago, written the way the model stores it.
String ago(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

const twoYears =
    Coverage(id: 'w', label: 'Warranty', unit: CoverageUnit.years, amount: 2);
const oneYear =
    Coverage(id: 'w', label: 'Warranty', unit: CoverageUnit.years, amount: 1);

void main() {
  const none = <String>{};

  group('the three warranty-state slices are exclusive', () {
    /*
      Between them these three plus "covered" have to account for every item
      exactly once, because the ring adds them up and shows the total as a
      percentage. An item counted twice inflates the divisor; one counted
      nowhere makes the arcs and the caption disagree.
    */
    final cases = <String, Item>{
      'covered': item(purchaseDate: ago(30), coverages: [twoYears]),
      'ending soon': item(purchaseDate: ago(355), coverages: [oneYear]),
      'lapsed': item(purchaseDate: ago(800), coverages: [oneYear]),
      'no term': item(purchaseDate: ago(30)),
    };

    for (final entry in cases.entries) {
      test('${entry.key} matches at most one of the three', () {
        final hits = [
          ItemFilter.endingSoon,
          ItemFilter.lapsed,
          ItemFilter.noTerm,
        ].where((f) => matchesFilter(f, entry.value, withReceipt: none));

        expect(hits.length, lessThanOrEqualTo(1),
            reason: '${entry.key} matched $hits');
      });
    }
  });

  test('no term and no warranty length are NOT the same question', () {
    /*
      This pair is why there are two filters rather than one. An item with a
      two-year warranty and no purchase date HAS a term — so the Needs a minute
      card must not nag about it — and still cannot be counted down, so the
      ring must call it undated. One filter for both would make one of the two
      numbers wrong, and it was the same single filter until this was split.
    */
    final termButNoDate = item(coverages: [twoYears]);

    expect(matchesFilter(ItemFilter.noTerm, termButNoDate, withReceipt: none),
        isTrue);
    expect(
        matchesFilter(ItemFilter.noCoverage, termButNoDate, withReceipt: none),
        isFalse);
  });

  test('no receipt is answered from the doc set, not from the item', () {
    final has = item(id: 'a');
    final hasnt = item(id: 'b');

    expect(matchesFilter(ItemFilter.noReceipt, has, withReceipt: {'a'}),
        isFalse);
    expect(matchesFilter(ItemFilter.noReceipt, hasnt, withReceipt: {'a'}),
        isTrue);
  });

  test('an empty purchase date counts as missing, not just null', () {
    // The form writes '' rather than null on a cleared field, and `gapsFor`
    // has always checked both. A predicate that only checked null would
    // undercount against the number printed on the card.
    for (final blank in [null, '']) {
      expect(
          matchesFilter(ItemFilter.noPurchaseDate, item(purchaseDate: blank),
              withReceipt: none),
          isTrue,
          reason: 'purchaseDate ${blank == null ? 'null' : 'empty'}');
    }
    expect(
        matchesFilter(ItemFilter.noPurchaseDate, item(purchaseDate: ago(1)),
            withReceipt: none),
        isFalse);
  });

  test('no photo reads the thumbnail, which is what the tile draws', () {
    expect(matchesFilter(ItemFilter.noPhoto, item(), withReceipt: none), isTrue);
    expect(
        matchesFilter(ItemFilter.noPhoto, item(thumbBlobId: 'b1'),
            withReceipt: none),
        isFalse);
  });

  test('every gap the card can show opens a filter', () {
    // The four rows used to open the unfiltered list. A GapKind with no entry
    // here is a row that would silently go back to doing that.
    for (final kind in GapKind.values) {
      expect(gapFilter[kind], isNotNull, reason: '$kind has no filter');
    }
  });

  test('every filter has a label, because the chip prints one', () {
    for (final f in ItemFilter.values) {
      expect(filterLabel[f], isNotNull, reason: '$f has no label');
    }
  });
}
