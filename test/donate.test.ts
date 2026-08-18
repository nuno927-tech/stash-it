/**
 * The tip jar.
 *
 *   npm run test:donate
 *
 * A payment link is one of the few things in this app that reaches outside it,
 * and a wrong amount or a public audience isn't something the person finds out
 * about until after they've sent money.
 */

import {
  donationDue,
  money,
  MONTH_DAYS,
  TIERS,
  TIP_DUE_COPY,
  venmoUrl,
  VENMO_HANDLE,
  YEAR_DAYS,
  YEARLY_AMOUNT,
} from '@/lib/donate';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

function main() {
  /* ---------------------------------------------------------- the tiers */

  check('four amounts', TIERS.length === 4, String(TIERS.length));
  check('cheapest first', TIERS.every((t, i) => i === 0 || t.amount > TIERS[i - 1]!.amount));
  check('every tier says what it buys', TIERS.every((t) => t.label.length > 6));
  check('and carries a note for the payment', TIERS.every((t) => t.note.includes('Stash it')));
  check('the amounts are the ones offered', TIERS.map((t) => t.amount).join() === '1,3,5,10');

  /* ----------------------------------------------------------- the link */

  const url = new URL(venmoUrl({ amount: 3, note: 'Coffee for Stash it' }));
  const q = url.searchParams;

  check('it points at Venmo', url.hostname === 'venmo.com', url.hostname);
  check('and at the right person', q.get('recipients') === VENMO_HANDLE, q.get('recipients') ?? '');
  check('it is a payment, not a request', q.get('txn') === 'pay');

  // Venmo defaults to a public feed. Someone tipping a warranty app has not
  // agreed to have that broadcast to their friends list.
  check('private by default', q.get('audience') === 'private', q.get('audience') ?? '');

  // Two decimal places: Venmo has been known to read "3" and "3.00"
  // differently across clients, and the amount is the one field that must not
  // be open to interpretation.
  check('the amount is exact', q.get('amount') === '3.00', q.get('amount') ?? '');
  check('and so is a round ten', new URL(venmoUrl({ amount: 10, note: 'x' })).searchParams.get('amount') === '10.00');

  check('the note travels', q.get('note') === 'Coffee for Stash it');
  check(
    'monthly says so in the note',
    new URL(venmoUrl({ amount: 5, note: 'Pizza', cadence: 'monthly' })).searchParams.get('note') ===
      'Pizza (monthly)',
  );
  check(
    'and so does yearly',
    new URL(venmoUrl({ amount: 10, note: 'Lunch', cadence: 'yearly' })).searchParams.get('note') ===
      'Lunch (yearly)',
  );
  check(
    'never adds nothing',
    new URL(venmoUrl({ amount: 1, note: 'Thanks', cadence: 'never' })).searchParams.get('note') ===
      'Thanks',
  );

  // Everything is escaped by URLSearchParams rather than by hand.
  const odd = new URL(venmoUrl({ amount: 1, note: 'thanks & cheers?' }));
  check('notes with punctuation survive', odd.searchParams.get('note') === 'thanks & cheers?');

  /* -------------------------------------------------------- the reminder */

  const now = new Date('2026-08-12T09:00:00Z');
  const daysAgo = (n: number) => new Date(now.getTime() - n * 86_400_000).toISOString();

  // Never nag someone who hasn't opted in, and never on the day they did.
  check('no reminder without a first payment', !donationDue('monthly', undefined, now));
  check('not the same day', !donationDue('monthly', daysAgo(0), now));
  check('not after a fortnight', !donationDue('monthly', daysAgo(14), now));
  check('due after a month', donationDue('monthly', daysAgo(MONTH_DAYS), now));
  check('and stays due', donationDue('monthly', daysAgo(90), now));

  /*
    The one that would have been a bug. Someone who gave once and then turned
    the reminder off still has a `donateLastAt` on their record — a check that
    only looked at the date would start asking them again a month later, for a
    setting they had explicitly switched off.
  */
  check('never means never', !donationDue('never', daysAgo(900), now));
  check('and so does an unset cadence', !donationDue(undefined, daysAgo(900), now));

  // Yearly is a year, not a long month.
  check('a month is not a year', !donationDue('yearly', daysAgo(MONTH_DAYS), now));
  check('half a year is not either', !donationDue('yearly', daysAgo(180), now));
  check('a year is', donationDue('yearly', daysAgo(YEAR_DAYS), now));

  check(
    'every cadence that can be due has a line',
    TIP_DUE_COPY.monthly.length > 0 && TIP_DUE_COPY.yearly.length > 0 && TIP_DUE_COPY.never === '',
  );

  // A corrupt date must not turn into a permanent prompt — unlike a backup
  // reminder, nothing is at stake in missing this one.
  check('a corrupt date asks for nothing', !donationDue('monthly', 'not a date', now));

  /* --------------------------------------------------- the yearly amount */

  // The figure the running-costs note quotes has to be one the tip jar can
  // actually select, or "Chip in $10" lands on a screen offering something else.
  check(
    'the yearly amount is an offered tier',
    TIERS.some((t) => t.amount === YEARLY_AMOUNT),
    String(YEARLY_AMOUNT),
  );

  /* ------------------------------------------------------------- money */

  check('whole dollars have no decimals', money(3) === '$3', money(3));
  check('and ten reads plainly', money(10) === '$10', money(10));

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
