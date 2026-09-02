/// Reading a receipt.
///
///   flutter test test/receipt_read_test.dart
///
/// ── Real receipts, not tidy ones ───────────────────────────────────────────
/// The samples here are shaped like what actually comes off a thermal printer:
/// the word TOTAL four times with only one of them meaning it, an address
/// above the shop's name, a card expiry printed in the same format as the
/// purchase date, and prices written the European way round.
///
/// Every one of these was a bug at some point in writing it. The European
/// decimal comma read `1.299,00` as two hundred and ninety-nine, and the title
/// casing turned B&Q into B&q.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/receipt_read.dart';

final at = DateTime(2026, 9, 2);

ReceiptReading read(List<String> lines) => readReceipt(lines, today: at);

/// A whole supermarket receipt, in the order a camera would see it.
const List<String> lowes = [
  "LOWE'S HOME IMPROVEMENT",
  '1801 S BROADWAY',
  'LOS ANGELES CA 90015',
  '(213) 555-0134',
  '',
  'SALE',
  'BOSCH SHXM4AY55N DISHWASHER   749.99',
  '',
  'SUBTOTAL            749.99',
  'TAX 9.5%             71.25',
  'TOTAL               821.24',
  'VISA                821.24',
  'CHANGE                0.00',
  '',
  '03/04/2025  14:22',
  'THANK YOU FOR SHOPPING',
];

