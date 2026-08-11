/**
 * Money and phone formatting.
 *
 *   npm run test:format
 *
 * These run on every keystroke, so the rule that matters most is that a
 * half-typed value survives intact. Formatting that fights the user mid-entry
 * is worse than no formatting at all.
 */

import {
  completeMoneyInput,
  currencySymbol,
  decimalsFor,
  formatMoneyInput,
  formatPhoneInput,
  phoneHref,
} from '@/lib/format';
import { parseMoneyToCents } from '@/lib/addItem';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const money = (input: string, want: string, currency = 'USD') => {
  const got = formatMoneyInput(input, currency);
  check(`money "${input}" → "${want}"`, got === want, got === want ? '' : `got "${got}"`);
};

/* ---------------------------------------------------------- grouping */

money('', '');
money('8', '8');
money('849', '849');
money('1234', '1,234');
money('1234567', '1,234,567');
money('1234.5', '1,234.5');
money('1234.56', '1,234.56');

// Typing state: a trailing dot must survive, or the decimal can never be typed.
money('1234.', '1,234.');
money('.', '0.');
money('.5', '0.5');

// Junk is dropped rather than rejected — people paste prices with symbols.
money('$1,299.99', '1,299.99');
money('abc', '');
money('12ab34', '1,234');

// Only the first dot counts; the rest are typos.
money('12.34.56', '12.3456'.slice(0, 5));
money('1.2.3', '1.23');

// Leading zeros go, but a lone zero stays — someone may be typing "0.99".
money('007', '7');
money('0', '0');
money('0.99', '0.99');

// Excess decimals are cut rather than rounded: rounding someone's input while
// their finger is still on the keyboard is maddening.
money('1.239', '1.23');

/* ---------------------------------------------------- zero-decimal money */

check('yen has no minor unit', decimalsFor('JPY') === 0);
check('dollars do', decimalsFor('USD') === 2);
money('1234', '1,234', 'JPY');
money('1234.5', '1,234', 'JPY');

/* -------------------------------------------------------------- symbols */

check('dollar', currencySymbol('USD') === '$');
check('pound', currencySymbol('GBP') === '£');
check('euro', currencySymbol('EUR') === '€');
check('yen', currencySymbol('JPY') === '¥');
check('an unknown currency shows its code', currencySymbol('XYZ') === 'XYZ');

/* ------------------------------------------------------------ on blur */

check('a bare number gains its decimals', completeMoneyInput('1234', 'USD') === '1,234.00');
check('a half-typed decimal is padded', completeMoneyInput('1234.5', 'USD') === '1,234.50');
check('a complete one is left alone', completeMoneyInput('1,234.56', 'USD') === '1,234.56');
check('an empty field stays empty', completeMoneyInput('', 'USD') === '');
check('yen gains nothing', completeMoneyInput('1234', 'JPY') === '1,234');

/* ------------------------------------------- the formatter feeds the parser */

const roundTrip = (typed: string, cents: number) => {
  const got = parseMoneyToCents(completeMoneyInput(typed, 'USD'));
  check(`"${typed}" stores as ${cents} cents`, got === cents, `got ${got}`);
};
roundTrip('849', 84900);
roundTrip('1234.5', 123450);
roundTrip('1234567.89', 123456789);
roundTrip('0.05', 5);

/* --------------------------------------------------------------- phone */

const phone = (input: string, want: string) => {
  const got = formatPhoneInput(input);
  check(`phone "${input}" → "${want}"`, got === want, got === want ? '' : `got "${got}"`);
};

// Progressive: the shape appears as it's typed, never after the fact.
phone('8', '8');
phone('860', '860');
phone('8605', '(860) 5');
phone('860555', '(860) 555');
phone('8605551234', '(860) 555-1234');

// Already-formatted input is idempotent — retyping a digit must not scramble it.
phone('(860) 555-1234', '(860) 555-1234');
check(
  'formatting twice changes nothing',
  formatPhoneInput(formatPhoneInput('8605551234')) === '(860) 555-1234',
);

// A leading 1 is kept visible, because that's how people read it aloud.
phone('18001234567', '1-(800) 123-4567');

// An explicit country code is the user being deliberate; leave it be.
phone('+44 20 7946 0018', '+44 20 7946 0018');
phone('+', '+');

// Nothing recognisable, nothing invented.
phone('', '');
phone('abc', '');
phone('123456789012345', '123456789012345');

check('the dialable form strips punctuation', phoneHref('(860) 555-1234') === '8605551234');
check('and keeps a plus', phoneHref('+44 20 7946 0018') === '+442079460018');

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
