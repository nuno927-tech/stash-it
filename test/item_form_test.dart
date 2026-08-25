/// What a half-filled item form means.
///
///   flutter test test/item_form_test.dart
///
/// ── The rule the whole file is arguing about ──────────────────────────────
/// **Refuse as little as possible.** An app that will not save a kettle until
/// you find the receipt is an app people stop opening. So most of these
/// assertions are that something incomplete *is* saveable — and the two that
/// refuse are the two where saving anyway would produce a record that lies.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/item_form.dart';
import 'package:stash_it/logic/warranty.dart';
import 'package:stash_it/models/types.dart';

void main() {
  group('what can be saved', () {
    test('a name alone is enough', () {
      final d = ItemDraft(name: 'Kettle');
      expect(whyNotSaveable(d), isNull);
    });

    test('but nothing at all is not', () {
      expect(whyNotSaveable(ItemDraft()), contains('Give it a name'));
    });

    test('and neither is whitespace', () {
      expect(whyNotSaveable(ItemDraft(name: '   ')), contains('Give it a name'));
    });

    // No date, no price, no cover — all fine. Most things people own are like
    // this and the app's job is to hold them anyway.
    test('no date and no price is fine', () {
      final d = ItemDraft(name: 'Lamp');
      expect(whyNotSaveable(d), isNull);

      final item = toItem(d, propertyId: 'default');
      expect(item.purchaseDate, isNull);
      expect(item.purchasePriceCents, isNull);
      expect(warrantyState(item), WarrantyState.unknown);
    });
  });

  group('the one real refusal', () {
    /*
      A term with no purchase date to count from is not a warranty, it is a
      number. Every countdown, colour, ring and reminder is arithmetic on that
      date — so saving "24 months" without it produces an item the app reports
      as untracked forever, while the person who typed 24 believes it is
      covered.
    */
    test('a term with nothing to count from is refused', () {
      final d = ItemDraft(
        name: 'Kettle',
        coverages: [CoverageDraft(unit: CoverageUnit.months, amountText: '24')],
      );
      expect(whyNotSaveable(d), contains('purchase date'));
    });

    test('and is fine the moment a date arrives', () {
      final d = ItemDraft(
        name: 'Kettle',
        purchaseDate: '2026-01-01',
        coverages: [CoverageDraft(unit: CoverageUnit.months, amountText: '24')],
      );
      expect(whyNotSaveable(d), isNull);
    });

    /*
      Lifetime is the exception, and it has to be. There is nothing to count
      down to, so there is nothing a date would be measured from — demanding
      one would be demanding a receipt for a promise that never expires.
    */
    test('lifetime cover needs no date', () {
      final d = ItemDraft(
        name: 'Couch',
        coverages: [CoverageDraft(label: 'Frame', unit: CoverageUnit.lifetime)],
      );
      expect(whyNotSaveable(d), isNull);
    });

    test('a term with no length is asked about by name', () {
      final d = ItemDraft(
        name: 'Couch',
        purchaseDate: '2026-01-01',
        coverages: [CoverageDraft(label: 'Fabric', provider: 'Ercol')],
      );
      expect(whyNotSaveable(d), contains('Fabric'));
    });

    // Tapping "add cover" and changing your mind is not an error.
    test('but a row nobody touched is dropped, not refused', () {
      final d = ItemDraft(name: 'Kettle', coverages: [CoverageDraft()]);
      expect(whyNotSaveable(d), isNull);
      expect(toItem(d, propertyId: 'default').coverages, isEmpty);
    });
  });

  group('turning it into a record', () {
    test('blank fields become null, not empty strings', () {
      final d = ItemDraft(name: 'Kettle', brand: '  ', notes: '');
      final item = toItem(d, propertyId: 'default');

      // A field somebody opened and left empty is not different from one they
      // never opened, and `''` makes every reader test for two kinds of
      // nothing.
      expect(item.brand, isNull);
      expect(item.notes, isNull);
    });

    test('the price goes through the same parser the field uses', () {
      final d = ItemDraft(name: 'Couch', priceText: r'$1,299.00');
      expect(toItem(d, propertyId: 'default').purchasePriceCents, 129900);
    });

    test('and an unparseable price is absent rather than zero', () {
      final d = ItemDraft(name: 'Couch', priceText: 'about a grand');
      expect(toItem(d, propertyId: 'default').purchasePriceCents, isNull);
    });

    test('an unnamed policy gets the default word', () {
      final d = ItemDraft(
        name: 'Kettle',
        purchaseDate: '2026-01-01',
        coverages: [CoverageDraft(unit: CoverageUnit.years, amountText: '2')],
      );
      expect(toItem(d, propertyId: 'default').coverages.single.label,
          defaultCoverageLabel);
    });

    test('lifetime stores no amount', () {
      final d = ItemDraft(
        name: 'Couch',
        coverages: [
          CoverageDraft(label: 'Frame', unit: CoverageUnit.lifetime, amountText: '99'),
        ],
      );
      final c = toItem(d, propertyId: 'default').coverages.single;
      expect(c.unit, CoverageUnit.lifetime);
      expect(c.amount, 0);
    });

    /*
      Zero is a real lead time — "tell me on the day" — and null means "use the
      setting". A form that collapsed one into the other would be invisible
      until somebody's roof stopped warning them a year early.
    */
    test('a zero lead time survives, and so does no lead time', () {
      expect(toItem(ItemDraft(name: 'A', leadDays: 0), propertyId: 'p').leadDays, 0);
      expect(toItem(ItemDraft(name: 'A'), propertyId: 'p').leadDays, isNull);
    });
  });

  group('editing something that exists', () {
    final couch = Item(
      id: 'couch',
      propertyId: 'default',
      name: 'Couch',
      brand: 'Ercol',
      purchaseDate: '2026-01-15',
      purchasePriceCents: 129900,
      currency: 'GBP',
      leadDays: 90,
      coverages: const [
        Coverage(
          id: 'frame',
          label: 'Frame',
          unit: CoverageUnit.lifetime,
          amount: 0,
          provider: 'Ercol',
        ),
        Coverage(id: 'fabric', label: 'Fabric', unit: CoverageUnit.years, amount: 1),
      ],
    );

    test('opens with everything in the boxes', () {
      final d = draftOf(couch);
      expect(d.name, 'Couch');
      expect(d.brand, 'Ercol');
      expect(d.purchaseDate, '2026-01-15');
      expect(d.priceText, '1299.00');
      expect(d.currency, 'GBP');
      expect(d.leadDays, 90);
      expect(d.coverages, hasLength(2));
    });

    test('and a lifetime policy shows no number to change', () {
      expect(draftOf(couch).coverages.first.amountText, '');
    });

    /*
      THE ROUND TRIP THAT MATTERS. Opening an item and saving it without
      touching anything must give back the same item — including the coverage
      ids, because those are what the schedule breaks ties by when two policies
      end on the same day.
    */
    test('saving an untouched draft changes nothing', () {
      final back = toItem(draftOf(couch), propertyId: 'default');

      expect(back.id, 'couch');
      expect(back.name, 'Couch');
      expect(back.purchasePriceCents, 129900);
      expect(back.leadDays, 90);
      expect(back.coverages.map((c) => c.id), ['frame', 'fabric']);
      expect(back.coverages.first.unit, CoverageUnit.lifetime);
      expect(back.coverages.last.amount, 1);

      // And the app still reads it the same way afterwards.
      final order = coverageSchedule(back, DateTime(2026, 8, 24))
          .map((d) => d.coverage.id);
      expect(order, ['fabric', 'frame']);
    });
  });
}
