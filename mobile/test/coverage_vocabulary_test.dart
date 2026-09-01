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

      The form draws these as two rows and a Custom seat — what kind of policy
      then what it does for you. Reordering the list silently reshuffles the
      buttons on the screen, which is exactly the sort of change that looks
      harmless in a diff.
    */
    test('is four names, split two and three, in order', () {
      /*
        Four, not six. "Money back" and "Free service" came off: real answers
        and rare ones, each costing a segment on a control that was two rows of
        three and needed two lines per label to fit them. The card read as
        bloated and that was most of the reason.

        The split is two and three because the names are uneven — "Warranty"
        against "Extended warranty" — and the long ones need half a bar each to
        stay on one line. The third seat on the second row is Custom, which the
        control adds itself.
      */
      expect(coverageLabels, hasLength(4));
      expect(coverageLabels.take(2), [
        'Warranty',
        'Limited warranty',
      ]);
      expect(coverageLabels.skip(2), [
        'Extended warranty',
        'Parts and labor',
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

    test('the four are not, whitespace and all', () {
      for (final label in coverageLabels) {
        expect(isCustomLabel(label), isFalse);
        expect(isCustomLabel('  $label  '), isFalse);
      }
    });

    test('a name that used to be on the list is custom now', () {
      /*
        "Money back" was one of the six and is not one of the four. A record
        restored from a backup keeps saying it, and this is what becomes of it:
        the Custom slot, showing its own name.

        The honest outcome rather than a bug — it IS a custom name now, nothing
        is lost, and the alternative would be a hidden option only somebody's
        old data can reach.
      */
      expect(isCustomLabel('Money back'), isTrue);
      expect(isCustomLabel('Free service'), isTrue);
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
