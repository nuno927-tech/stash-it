/**
 * Reading a shared receipt.
 *
 *   npm run test:receipt
 *
 * The governing rule is that a wrong guess is worse than no guess, so most of
 * this file is about what the parser refuses. A blank field is visibly blank.
 * A plausible wrong date gets saved and only surfaces years later, when the
 * warranty it implied turns out to have expired months before the app said.
 */

import {
  guessDocKind,
  guessMerchant,
  guessOrderNumber,
  guessTotal,
  parseLooseDate,
  readReceipt,
} from '@/lib/receipt';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const TODAY = new Date('2026-08-11T12:00:00Z');

function main() {
  /* ------------------------------------------------------------ merchant */

  check('receipt from X', guessMerchant({ title: 'Your receipt from Apple' }) === 'Apple');
  check(
    'order confirmation from X',
    guessMerchant({ title: 'Order confirmation from John Lewis' }) === 'John Lewis',
  );
  check('your X order', guessMerchant({ title: 'Your Amazon order has shipped' }) === 'Amazon');
  check(
    'thanks for shopping at X',
    guessMerchant({ title: 'Thanks for shopping at Best Buy!' }) === 'Best Buy',
  );
  check('X: your order', guessMerchant({ title: 'Currys — your order' }) === 'Currys');

  // Mail clients prefix subjects and the prefix is never the shop.
  check(
    'a forward prefix is stripped',
    guessMerchant({ title: 'Fwd: Your receipt from Apple' }) === 'Apple',
  );
  check('and Re:', guessMerchant({ title: 'Re: Receipt from Bosch' }) === 'Bosch');

  // The .com belongs to the domain, not the name on the shop front.
  check(
    'a trailing TLD is dropped',
    guessMerchant({ title: 'Your Amazon.com order' }) === 'Amazon',
  );

  check(
    'the body is read when the subject says nothing',
    guessMerchant({ title: 'Your order', text: 'Thanks for your order at Wickes\nDetails below' }) ===
      'Wickes',
  );

  check(
    'a link is the last resort',
    guessMerchant({ url: 'https://order.johnlewis.com/x/y' }) === 'Johnlewis',
  );
  check('and www is not a merchant', guessMerchant({ url: 'https://www.currys.co.uk' }) === 'Currys');

  check('nothing in, nothing out', guessMerchant({}) === undefined);
  check(
    'a subject with no shop in it stays empty',
    guessMerchant({ title: 'Your item has been delivered' }) === undefined,
  );

  /* --------------------------------------------------------------- total */

  // The largest number in a receipt email is often an order id, and the price
  // of the most expensive line is not the total.
  const email = `
    Order 114-2938475-1122
    Dishwasher            $849.00
    Extended cover        $129.99
    Subtotal              $978.99
    Shipping                $0.00
    Tax                    $68.53
    Order total         $1,047.52
  `;
  const total = guessTotal(email);
  check('the labelled total wins over the largest line', total?.cents === 104752, String(total?.cents));
  check('and carries its currency', total?.currency === 'USD');

  check(
    'total appearing before the number on the next line',
    guessTotal('Total\n£299.99')?.cents === 29999,
  );
  check(
    'European grouping is read correctly',
    guessTotal('Gesamt: €1.234,56')?.cents === 123456,
    String(guessTotal('Gesamt: €1.234,56')?.cents),
  );
  check('a trailing code counts', guessTotal('Paid 45.00 GBP')?.currency === 'GBP');
  check(
    'with no label, the largest amount is the guess',
    guessTotal('Coffee $4.50 and a kettle $89.99')?.cents === 8999,
  );
  check('no money, no guess', guessTotal('Your order has shipped') === undefined);
  check('undefined in, undefined out', guessTotal(undefined) === undefined);

  /* ---------------------------------------------------------------- date */

  check('ISO', parseLooseDate('Ordered 2026-07-04', TODAY) === '2026-07-04');
  check('9 August 2026', parseLooseDate('Placed 9 August 2026', TODAY) === '2026-08-09');
  check('with an ordinal', parseLooseDate('on the 3rd Mar 2026', TODAY) === '2026-03-03');
  check('August 9, 2026', parseLooseDate('August 9, 2026', TODAY) === '2026-08-09');
  check('abbreviated month', parseLooseDate('Jul 4, 2026', TODAY) === '2026-07-04');

  // The heart of it: 03/04/2026 is two different days depending on which side
  // of the Atlantic wrote it, and an email never says which.
  check('an ambiguous numeric date is refused', parseLooseDate('03/04/2026', TODAY) === undefined);
  check('a day over 12 settles it', parseLooseDate('25/07/2026', TODAY) === '2026-07-25');
  check('so does a month-first one', parseLooseDate('07/25/2026', TODAY) === '2026-07-25');
  // Both readings are in the past here, and it's still refused — the point is
  // that we can't tell, not that we can't tell *and* it matters.
  check('still refused when both readings are plausible', parseLooseDate('03/04/2026', TODAY) === undefined);

  // A future date in a receipt is a delivery estimate or a warranty end.
  check('a future date is not a purchase date', parseLooseDate('2027-01-01', TODAY) === undefined);
  check('today is fine', parseLooseDate('2026-08-11', TODAY) === '2026-08-11');
  check('an impossible month is skipped', parseLooseDate('2026-13-01', TODAY) === undefined);
  check('no date at all', parseLooseDate('Thanks for your order', TODAY) === undefined);

  /* -------------------------------------------------------- order number */

  check(
    'an order number',
    guessOrderNumber('Order #114-2938475-1122 shipped') === '114-2938475-1122',
  );
  check('invoice reference', guessOrderNumber('Invoice no. INV-99213') === 'INV-99213');
  check('a run of words is not a reference', guessOrderNumber('Order status update') === undefined);

  /* ----------------------------------------------------------------- kind */

  check('a warranty by filename', guessDocKind('extended-warranty.pdf') === 'warranty');
  check('a protection plan is a warranty', guessDocKind('protection plan.pdf') === 'warranty');
  check('a manual', guessDocKind('user-guide.pdf') === 'manual');
  check('an invoice is a receipt', guessDocKind('invoice-2026.pdf') === 'receipt');
  check(
    'the filename beats the subject',
    guessDocKind('warranty.pdf', { title: 'Your receipt from Apple' }) === 'warranty',
  );
  check(
    'the subject is used when the filename is noise',
    guessDocKind('IMG_20260810.jpg', { title: 'Your warranty certificate' }) === 'warranty',
  );
  check('a bare photo is assumed to be a receipt', guessDocKind('IMG_1234.jpg') === 'receipt');

  /* ---------------------------------------------------------------- whole */

  const parsed = readReceipt(
    {
      title: 'Your receipt from Currys',
      text: 'Order #ORD-55912\nPurchased 9 August 2026\nOrder total £1,299.00',
    },
    TODAY,
  );
  check('end to end: merchant', parsed.merchant === 'Currys', parsed.merchant);
  check('end to end: date', parsed.purchaseDate === '2026-08-09', parsed.purchaseDate);
  check('end to end: total', parsed.totalCents === 129900, String(parsed.totalCents));
  check('end to end: currency', parsed.currency === 'GBP', parsed.currency);
  check('end to end: order', parsed.orderNumber === 'ORD-55912', parsed.orderNumber);

  // Nothing recognisable must produce nothing, not zeroes and empty strings
  // that look like the user typed them.
  const nothing = readReceipt({ title: 'Hello', text: 'Just checking in' }, TODAY);
  check(
    'an ordinary email fills nothing in',
    nothing.merchant === undefined &&
      nothing.purchaseDate === undefined &&
      nothing.totalCents === undefined &&
      nothing.orderNumber === undefined,
  );

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
