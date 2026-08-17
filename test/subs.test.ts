/**
 * Subscriptions: when they renew, what they cost, and what they say.
 *
 *   npm run test:subs
 *
 * Every figure on the subscriptions tab is derived from two fields — a cadence
 * and one anchor date — so every bug in this file is a wrong number presented
 * confidently. A renewal date that is one day out looks exactly like a correct
 * one until the money leaves.
 *
 * The cases that earn their place here are the ones a calendar gets wrong:
 * month ends, February, leap years, and the difference between "four weeks"
 * and "a month".
 */

/*
  Pinned to a timezone that observes DST, and pinned before anything else runs.

  Every assertion below is written in local time, so on a UTC machine the whole
  file quietly stops testing the hardest thing about this module. A weekly
  subscription anchored on a Monday renewed on Sundays from November onwards
  for one release, and no test here noticed, because the tests ran where a day
  is always 24 hours long. It only turned up when a realistic dataset was run
  through the dashboard on a laptop set to New York.

  A bug that reproduces for half the world and no CI machine is worse than one
  that reproduces for everybody.
*/
process.env.TZ = 'America/New_York';

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import {
  activeSubscriptions,
  createSubscription,
  deleteSubscription,
  activeItemCount,
  canAddItem,
} from '@/db/repo';
import { FREE_ITEM_LIMIT, SCHEMA_VERSION, type Cadence, type Subscription } from '@/db/types';
import {
  addMonthsClamped,
  biggest,
  dailyCents,
  daysUntilRenewal,
  dueWithin,
  dueReminders,
  heaviest,
  monthlyCents,
  nextRenewal,
  ordinal,
  parseAnchor,
  renewalLabel,
  renewalsBetween,
  renewalsInMonth,
  spendByMonth,
  spread,
  subGaps,
  totalMonthlyCents,
  totalYearlyCents,
} from '@/lib/subscriptions';
import { CATALOGUE, monogram, monogramColour, searchServices } from '@/lib/services';
import { exportBundle, parseBundle, restoreBundle } from '@/lib/backup';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const iso = (d: Date | null) =>
  d ? `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` : 'null';

