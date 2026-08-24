/// Drag-to-reorder arithmetic.
///
///   dart test test/reorder_test.dart
///
/// Translated from `test/reorder.test.ts`. The bug this guards: the held row is
/// drawn following your finger, so it is always under the pointer by
/// construction. A hit test that takes the first match while dragging downwards
/// finds the held row, compares it to where it started, sees no change, and
/// does nothing. Dragging down never reordered anything.
library;

import 'package:stash_it/logic/reorder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Five 50-pixel rows, stacked.
final rows = [
  const Span(0, 50),
  const Span(50, 100),
  const Span(100, 150),
  const Span(150, 200),
  const Span(200, 250),
];

void main() {
  group('the hit test', () {
    test('dragging down finds the row underneath', () {
      expect(dropTarget(rows, 120, 1), 2);
    });

    /*
      THE ASSERTION THE FILE EXISTS FOR. The held row is dragged down over its
      neighbour, so both boxes contain the pointer. Taking the first match
      returns the held row — index 1 — and the caller then does nothing at all.
    */
    test('and not the row in your hand, which is also under the pointer', () {
      final overlapping = [
        const Span(0, 50),
        const Span(100, 150), // held, dragged down onto row 2
        const Span(100, 150),
      ];
      final naive = overlapping.indexWhere((r) => 120 >= r.top && 120 <= r.bottom);
      expect(naive, 1, reason: 'the naive version returns the held row');
      expect(dropTarget(overlapping, 120, 1), 2);
    });

    test('dragging up finds the row above', () {
      expect(dropTarget(rows, 80, 3), 1);
    });

    test('a pointer past the end targets nothing', () {
      expect(dropTarget(rows, 9999, 0), isNull);
    });

    test('a pointer above the list targets nothing', () {
      expect(dropTarget(rows, -40, 4), isNull);
    });

    test('a gap between rows targets nothing', () {
      expect(dropTarget([const Span(0, 10), null], 40, 0), isNull);
    });

    // A null entry is a row that has not been measured yet, and is skipped
    // rather than treated as a zero-height row at the origin.
    test('an unmeasured row is skipped', () {
      expect(dropTarget([null, const Span(0, 50)], 25, 5), 1);
    });

    test('an empty list targets nothing', () {
      expect(dropTarget([], 10, 0), isNull);
    });

    test('the only row cannot be dropped on itself', () {
      expect(dropTarget([rows.first], 25, 0), isNull);
    });
  });

  group('the move', () {
    final list = ['a', 'b', 'c', 'd'];

    test('moving down', () => expect(moveWithin(list, 0, 2).join(), 'bcad'));
    test('moving up', () => expect(moveWithin(list, 3, 1).join(), 'adbc'));
    test('moving to the end', () => expect(moveWithin(list, 0, 3).join(), 'bcda'));

    // Identity, so a caller can use it to decide whether to rebuild.
    test('a move to the same place is the same list', () {
      expect(identical(moveWithin(list, 2, 2), list), isTrue);
    });

    test('an out-of-range source is ignored', () {
      expect(identical(moveWithin(list, 9, 1), list), isTrue);
      expect(identical(moveWithin(list, -1, 1), list), isTrue);
    });

    test('an out-of-range target is ignored', () {
      expect(identical(moveWithin(list, 0, 9), list), isTrue);
      expect(identical(moveWithin(list, 0, -1), list), isTrue);
    });

    test('the original is never mutated', () {
      moveWithin(list, 0, 3);
      expect(list.join(), 'abcd');
    });
  });
}