void main() {
  group('a whole receipt', () {
    test('the three things worth having come off it', () {
      final got = read(lowes);

      expect(got.date?.value, '2025-04-03');
      expect(got.totalCents?.value, 82124);
      expect(got.retailer?.value, "Lowe's Home Improvement");
    });

    test('the total is the one that was paid, not the subtotal', () {
      // SUBTOTAL, TAX and TOTAL all carry an amount, and TOTAL is fourth on
      // the page. Picking the first labelled line would have taken the item.
      expect(read(lowes).totalCents?.value, 82124);
    });

    test('the shop beats the address above it', () {
      expect(read(lowes).retailer?.value, isNot(contains('BROADWAY')));
    });

    test('each field says what line it came from', () {
      // The screen shows this beside the proposal. "Total: 821.24" is a claim;
      // the line it was read off is evidence somebody can check at a glance.
      expect(read(lowes).totalCents?.saw, contains('TOTAL'));
      expect(read(lowes).date?.saw, contains('03/04/2025'));
    });
  });

  group('dates', () {
    test('year first is read exactly, and known to be exact', () {
      final got = read(['ACME LTD', 'Invoice date 2025-03-04', 'TOTAL 12.00']);

      expect(got.date?.value, '2025-03-04');
      expect(got.date?.sureness, Sureness.clear);
    });

    test('a spelled month cannot be mistaken for a day', () {
      expect(read(['JOHN LEWIS', '4 Mar 2025']).date?.value, '2025-03-04');
      expect(read(['BEST BUY', 'Mar 4, 2025']).date?.value, '2025-03-04');
      expect(read(['JOHN LEWIS', '4 Mar 2025']).date?.sureness,
          Sureness.clear);
    });

    test('a number above twelve settles which is the day', () {
      final got = read(['TESCO', '23/11/2025 09:14']);

      expect(got.date?.value, '2025-11-23');
      expect(got.date?.sureness, Sureness.clear);
    });

    test('when neither can be told apart it says so', () {
      /*
        04/03/2025 is the fourth of March in most of the world and the third of
        April in the United States. Day first, because that is the reading
        almost everywhere — but `likely`, so the screen shows the line and the
        person holding the receipt settles it.
      */
      final got = read(['SHOP', '03/04/2025']);

      expect(got.date?.value, '2025-04-03');
      expect(got.date?.sureness, Sureness.likely);
    });

    test('a date in the future is a misread and is dropped', () {
      // A card expiry or a use-by, printed in the same format right beside the
      // purchase date. Offering one as a purchase date is worse than nothing.
      final got = read([
        'SHOP',
        'Use by 12/12/2030',
        'Purchased 01/06/2026',
        'TOTAL 5.00',
      ]);

      expect(got.date?.value, '2026-06-01');
    });

    test('a date that does not exist is dropped, not rounded', () {
      // DateTime(2025, 2, 30) silently becomes the second of March.
      final got = read(['SHOP', '30/02/2025', '15/03/2025']);

      expect(got.date?.value, '2025-03-15');
    });

    test('two digit years are this century', () {
      expect(read(['SHOP', '15/03/25']).date?.value, '2025-03-15');
    });

    test('nothing that looks like a date leaves it empty', () {
      expect(read(['SHOP', 'nothing here', 'TOTAL 5.00']).date, isNull);
    });
  });

  group('totals', () {
    test('a subtotal is never the answer', () {
      expect(read(['SHOP', 'SUBTOTAL 10.00', 'TOTAL 12.00']).totalCents?.value,
          1200);
    });

    test('the last TOTAL wins, because receipts print a running one', () {
      expect(
        read(['SHOP', 'TOTAL 10.00', 'more', 'TOTAL 25.50']).totalCents?.value,
        2550,
      );
    });

    test('amount due beats a plain total', () {
      expect(
        read(['SHOP', 'TOTAL 10.00', 'AMOUNT DUE 12.34']).totalCents?.value,
        1234,
      );
    });

    test('savings and tax are not the price', () {
      expect(
        read(['SHOP', 'TOTAL SAVINGS 40.00', 'TOTAL 12.00']).totalCents?.value,
        1200,
      );
    });

    test('with no label at all, the biggest amount is offered as likely', () {
      final got = read(['SHOP', 'apples 2.00', 'telly 399.99', 'bag 0.10']);

      expect(got.totalCents?.value, 39999);
      expect(got.totalCents?.sureness, Sureness.likely);
    });

    test('thousands separators, both ways round', () {
      /*
        `1,299.00` and `1.299,00` are the same money written in two countries.
        The last separator is the decimal point, which is what tells them apart
        without having to know where the receipt was printed — and reading it
        the other way round proposed a price a thousand short.
      */
      expect(read(['SHOP', 'TOTAL 1,299.00']).totalCents?.value, 129900);
      expect(read(['SHOP', 'TOTAL 1.299,00']).totalCents?.value, 129900);
    });

    test('the price is the last amount on the line, not the first', () {
      expect(read(['SHOP', 'TOTAL 3 items    74.99']).totalCents?.value, 7499);
    });

    test('no money on the page leaves it empty', () {
      expect(read(['SHOP', 'nothing here']).totalCents, isNull);
    });
  });

  group('the shop', () {
    test('an address above the name is stepped over', () {
      expect(read(['123 HIGH STREET', 'GREGGS', 'TOTAL 3.20']).retailer?.value,
          'Greggs');
    });

    test('so are the words receipts start with', () {
      expect(
        read(['RECEIPT', 'CURRYS PC WORLD', 'TOTAL 3.20']).retailer?.value,
        'Currys Pc World',
      );
    });

    test('and phone numbers', () {
      expect(read(['Tel 0800 555 111', 'B&Q', 'TOTAL 1.00']).retailer?.value,
          'B&Q');
    });

    test('an ampersand keeps the letter after it', () {
      // Splitting on spaces to title-case turns B&Q into B&q, because the Q is
      // the second character of its word.
      expect(read(['H&M', 'TOTAL 1.00']).retailer?.value, 'H&M');
    });

    test('a name already in mixed case was typed by somebody who meant it', () {
      expect(read(['Currys PC World', 'TOTAL 3.20']).retailer?.value,
          'Currys PC World');
    });

    test('it is always likely, never clear', () {
      // Nothing on a receipt says "this is the name of the shop". It is
      // position and shape, so it is always shown with the line it came from.
      expect(read(lowes).retailer?.sureness, Sureness.likely);
    });
  });

  group('nothing at all', () {
    test('an empty page reads as empty rather than as zeroes', () {
      expect(read(const []).isEmpty, isTrue);
    });

    test('blank lines are the same as no lines', () {
      expect(read(['', '   ', '']).isEmpty, isTrue);
    });

    test('a photograph of a wall proposes nothing', () {
      // Text recognition on something that is not a receipt returns words. It
      // must not produce a date, a price and a shop out of them.
      final got = read(['the', 'quick brown fox', 'jumps over']);

      expect(got.date, isNull);
      expect(got.totalCents, isNull);
    });
  });
}
