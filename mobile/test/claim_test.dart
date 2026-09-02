/// What a claim says, and what it refuses to say.
///
///   flutter test test/claim_test.dart
///
/// ── This one is read by a stranger ─────────────────────────────────────────
/// Everything else the app writes is read by the person who owns the data.
/// This is read by a service desk with a queue, who owe the sender nothing and
/// will stop reading at the first line that is not one of the four things they
/// need: what it is, when it was bought, proof of that, and whether it is
/// still covered.
///
/// So the tests are mostly about what is NOT in it. An empty field printed as
/// "Serial: " or "Serial: unknown" is worse than a missing line — it tells the
/// desk the sender does not have one, when in fact they never typed it in and
/// could go and read it off the back of the machine.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/claim.dart';
import 'package:stash_it/models/types.dart';

final at = DateTime(2026, 9, 2);

Item bosch({
  String? serial = 'FD-9401-22817',
  String? retailer = "Lowe's",
  String? purchaseDate = '2025-03-04',
  int? priceCents = 74999,
  List<Coverage> coverages = const [
    Coverage(
      id: 'c1',
      label: 'Warranty',
      unit: CoverageUnit.years,
      amount: 2,
      provider: 'Bosch Home',
      policyNumber: 'BH-77123',
    ),
  ],
}) =>
    Item(
      id: 'b',
      propertyId: 'p1',
      name: 'Bosch dishwasher',
      brand: 'Bosch',
      model: 'SHXM4AY55N',
      serial: serial,
      retailer: retailer,
      purchaseDate: purchaseDate,
      purchasePriceCents: priceCents,
      currency: 'USD',
      coverages: coverages,
    );

String labelsOf(Item item) =>
    claimLines(item, now: at).map((l) => l.$1).join(',');

void main() {
  group('the facts', () {
    test('the ones a desk asks for are all there', () {
      final text = claimText(bosch(), now: at);

      expect(text, contains('Bosch dishwasher'));
      expect(text, contains('SHXM4AY55N'));
      expect(text, contains('FD-9401-22817'));
      expect(text, contains("Lowe's"));
      expect(text, contains(r'$749.99'));
    });

    test('the date is spelled out, not 03/09', () {
      // A desk in another country reads 03/09 as March the ninth. One of the
      // two forms is unambiguous everywhere and it is this one.
      expect(claimText(bosch(), now: at), contains('4 March 2025'));
      expect(claimText(bosch(), now: at), isNot(contains('2025-03-04')));
    });

    test('every policy, not just the nearest', () {
      // A couch has a lifetime frame, ten years on the cushions and one on the
      // fabric. Which is being claimed against is the desk's decision.
      final couch = bosch(coverages: const [
        Coverage(
            id: 'a', label: 'Frame', unit: CoverageUnit.lifetime, amount: 0),
        Coverage(id: 'b', label: 'Fabric', unit: CoverageUnit.years, amount: 1),
      ]);

      final text = claimText(couch, now: at);

      expect(text, contains('Frame'));
      expect(text, contains('Fabric'));
    });

    test('a lifetime policy says lifetime rather than a date', () {
      final forever = bosch(coverages: const [
        Coverage(
            id: 'a', label: 'Frame', unit: CoverageUnit.lifetime, amount: 0),
      ]);

      expect(claimText(forever, now: at), contains('lifetime'));
    });

    test('the provider and policy number ride with their own cover', () {
      final text = claimText(bosch(), now: at);

      expect(text, contains('Bosch Home'));
      expect(text, contains('BH-77123'));
    });
  });

  group('what it leaves out', () {
    test('a serial nobody typed produces no line at all', () {
      final without = bosch(serial: null);

      expect(labelsOf(without), isNot(contains('Serial')));
      expect(claimText(without, now: at), isNot(contains('Serial')));
    });

    test('a blank string counts as missing, not as an answer', () {
      expect(labelsOf(bosch(serial: '   ')), isNot(contains('Serial')));
    });

    test('no price, no price line', () {
      expect(labelsOf(bosch(priceCents: null)), isNot(contains('Price')));
    });

    test('no retailer, no From line', () {
      expect(labelsOf(bosch(retailer: '')), isNot(contains('From')));
    });

    test('an unreadable date is dropped rather than printed raw', () {
      // Better a claim with no purchase date than one saying "Bought: soon".
      final odd = bosch(purchaseDate: 'sometime in spring');

      expect(labelsOf(odd), isNot(contains('Bought')));
      expect(claimText(odd, now: at), isNot(contains('sometime in spring')));
    });

    test('nothing filled in at all is still a sendable message', () {
      final bare = Item(id: 'x', propertyId: 'p1', name: 'Kettle');
      final text = claimText(bare, now: at);

      expect(text, contains('Kettle'));
      expect(text.trim(), isNotEmpty);
    });
  });

  group('the opening line', () {
    test('in cover, it asks for a claim', () {
      final text = claimText(bosch(), now: at);

      expect(text, startsWith('I would like to make a warranty claim'));
      expect(text, contains('covered until'));
    });

    test('out of cover, it asks about a repair instead', () {
      /*
        The ask changes with the state, because sending the second worded as
        the first gets a flat no to a letter nobody meant to write. Plenty of
        manufacturers repair out of warranty, sometimes for nothing when the
        fault is theirs — but not in answer to a claim they can refuse in one
        line.
      */
      final old = bosch(purchaseDate: '2015-03-04');
      final text = claimText(old, now: at);

      expect(text, startsWith('I am asking about a repair'));
      expect(text, isNot(contains('I would like to make a warranty claim')));
    });

    test('no warranty recorded says so plainly', () {
      final unknown = bosch(coverages: const []);
      final text = claimText(unknown, now: at);

      expect(text, startsWith('I am asking about a repair'));
      expect(text, contains('do not have a warranty length recorded'));
    });
  });

  group('the attachments', () {
    test('one is named on its own line', () {
      final text = claimText(bosch(), attached: ['receipt.jpg'], now: at);

      expect(text, contains('Attached: receipt.jpg'));
    });

    test('several are listed', () {
      final text = claimText(
        bosch(),
        attached: ['receipt.jpg', 'warranty.pdf'],
        now: at,
      );

      expect(text, contains('Attached:'));
      expect(text, contains('receipt.jpg'));
      expect(text, contains('warranty.pdf'));
    });

    test('none means the word never appears', () {
      // An email saying "Attached:" with nothing under it reads as an email
      // with something wrong with it.
      expect(claimText(bosch(), now: at), isNot(contains('Attached')));
    });
  });

  test('the subject names the item, for an inbox to sort by', () {
    expect(claimSubject(bosch()), 'Warranty claim — Bosch dishwasher');
  });
}
