/// Reading a shared receipt email.
///
///   dart test test/receipt_test.dart
///
/// Translated from `test/receipt.test.ts`. The governing rule is that **a wrong
/// guess is worse than no guess**, so most of these assert that something is
/// refused rather than that something is found.
library;

import 'package:stash_it/logic/receipt.dart';
import 'package:stash_it/models/types.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 8, 11, 12);

void main() {
  group('the merchant', () {
    String? from({String? title, String? text, String? url}) =>
        guessMerchant(SharedText(title: title, text: text, url: url));

    test('receipt from X', () {
      expect(from(title: 'Your receipt from Apple'), 'Apple');
    });

    test('order confirmation from X', () {
      expect(from(title: 'Order confirmation from John Lewis'), 'John Lewis');
    });

    test('your X order', () {
      expect(from(title: 'Your Amazon order has shipped'), 'Amazon');
    });

    test('thanks for shopping at X', () {
      expect(from(title: 'Thanks for shopping at Best Buy!'), 'Best Buy');
    });

    test('X: your order', () {
      expect(from(title: 'Currys — your order'), 'Currys');
    });

    test('a forwarded subject is unwrapped', () {
      expect(from(title: 'Fwd: Your receipt from Apple'), 'Apple');
      expect(from(title: 'Re: Receipt from Bosch'), 'Bosch');
    });

    test('and a domain suffix is trimmed off the name', () {
      expect(from(title: 'Your Amazon.com order'), 'Amazon');
    });

    /*
      The subject is worth far more than the body — it is written to be
      scanned, and the body is mostly boilerplate and shipping addresses — but
      a subject that says nothing falls through to the first few lines.
    */
    test('the body is the fallback when the subject says nothing', () {
      expect(
        from(title: 'Your order', text: 'Thanks for your order at Wickes\nDetails below'),
        'Wickes',
      );
    });

    /*
      And a shared link is the last resort. A bad guess here is visible in the
      form before anything is saved, which is what makes it acceptable at all.
    */
    test('a link is the last resort', () {
      expect(from(url: 'https://order.johnlewis.com/x/y'), 'Johnlewis');
    });

    test('and www is not a merchant', () {
      expect(from(url: 'https://www.currys.co.uk'), 'Currys');
    });

    test('nothing in, nothing out', () => expect(from(), isNull));

    test('and a sentence that is not about a shop is refused', () {
      expect(from(title: 'Your item has been delivered'), isNull);
    });
  });

  group('the total', () {
    /*
      THE CASE THE FUNCTION EXISTS FOR. An order email is full of numbers —
      subtotals, shipping, tax, each line, a promo code — and the largest is as
      likely to be an order id as a price. The labelled one wins.
    */
    const email = '''
    Order 114-2938475-1122
    Dishwasher            \$849.00
    Extended cover        \$129.99
    Subtotal              \$978.99
    Shipping                \$0.00
    Tax                    \$68.53
    Order total         \$1,047.52
  ''';

    test('the labelled total wins over the largest line', () {
      expect(guessTotal(email)!.cents, 104752);
    });

    test('and carries its currency', () {
      expect(guessTotal(email)!.currency, 'USD');
    });

    test('a label on the line above still finds it', () {
      expect(guessTotal('Total\n£299.99')!.cents, 29999);
    });

    /*
      "1,234.56" and "1.234,56" are the same money written by different
      countries. The last separator followed by exactly two digits is the
      decimal point — the same rule the price field uses.
    */
    test('a European decimal comma is read correctly', () {
      expect(guessTotal('Gesamt: €1.234,56')!.cents, 123456);
    });

    test('a trailing currency code counts', () {
      expect(guessTotal('Paid 45.00 GBP')!.currency, 'GBP');
      expect(guessTotal('Paid 45.00 GBP')!.cents, 4500);
    });

    test('with no label, the largest amount is the guess', () {
      expect(guessTotal(r'Coffee $4.50 and a kettle $89.99')!.cents, 8999);
    });

    test('no money, no guess', () {
      expect(guessTotal('Your order has shipped'), isNull);
      expect(guessTotal(null), isNull);
    });
  });

  group('the date', () {
    test('ISO', () => expect(parseLooseDate('Ordered 2026-07-04', today), '2026-07-04'));

    test('9 August 2026', () {
      expect(parseLooseDate('Placed 9 August 2026', today), '2026-08-09');
    });

    test('with an ordinal', () {
      expect(parseLooseDate('on the 3rd Mar 2026', today), '2026-03-03');
    });

    test('August 9, 2026', () {
      expect(parseLooseDate('August 9, 2026', today), '2026-08-09');
    });

    test('an abbreviated month', () {
      expect(parseLooseDate('Jul 4, 2026', today), '2026-07-04');
    });

    /*
      THE REFUSAL THAT MATTERS MOST. 03/04/2026 is the 3rd of April to most of
      the world and the 4th of March to the United States, and nothing in an
      email reliably says which. Guessing wrong shifts a warranty expiry by up
      to eleven months, and the error is invisible until the day it matters.
    */
    test('an ambiguous numeric date is refused', () {
      expect(parseLooseDate('03/04/2026', today), isNull);
    });

    test('but a day over 12 settles it', () {
      expect(parseLooseDate('25/07/2026', today), '2026-07-25');
    });

    test('and so does a month-first one', () {
      expect(parseLooseDate('07/25/2026', today), '2026-07-25');
    });

    /*
      A receipt is for something already bought. A date in the future is a
      delivery estimate or a warranty end, and neither is a purchase date.
    */
    test('a future date is not a purchase date', () {
      expect(parseLooseDate('2027-01-01', today), isNull);
    });

    test('today is fine', () {
      expect(parseLooseDate('2026-08-11', today), '2026-08-11');
    });

    test('an impossible month is skipped', () {
      expect(parseLooseDate('2026-13-01', today), isNull);
    });

    test('no date at all', () {
      expect(parseLooseDate('Thanks for your order', today), isNull);
      expect(parseLooseDate(null, today), isNull);
    });
  });

  group('the order number', () {
    test('an Amazon-style reference', () {
      expect(guessOrderNumber('Order #114-2938475-1122 shipped'), '114-2938475-1122');
    });

    test('an invoice reference', () {
      expect(guessOrderNumber('Invoice no. INV-99213'), 'INV-99213');
    });

    // A run of words is not a reference.
    test('and a sentence is not one', () {
      expect(guessOrderNumber('Order status update'), isNull);
      expect(guessOrderNumber(null), isNull);
    });
  });

  group('what kind of document', () {
    test('a warranty by filename', () {
      expect(guessDocKind('extended-warranty.pdf'), DocKind.warranty);
    });

    test('a protection plan is a warranty', () {
      expect(guessDocKind('protection plan.pdf'), DocKind.warranty);
    });

    test('a manual', () => expect(guessDocKind('user-guide.pdf'), DocKind.manual));

    test('an invoice is a receipt', () {
      expect(guessDocKind('invoice-2026.pdf'), DocKind.receipt);
    });

    // Someone who named a file "extended-warranty.pdf" has told us more than
    // the subject line of the email it arrived in.
    test('the filename beats the subject', () {
      expect(
        guessDocKind('warranty.pdf', const SharedText(title: 'Your receipt from Apple')),
        DocKind.warranty,
      );
    });

    test('but a nameless file falls back to the subject', () {
      expect(
        guessDocKind('IMG_20260810.jpg', const SharedText(title: 'Your warranty certificate')),
        DocKind.warranty,
      );
    });

    test('and a bare photo is assumed to be a receipt', () {
      expect(guessDocKind('IMG_1234.jpg'), DocKind.receipt);
      expect(guessDocKind(null), DocKind.receipt);
    });
  });

  group('end to end', () {
    final parsed = readReceipt(
      const SharedText(
        title: 'Your receipt from Currys',
        text: 'Order #ORD-55912\nPurchased 9 August 2026\nOrder total £1,299.00',
      ),
      today,
    );

    test('merchant', () => expect(parsed.merchant, 'Currys'));
    test('date', () => expect(parsed.purchaseDate, '2026-08-09'));
    test('total', () => expect(parsed.totalCents, 129900));
    test('currency', () => expect(parsed.currency, 'GBP'));
    test('order number', () => expect(parsed.orderNumber, 'ORD-55912'));

    /*
      Nothing recognisable must produce nothing — not zeroes and empty strings
      that look like the user typed them. A field left blank is obviously blank
      and takes five seconds to fill.
    */
    test('an ordinary email fills nothing in', () {
      final nothing = readReceipt(
        const SharedText(title: 'Hello', text: 'Just checking in'),
        today,
      );
      expect(nothing.merchant, isNull);
      expect(nothing.purchaseDate, isNull);
      expect(nothing.totalCents, isNull);
      expect(nothing.currency, isNull);
      expect(nothing.orderNumber, isNull);
    });
  });
}
