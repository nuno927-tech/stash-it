/// Money and phone formatting.
///
///   dart test test/format_test.dart
///
/// Translated from `test/format.test.ts`. These run on every keystroke, so the
/// rule that matters most is that a half-typed value survives intact.
/// Formatting that fights the user mid-entry is worse than no formatting.
library;

import 'package:stash_it/logic/format.dart';
import 'package:test/test.dart';

void money(String input, String want, [String currency = 'USD']) {
  test('money "$input" → "$want"${currency == 'USD' ? '' : ' ($currency)'}', () {
    expect(formatMoneyInput(input, currency), want);
  });
}

void phone(String input, String want) {
  test('phone "$input" → "$want"', () {
    expect(formatPhoneInput(input), want);
  });
}

void main() {
  group('grouping', () {
    money('', '');
    money('8', '8');
    money('849', '849');
    money('1234', '1,234');
    money('1234567', '1,234,567');
    money('1234.5', '1,234.5');
    money('1234.56', '1,234.56');
  });

  group('typing state', () {
    // A trailing dot must survive, or the decimal can never be typed.
    money('1234.', '1,234.');
    money('.', '0.');
    money('.5', '0.5');
  });

  group('junk', () {
    // Dropped rather than rejected — people paste prices with symbols.
    money(r'$1,299.99', '1,299.99');
    money('abc', '');
    money('12ab34', '1,234');

    // Only the first dot counts; the rest are typos.
    money('12.34.56', '12.34');
    money('1.2.3', '1.23');

    // Leading zeros go, but a lone zero stays — someone may be typing "0.99".
    money('007', '7');
    money('0', '0');
    money('0.99', '0.99');

    // Excess decimals are cut rather than rounded: rounding someone's input
    // while their finger is still on the keyboard is maddening.
    money('1.239', '1.23');
  });

  group('zero-decimal money', () {
    test('yen has no minor unit', () => expect(decimalsFor('JPY'), 0));
    test('dollars do', () => expect(decimalsFor('USD'), 2));
    money('1234', '1,234', 'JPY');
    money('1234.5', '1,234', 'JPY');
  });

  group('symbols', () {
    test('dollar', () => expect(currencySymbol('USD'), r'$'));
    test('pound', () => expect(currencySymbol('GBP'), '£'));
    test('euro', () => expect(currencySymbol('EUR'), '€'));
    test('yen', () => expect(currencySymbol('JPY'), '¥'));
    test('an unknown currency shows its code', () {
      expect(currencySymbol('XYZ'), 'XYZ');
    });
  });

  group('on blur', () {
    test('a bare number gains its decimals', () {
      expect(completeMoneyInput('1234'), '1,234.00');
    });

    test('a half-typed decimal is padded', () {
      expect(completeMoneyInput('1234.5'), '1,234.50');
    });

    test('a complete one is left alone', () {
      expect(completeMoneyInput('1,234.56'), '1,234.56');
    });

    test('an empty field stays empty', () => expect(completeMoneyInput(''), ''));

    test('yen gains nothing', () {
      expect(completeMoneyInput('1234', 'JPY'), '1,234');
    });
  });

  group('the formatter feeds the parser', () {
    /*
      The two have to agree about what a typed price means, which is why they
      are in one file here rather than split across format.ts and addItem.ts.
      Money is stored as integer minor units, never a float.
    */
    void roundTrip(String typed, int cents) {
      test('"$typed" stores as $cents cents', () {
        expect(parseMoneyToCents(completeMoneyInput(typed)), cents);
      });
    }

    roundTrip('849', 84900);
    roundTrip('1234.5', 123450);
    roundTrip('1234567.89', 123456789);
    roundTrip('0.05', 5);

    /*
      The separator rule, which is the part that is genuinely ambiguous:
      "1.299" is one thousand two hundred and ninety-nine euros in Germany and
      one pound thirty in the UK. The last separator followed by exactly two
      digits is the decimal point; anything else is a thousands separator.
    */
    test('a two-digit tail is a decimal', () {
      expect(parseMoneyToCents('1.30'), 130);
    });

    test('a three-digit tail is a thousands separator', () {
      expect(parseMoneyToCents('1.299'), 129900);
    });

    test('and so is a comma', () {
      expect(parseMoneyToCents('1,299'), 129900);
    });

    test('nothing typed is nothing stored', () {
      expect(parseMoneyToCents(''), isNull);
      expect(parseMoneyToCents('abc'), isNull);
      expect(parseMoneyToCents('-'), isNull);
    });
  });

  group('phone', () {
    // Progressive: the shape appears as it is typed, never after the fact.
    phone('8', '8');
    phone('860', '860');
    phone('8605', '(860) 5');
    phone('860555', '(860) 555');
    phone('8605551234', '(860) 555-1234');

    // Already-formatted input is idempotent — retyping a digit must not
    // scramble what is already on screen.
    phone('(860) 555-1234', '(860) 555-1234');

    test('formatting twice changes nothing', () {
      expect(formatPhoneInput(formatPhoneInput('8605551234')), '(860) 555-1234');
    });

    // A leading 1 is kept visible, because that is how people read it aloud.
    phone('18001234567', '1-(800) 123-4567');

    // An explicit country code is the user being deliberate; leave it be.
    phone('+44 20 7946 0018', '+44 20 7946 0018');
    phone('+', '+');

    // Nothing recognisable, nothing invented.
    phone('', '');
    phone('abc', '');

    test('the dialable form strips punctuation', () {
      expect(phoneHref('(860) 555-1234'), '8605551234');
    });

    test('and keeps a plus', () {
      expect(phoneHref('+44 20 7946 0018'), '+442079460018');
    });
  });
}
