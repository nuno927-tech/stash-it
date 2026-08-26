/// The words and numbers the warranty card offers.
///
/// Small, and worth having: these two lists are the reason the form can be a
/// row of buttons instead of a text box, and both are the kind of constant
/// somebody appends to without checking what reads it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/item_form.dart';
import 'package:stash_it/models/types.dart';

void main() {
  group('coverageLabels', () {
    /*
      The order is the layout.

      The form draws these as two rows of three — what kind of policy it is,
      then what it does for you. Reordering the list silently reshuffles the
      buttons on the screen, which is exactly the sort of change that looks
      harmless in a diff.
    */
    test('is two rows of three, in order', () {
      expect(coverageLabels, hasLength(6));
      expect(coverageLabels.take(3), [
        'Warranty',
        'Limited warranty',
        'Extended warranty',
      ]);
      expect(coverageLabels.skip(3), [
        'Parts and labor',
        'Money back',
        'Free service',
      ]);
    });

    test('the default the rest of the app uses is one of them', () {
      // `defaultCoverageLabel` in warranty.dart is what an unnamed policy is
      // called everywhere it is displayed. If it were not on this list, the
      // form would open on an existing policy with nothing selected.
      expect(coverageLabels, contains('Warranty'));
    });
  });

  group('isCustomLabel', () {
    test('anything not on the list is custom', () {
      expect(isCustomLabel('Roof guarantee'), isTrue);
      expect(isCustomLabel('warranty'), isTrue, reason: 'case matters');
    });

    test('the six are not', () {
      for (final label in coverageLabels) {
        expect(isCustomLabel(label), isFalse);
      }
      expect(isCustomLabel('  Money back  '), isFalse);
    });

    /*
      A blank policy has not had anything invented for it. Treating empty as
      custom would light the Custom button on every freshly added row, which
      says the user made a choice they have not made.
    */
    test('blank is not custom', () {
      expect(isCustomLabel(''), isFalse);
      expect(isCustomLabel('   '), isFalse);
    });
  });

  group('coveragePresets', () {
    test('are the numbers printed on real warranties', () {
      expect(coveragePresets[CoverageUnit.days], [14, 30, 60, 90, 180]);
      expect(coveragePresets[CoverageUnit.months], [3, 6, 12, 18, 24]);
      expect(coveragePresets[CoverageUnit.years], [1, 2, 3, 5, 10]);
    });

    test('lifetime has none, because there is nothing to count', () {
      expect(coveragePresets[CoverageUnit.lifetime], isEmpty);
    });

    test('every unit has an entry, so the form can never index into null', () {
      for (final unit in CoverageUnit.values) {
        expect(coveragePresets[unit], isNotNull, reason: '$unit');
      }
    });
  });

  group('isCustomTerm', () {
    test('a number on the row is not custom', () {
      expect(isCustomTerm(CoverageUnit.months, '12'), isFalse);
      expect(isCustomTerm(CoverageUnit.years, '5'), isFalse);
      expect(isCustomTerm(CoverageUnit.days, '90'), isFalse);
    });

    test('a number off the row is', () {
      expect(isCustomTerm(CoverageUnit.months, '9'), isTrue);
      expect(isCustomTerm(CoverageUnit.years, '7'), isTrue);
    });

    /*
      Nothing typed yet is not a custom term — the row simply has nothing
      selected. Showing "9" in a Custom button on an empty form would be
      inventing an answer.
    */
    test('blank is not custom', () {
      expect(isCustomTerm(CoverageUnit.months, ''), isFalse);
      expect(isCustomTerm(CoverageUnit.months, '  '), isFalse);
    });

    test('lifetime is never custom, whatever is left in the box', () {
      // The length field is disabled under Lifetime but the text survives a
      // unit change, so this is reachable: type 24, switch to Lifetime.
      expect(isCustomTerm(CoverageUnit.lifetime, '24'), isFalse);
    });

    test('something unparseable counts as custom rather than crashing', () {
      expect(isCustomTerm(CoverageUnit.months, 'two'), isTrue);
    });
  });

  test('every unit has a label for its button', () {
    for (final unit in CoverageUnit.values) {
      expect(coverageUnitLabels[unit], isNotNull, reason: '$unit');
    }
    expect(coverageUnitLabels[CoverageUnit.lifetime], 'Lifetime');
  });
}