function sub(over: Partial<Subscription> = {}): Subscription {
  return {
    id: 'x',
    schemaVersion: SCHEMA_VERSION,
    propertyId: 'p',
    name: 'Netflix',
    cadence: 'monthly' as Cadence,
    anchorDate: '2026-01-15',
    amountCents: 1299,
    currency: 'USD',
    createdAt: '',
    updatedAt: '',
    ...over,
  };
}

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;

  /* -------------------------------------------------------- parsing dates */

  check('a real date parses', iso(parseAnchor('2026-03-09')) === '2026-03-09');
  // `new Date('2026-02-31')` rolls silently into March, which would put a
  // renewal in the wrong month for ever after.
  check('an impossible date is refused', parseAnchor('2026-02-31') === null);
  check('so is rubbish', parseAnchor('next tuesday') === null);
  check('and an empty string', parseAnchor('') === null);

  /* ------------------------------------------------------ clamped months */

  /*
    A subscription anchored on the 31st renews on the 30th in April and the
    28th in February — that is what the card issuer does. Rolling forward into
    the 1st instead would draw the renewal in the wrong month on the calendar
    and shift every date after it by one.
  */
  const jan31 = new Date(2026, 0, 31);
  check('31 January plus a month is 28 February', iso(addMonthsClamped(jan31, 1)) === '2026-02-28');
  check('plus two is 31 March', iso(addMonthsClamped(jan31, 2)) === '2026-03-31');
  check('plus three is 30 April', iso(addMonthsClamped(jan31, 3)) === '2026-04-30');
  // 2028 is a leap year: the same anchor reaches the 29th rather than the 28th.
  check('and February 2028 has a 29th', iso(addMonthsClamped(new Date(2028, 0, 31), 1)) === '2028-02-29');

  /* ------------------------------------------------------- next renewal */

  const monthly = sub({ anchorDate: '2026-01-15' });
  check(
    'before the anchor, the anchor is next',
    iso(nextRenewal(monthly, new Date(2026, 0, 1))) === '2026-01-15',
  );
  check(
    'on the day, today is next',
    iso(nextRenewal(monthly, new Date(2026, 0, 15))) === '2026-01-15',
  );
  check(
    'the day after, next month',
    iso(nextRenewal(monthly, new Date(2026, 0, 16))) === '2026-02-15',
  );
  check(
    'years later it still lands on the 15th',
    iso(nextRenewal(monthly, new Date(2029, 6, 20))) === '2029-08-15',
  );

  /*
    The one that breaks naive implementations: stepping from the *previous
    result* rather than the anchor means February's clamp to the 28th sticks,
    and every month after it renews on the 28th for ever.
  */
  const endOfMonth = sub({ anchorDate: '2026-01-31' });
  check(
    'a 31st anchor clamps in February',
    iso(nextRenewal(endOfMonth, new Date(2026, 1, 1))) === '2026-02-28',
  );
  check(
    'and comes back to the 31st in March',
    iso(nextRenewal(endOfMonth, new Date(2026, 2, 1))) === '2026-03-31',
  );
  check(
    'and is still the 31st in December',
    iso(nextRenewal(endOfMonth, new Date(2026, 11, 1))) === '2026-12-31',
  );

  const yearly = sub({ cadence: 'yearly', anchorDate: '2026-03-02' });
  check('a yearly plan skips a whole year', iso(nextRenewal(yearly, new Date(2026, 2, 3))) === '2027-03-02');
  const quarterly = sub({ cadence: 'quarterly', anchorDate: '2026-01-10' });
  check('a quarterly one steps three months', iso(nextRenewal(quarterly, new Date(2026, 0, 11))) === '2026-04-10');
  const weekly = sub({ cadence: 'weekly', anchorDate: '2026-01-05' });
  check('a weekly one steps seven days', iso(nextRenewal(weekly, new Date(2026, 0, 6))) === '2026-01-12');
  check('and keeps stepping', iso(nextRenewal(weekly, new Date(2026, 1, 1))) === '2026-02-02');

  check('a broken anchor has no next renewal', nextRenewal(sub({ anchorDate: 'x' })) === null);

  /* ------------------------------------------------------ days until */

  check('today is zero', daysUntilRenewal(monthly, new Date(2026, 0, 15)) === 0);
  check('tomorrow is one', daysUntilRenewal(monthly, new Date(2026, 0, 14)) === 1);
  check('never negative', (daysUntilRenewal(monthly, new Date(2026, 0, 16)) ?? -1) > 0);

  check('the label counts', renewalLabel(6) === 'Renews in 6 days');
  check('one day is named', renewalLabel(1) === 'Renews tomorrow');
  check('today says so', renewalLabel(0) === 'Renews today');

  /* ----------------------------------------------------- the arithmetic */

  /*
    The number this whole screen exists for. A yearly plan recorded as a
    monthly charge overstates the total twelvefold, and a weekly one counted as
    four weeks a month understates it by about 8% — both in the direction
    nobody notices.
  */
  check('monthly is itself', monthlyCents(sub({ amountCents: 1299 })) === 1299);
  check('yearly divides by twelve', monthlyCents(sub({ cadence: 'yearly', amountCents: 13900 })) === 1158);
  check('quarterly divides by three', monthlyCents(sub({ cadence: 'quarterly', amountCents: 3000 })) === 1000);
  const weeklyMonthly = monthlyCents(sub({ cadence: 'weekly', amountCents: 500 }));
  check('weekly is 52.18 a year, not 48', weeklyMonthly === 2174, `${weeklyMonthly}`);
  check('four-weeks would have said 2000', weeklyMonthly > 2000);
  check('nothing costs nothing', monthlyCents(sub({ amountCents: 0 })) === 0);

  const basket = [
    sub({ amountCents: 1299 }),
    sub({ cadence: 'yearly', amountCents: 13900 }),
    sub({ cadence: 'weekly', amountCents: 500 }),
  ];
  check('the monthly total adds up', totalMonthlyCents(basket) === 1299 + 1158 + 2174);
  check('and the yearly one', totalYearlyCents(basket) === 1299 * 12 + 13900 + Math.round(500 * (365.25 / 7)));

  /* ------------------------------------------------- the dashboard figures */

  /*
    The two totals answer different questions and must not be conflated. The
    monthly figure normalises — a yearly plan is a twelfth of itself. "Due this
    week" does not: the real charge, on its real date, at full price. Averaging
    a £139 annual renewal down to £11.58 on the Thursday it actually leaves
    would be the app telling you the wrong number on the one day it matters.
  */
  const week = [
    sub({ id: 'a', anchorDate: '2026-01-14', amountCents: 1299 }),
    sub({ id: 'b', cadence: 'yearly', anchorDate: '2026-01-16', amountCents: 13900 }),
    sub({ id: 'c', anchorDate: '2026-02-20', amountCents: 999 }),
  ];
  const soon = dueWithin(week, 7, new Date(2026, 0, 12));
  check('it counts only what lands this week', soon.count === 2, `${soon.count}`);
  check('at full price, not normalised', soon.cents === 1299 + 13900, `${soon.cents}`);
  check(
    'and the monthly total still averages the same plans',
    totalMonthlyCents(week) === 1299 + 1158 + 999,
  );

  check('a quiet week is empty', dueWithin(week, 1, new Date(2026, 0, 1)).count === 0);
  check('today counts as due', dueWithin(week, 0, new Date(2026, 0, 14)).count === 1);

  // The same money in the unit people feel.
  const perDay = dailyCents([sub({ amountCents: 3000 })]);
  check('a day rate comes off the year', Math.round(perDay) === Math.round(3000 * 12 / 365.25), `${perDay}`);
  check('nothing subscribed is nothing a day', dailyCents([]) === 0);

  // Compared by monthly cost, so a yearly plan doesn't win on sticker price.
  const top = biggest([
    sub({ id: 'small', cadence: 'yearly', amountCents: 6000 }),
    sub({ id: 'big', cadence: 'monthly', amountCents: 2000 }),
  ]);
  check('the largest is judged per month', top?.id === 'big', top?.id);
  check('and nothing has no largest', biggest([]) === null);

  /* ------------------------------------------------- the six-month chart */

  /*
    The chart exists to show what an average hides: that the months are not
    level. Everything below is a way of getting that wrong.
  */

  // A weekly plan is four or five charges a month, not "about four".
  const wk = sub({ cadence: 'weekly', anchorDate: '2026-01-01' });
  const jan = renewalsBetween(wk, new Date(2026, 0, 1), new Date(2026, 0, 31));
  check('January holds five weekly renewals', jan.length === 5, `${jan.length}`);
  check('and they are the 1st through the 29th', iso(jan[0]!) === '2026-01-01' && iso(jan[4]!) === '2026-01-29');
  const feb = renewalsBetween(wk, new Date(2026, 1, 1), new Date(2026, 1, 28));
  check('February holds four', feb.length === 4, `${feb.length}`);

  // A yearly plan is absent from eleven months out of twelve. If it leaked one
  // twelfth into every month the chart would be a flat line, which is exactly
  // the picture it was built to contradict.
  const annual = sub({ cadence: 'yearly', anchorDate: '2026-03-02', amountCents: 13900 });
  check('a yearly plan appears in March', renewalsBetween(annual, new Date(2026, 2, 1), new Date(2026, 2, 31)).length === 1);
  check('and in no other month', renewalsBetween(annual, new Date(2026, 3, 1), new Date(2026, 3, 30)).length === 0);
  check('and once a year, not twice', renewalsBetween(annual, new Date(2026, 0, 1), new Date(2026, 11, 31)).length === 1);

  // A 31st anchor must appear exactly once in a 30-day month, on the 30th —
  // not twice, and not skipped.
  const eom = sub({ anchorDate: '2026-01-31' });
  const apr = renewalsBetween(eom, new Date(2026, 3, 1), new Date(2026, 3, 30));
  check('a 31st anchor lands once in April', apr.length === 1, `${apr.length}`);
  check('on the 30th', iso(apr[0]!) === '2026-04-30');

  /*
    The whole point, as one assertion. Netflix every month and one annual plan
    in March: the monthly average says every month is the same, and the chart
    says March is nearly twelve times the others.
  */
  const lumpy = [sub({ id: 'n', amountCents: 1299 }), annual];
  const spend = spendByMonth(lumpy, 6, new Date(2026, 0, 15));
  check('six months come back', spend.length === 6);
  check('it starts at the current month', spend[0]!.month === 0 && spend[0]!.year === 2026);
  check('it crosses the year end', spendByMonth(lumpy, 6, new Date(2026, 9, 1))[3]!.year === 2027);
  check('an ordinary month is just Netflix', spend[0]!.cents === 1299, `${spend[0]!.cents}`);
  check('March carries the annual too', spend[2]!.cents === 1299 + 13900, `${spend[2]!.cents}`);
  check('and counts two charges', spend[2]!.count === 2);

  /*
    The current month is whole, including the part already spent. A first bar
    measuring "what's left" against five measuring "what it costs" is a chart
    that lies by construction — and on the 28th it would show almost nothing.
  */
  const late = spendByMonth([sub({ anchorDate: '2026-01-05', amountCents: 1299 })], 2, new Date(2026, 0, 28));
  check('a charge already taken still counts this month', late[0]!.cents === 1299, `${late[0]!.cents}`);

  check('the heaviest month is found', heaviest(spend)!.month === 2);
  check('and nothing has no heaviest', heaviest(spendByMonth([], 6, new Date(2026, 0, 1))) === null);

  // The caption is only written when there's something to say.
  check('a lumpy run reads as lumpy', spread(spend) > 1.4, `${spread(spend).toFixed(2)}`);
  const level = spendByMonth([sub({ amountCents: 1299 })], 6, new Date(2026, 0, 15));
  check('a level one does not', spread(level) === 1, `${spread(level)}`);
  check('and an empty one is level by definition', spread([]) === 1);

  /* --------------------------------------------------- when the clocks change */

  /*
    1 November 2026 is 25 hours long in New York. Everything here failed before
    `addDays` existed, and every failure was silent.
  */

  // A weekly plan anchored on a Monday renews on Mondays. Forever. Stepping by
  // 7 * 86,400,000 ms moved it to Sunday for the whole winter — the renewal
  // date on the card was simply wrong, one day early, from November to March.
  const monday = sub({ cadence: 'weekly', anchorDate: '2026-08-03' });
  check('the anchor is a Monday', new Date(2026, 7, 3).getDay() === 1);
  let allMonday = true;
  for (let w = 0; w < 40; w++) {
    const at = nextRenewal(monday, new Date(2026, 7, 4 + w * 7));
    if (!at || at.getDay() !== 1) allMonday = false;
  }
  check('and every renewal for forty weeks is too', allMonday);
  check(
    'the one straight after the clocks go back',
    iso(nextRenewal(monday, new Date(2026, 10, 2))) === '2026-11-02',
  );

  /*
    The loop that draws the chart. `cursor = at + 86,400,000` on the morning
    the clocks go back lands at 23:00 the SAME day, so the cursor never
    advanced, the same date came back four hundred times, and one month of the
    chart read $18,324 against a $135 average. The bar was so tall the other
    five months rendered as 1% and looked empty.
  */
  const nov = renewalsBetween(sub({ anchorDate: '2026-09-01' }), new Date(2026, 10, 1), new Date(2026, 10, 30));
  check('a monthly charge on the 1st of November happens once', nov.length === 1, `${nov.length}`);

  // The invariant behind it, which no timezone can break: a list of renewal
  // dates has no duplicates and never goes backwards.
  // 103 weeks after the anchor, inclusive of the anchor itself, is 104
  // renewals — no more from a 25-hour day, no fewer from a 23-hour one. The
  // window crosses four clock changes.
  const long = renewalsBetween(monday, new Date(2026, 7, 3), new Date(2026, 7, 3 + 103 * 7));
  check('104 renewals in 103 weeks', long.length === 104, `${long.length}`);
  check('strictly increasing, never repeating', long.every((d, i) => i === 0 || d > long[i - 1]!));
  check('and all of them Mondays', long.every((d) => d.getDay() === 1));

  // Spring forward, too — 8 March 2026 is 23 hours long.
  const spring = renewalsBetween(sub({ cadence: 'weekly', anchorDate: '2026-03-02' }), new Date(2026, 2, 1), new Date(2026, 2, 31));
  check('a 23-hour day loses no renewals either', spring.length === 5, `${spring.length}`);
  check('and they stay on Mondays', spring.every((d) => d.getDay() === 1));

  /* --------------------------------------------------------- what needs you */

  const jobs = subGaps(
    [
      sub({ id: 'w', anchorDate: '2026-01-14', amountCents: 1299 }),
      sub({ id: 'y', cadence: 'yearly', anchorDate: '2026-02-01', amountCents: 13900 }),
      sub({ id: 'q', cadence: 'quarterly', anchorDate: '2026-03-20', amountCents: 3000 }),
      sub({ id: 'm', anchorDate: '2026-02-25', amountCents: 999 }),
    ],
    new Date(2026, 0, 12),
  );
  check('this week is a job', jobs[0]?.kind === 'soon' && jobs[0].count === 1);
  check('priced at what actually leaves', jobs[0]?.cents === 1299);
  // The yearly plan is 20 days out; the quarterly is 67 and doesn't qualify,
  // and the ordinary monthly one is never a "large charge" whenever it lands.
  check('a lump with lead time is the other', jobs[1]?.kind === 'bigsoon' && jobs[1].count === 1, `${jobs[1]?.count}`);
  check('and it is the annual one', jobs[1]?.cents === 13900);

  /*
    The windows must not overlap. A yearly plan renewing on Friday is this
    week's problem and belongs in one line, not both — a dashboard that counts
    the same charge twice is a dashboard whose numbers can't be added up.
  */
  const both = subGaps([sub({ cadence: 'yearly', anchorDate: '2026-01-15', amountCents: 13900 })], new Date(2026, 0, 12));
  check('a lump due this week is counted once', both.length === 1 && both[0]!.kind === 'soon');

  check('a quiet fortnight has no jobs', subGaps([sub({ anchorDate: '2026-02-20' })], new Date(2026, 0, 12)).length === 0);
  check('and nothing subscribed has none either', subGaps([], new Date(2026, 0, 12)).length === 0);

  /* -------------------------------------------------------- reminders */

  const now = new Date(2026, 0, 12);
  check('no reminder set, nothing due', !dueReminders([sub({ anchorDate: '2026-01-13' })], now).length);
  check(
    'three days out with a 3-day reminder is due',
    dueReminders([sub({ anchorDate: '2026-01-15', remindDays: 3 })], now).length === 1,
  );
  check(
    'four days out is not',
    dueReminders([sub({ anchorDate: '2026-01-16', remindDays: 3 })], now).length === 0,
  );
  check(
    'the day itself is still due',
    dueReminders([sub({ anchorDate: '2026-01-12', remindDays: 1 })], now).length === 1,
  );

  // Soonest first: the one about to take money leads.
  const order = dueReminders(
    [
      sub({ id: 'a', name: 'Later', anchorDate: '2026-01-18', remindDays: 7 }),
      sub({ id: 'b', name: 'Sooner', anchorDate: '2026-01-13', remindDays: 7 }),
    ],
    now,
  ).map((s) => s.name);
  check('the closest renewal leads', order.join() === 'Sooner,Later', order.join());

  /* --------------------------------------------------------- calendar */

  /*
    Walked month by month rather than read off the anchor's day number, which
    is what lets a weekly plan appear four or five times and a yearly one
    appear in exactly one month of twelve.
  */
  const weeklyMarks = renewalsInMonth(
    [sub({ cadence: 'weekly', anchorDate: '2026-01-05' })],
    2026,
    0,
    new Date(2026, 0, 1),
  );
  check('a weekly plan marks four or five days', weeklyMarks.length >= 4, `${weeklyMarks.length}`);
  const yearlyInMarch = renewalsInMonth([yearly], 2026, 2, new Date(2026, 0, 1));
  const yearlyInApril = renewalsInMonth([yearly], 2026, 3, new Date(2026, 0, 1));
  check('a yearly plan marks its one month', yearlyInMarch.length === 1 && yearlyInMarch[0]!.day === 2);
  check('and no other', yearlyInApril.length === 0);

  check('ordinals read properly', ['1st', '2nd', '3rd', '4th', '11th', '21st', '22nd'].join() ===
    [1, 2, 3, 4, 11, 21, 22].map(ordinal).join());

  /* --------------------------------------------------------- catalogue */

  check('the catalogue is stocked', CATALOGUE.length === 56, `${CATALOGUE.length}`);
  // The form shows thirty tiles, so the catalogue has to have at least that
  // many before anyone types a letter.
  check('and covers the grid without searching', CATALOGUE.length >= 30);
  check('every one has a mark and a colour', CATALOGUE.every((s) => s.path && /^#[0-9A-Fa-f]{6}$/.test(s.colour)));
  check('ids are unique', new Set(CATALOGUE.map((s) => s.id)).size === CATALOGUE.length);
  check('search finds by prefix', searchServices('net').some((s) => s.id === 'netflix'));
  check('and ignores punctuation and case', searchServices('YOUTUBE').some((s) => s.id === 'youtube'));
  check('an empty search offers everything', searchServices('  ').length === CATALOGUE.length);

  check('initials come from the words', monogram('Bob’s Gym') === 'BG');
  check('one word gives two letters', monogram('Netflix') === 'NE');
  // Same colour on every device and after every restore, or the list changes
  // appearance for no reason the user can see.
  check('the fallback colour is stable', monogramColour('Bob’s Gym') === monogramColour('Bob’s Gym'));

  /*
    Nothing fetches a logo any more — the app makes no network requests at all,
    which is the claim the privacy page makes and now the whole truth. Anything
    outside the catalogue gets initials.
  */
  check('an unknown service still gets a mark', monogram('Bob’s Gym').length === 2);

  /* ------------------------------------------------ the record and the cap */

  const id = await createSubscription({
    propertyId: property.id,
    name: 'Spotify',
    serviceId: 'spotify',
    cadence: 'monthly',
    anchorDate: '2026-02-09',
    amountCents: 1199,
    currency: 'USD',
  });
  const stored = (await db.subscriptions.get(id))!;
  check('it is stamped current', stored.schemaVersion === SCHEMA_VERSION, `${stored.schemaVersion}`);
  check('and listed', (await activeSubscriptions(property.id)).length === 1);

  /*
    Subscriptions do not count against the free tier. The cap prices storage —
    photos, receipts, scans — and a subscription is forty bytes with no
    attachments.
  */
  const items = await activeItemCount(property.id);
  check(
    'they are outside the item cap',
    canAddItem(items, { proUnlock: false, reportUnlock: false }) === items < FREE_ITEM_LIMIT,
  );
  check('and the item count ignores them', (await activeItemCount(property.id)) === items);

  /* ------------------------------------------------- through a backup */

  /*
    Subscriptions are the seventh table in a bundle, appended rather than
    inserted — a missing file contributes zero bytes to the checksum, so every
    backup written before they existed still verifies. Both halves of that are
    worth pinning: the new table survives a round trip, and an older bundle is
    still accepted.
  */
  const bundle = await exportBundle();
  const parsed = await parseBundle(bundle.blob);
  check('the bundle carries them', parsed.data.subscriptions.length === 1, `${parsed.data.subscriptions.length}`);
  check('with the anchor intact', parsed.data.subscriptions[0]!.anchorDate === '2026-02-09');
  check('and the service it was matched to', parsed.data.subscriptions[0]!.serviceId === 'spotify');

  await db.subscriptions.clear();
  check('cleared', (await activeSubscriptions(property.id)).length === 0);
  await restoreBundle(parsed, 'merge');
  const back = (await activeSubscriptions(property.id))[0];
  check('a restore brings it back', back?.name === 'Spotify', back?.name);
  check('with its cost', back?.amountCents === 1199);
  check('and its cadence', back?.cadence === 'monthly');

  await deleteSubscription(id);
  check('deleting takes it away for good', (await db.subscriptions.get(id)) === undefined);
  check('and the list is empty', (await activeSubscriptions(property.id)).length === 0);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
