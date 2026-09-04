/// Which squirrel the launch screen draws.
///
///   flutter test test/season_test.dart
///
/// ── Twelve assertions for four drawings ───────────────────────────────────
/// It is a `switch` on a month, and it would be reasonable to argue it does
/// not need a test. What it needs a test for is the BOUNDARIES: every one of
/// them is somebody's opinion about when a season starts, and the failure mode
/// is a bobble hat in March, which nobody sees until March.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/season.dart';

void main() {
  Season on(int month) => seasonOf(DateTime(2026, month, 15));

  group('every month lands somewhere', () {
    test('spring is March to May', () {
      expect(on(3), Season.spring);
      expect(on(4), Season.spring);
      expect(on(5), Season.spring);
    });

    test('summer is June to August', () {
      expect(on(6), Season.summer);
      expect(on(7), Season.summer);
      expect(on(8), Season.summer);
    });

    test('autumn is September to November', () {
      expect(on(9), Season.autumn);
      expect(on(10), Season.autumn);
      expect(on(11), Season.autumn);
    });

    /*
      December, January and February — the wrap is the one the `switch` handles
      with a default rather than a list, so it is the one worth pinning.
    */
    test('winter carries across the new year', () {
      expect(on(12), Season.winter);
      expect(on(1), Season.winter);
      expect(on(2), Season.winter);
    });
  });

  group('the edges of the months', () {
    /*
      Whole months, not solstices. An astronomical boundary moves between the
      20th and the 23rd depending on the year, which needs a table to be right
      and is invisible when it is wrong.
    */
    test('the last day of February is still winter', () {
      expect(seasonOf(DateTime(2026, 2, 28)), Season.winter);
    });

    test('and the first of March is spring', () {
      expect(seasonOf(DateTime(2026, 3, 1)), Season.spring);
    });

    test('new year is winter on both sides of it', () {
      expect(seasonOf(DateTime(2026, 12, 31, 23, 59)), Season.winter);
      expect(seasonOf(DateTime(2027, 1, 1, 0, 1)), Season.winter);
    });
  });

  test('every season has a month, and every month a season', () {
    // A `switch` with a default cannot fail to answer, but it can answer the
    // same thing twice — which would mean one of the four drawings is never
    // shown at all.
    final seen = {for (var m = 1; m <= 12; m++) on(m)};

    expect(seen, Season.values.toSet());
  });
}
