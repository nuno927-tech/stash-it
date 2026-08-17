/**
 * The merged timeline, and the ring that sits above it.
 *
 *   npm run test:timeline
 *
 * Everything here is about ordering. The dashboard used to keep three separate
 * "next up" rows, one per kind, each sorted only against its own — so the
 * question "what should I deal with" had three answers and no way to compare
 * them. These checks are the comparison.
 */

// Dates, so: pinned. See the note at the top of subs.test.ts.
process.env.TZ = 'America/New_York';

import 'fake-indexeddb/auto';
import { SCHEMA_VERSION, type Item, type Paper, type Subscription } from '@/db/types';
import { buildTimeline, datedTally, flaggedCount, sortTimeline, whenLabel, type Entry } from '@/lib/timeline';
import { setEndingSoonDays } from '@/lib/warranty';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const NOW = new Date(2026, 7, 17); // 17 August 2026

function item(over: Partial<Item> = {}): Item {
  return {
    id: 'i',
    schemaVersion: SCHEMA_VERSION,
    propertyId: 'p',
    name: 'Thing',
    createdAt: '',
    updatedAt: '',
    ...over,
  };
}

/** An item bought `ago` days back with a term in months. */
function warranted(name: string, months: number, ago: number): Item {
  const bought = new Date(NOW.getFullYear(), NOW.getMonth(), NOW.getDate() - ago);
  const iso = `${bought.getFullYear()}-${String(bought.getMonth() + 1).padStart(2, '0')}-${String(bought.getDate()).padStart(2, '0')}`;
  return item({ id: name, name, purchaseDate: iso, warranty: { months, unit: 'months', amount: months } });
}

function sub(over: Partial<Subscription> = {}): Subscription {
  return {
    id: 's',
    schemaVersion: SCHEMA_VERSION,
    propertyId: 'p',
    name: 'Netflix',
    cadence: 'monthly',
    anchorDate: '2026-08-22',
    amountCents: 1549,
    currency: 'USD',
    createdAt: '',
    updatedAt: '',
    ...over,
  };
}

function paper(over: Partial<Paper> = {}): Paper {
  return {
    id: 'd',
    schemaVersion: SCHEMA_VERSION,
    propertyId: 'p',
    kind: 'passport',
    label: 'Passport',
    expiresOn: '2027-02-11',
    createdAt: '',
    updatedAt: '',
    ...over,
  };
}

const keys = (e: Entry[]) => e.map((x) => x.key).join(' → ');

function main() {
  // The app's own "ending soon" window, so the fixtures and the dashboard
  // agree about which warranties are worth mentioning.
  setEndingSoonDays(30);

  /* ------------------------------------------------- the ordering, in full */

  /*
    THE CASE THE FILE EXISTS FOR. Chronologically this list runs Netflix (5
    days), MOT (already gone), passport (already needed starting). By date the
    direct debit leads and the cancelled holiday is third.
  */
  const line = buildTimeline(
    [warranted('Headphones', 24, 710)], // ~20 days of cover left
    [sub({ id: 'nflx', name: 'Netflix', anchorDate: '2026-08-22' })],
    [
      paper({ id: 'mot', kind: 'vehicle', label: 'MOT', holder: 'Golf', expiresOn: '2026-07-10' }),
      paper({ id: 'pp', label: 'Passport', holder: 'Nuno', expiresOn: '2027-02-11' }),
    ],
    NOW,
  );

  check('everything lands in one list', line.length === 4, keys(line));
  check('the expired document leads', line[0]?.key === 'paper:mot', keys(line));
  check('then the one that needs starting', line[1]?.key === 'paper:pp', keys(line));
  check(
    'and the direct debit comes after both, despite being sooner',
    line.findIndex((e) => e.key === 'sub:nflx') > 1,
    keys(line),
  );

  /*
    Which is only interesting because it IS sooner. If the ranking were
    chronological this assertion would be the other way round.
  */
  const nflx = line.find((e) => e.key === 'sub:nflx')!;
  const mot = line.find((e) => e.key === 'paper:mot')!;
  check('the MOT is further from today than Netflix is', Math.abs(mot.days) > nflx.days, `${mot.days} vs ${nflx.days}`);

  /* -------------------------------------------------------------- flagging */

  check('overdue and needs-starting are flagged', mot.flagged && line[1]!.flagged);
  check('an ordinary renewal is not', !nflx.flagged);
  check('two things need doing', flaggedCount(line) === 2, `${flaggedCount(line)}`);

  /*
    A reminder is now the only thing that lifts a renewal out of the ordinary
    run of them, and it does it by moving the row rather than by adding a
    second card higher up the page.
  */
  const reminded = buildTimeline([], [sub({ id: 'r', remindDays: 7 })], [], NOW);
  check('a reminder due promotes the row', reminded[0]?.urgency === 'now', reminded[0]?.urgency);
  check('and flags it', reminded[0]?.flagged === true);
  const quiet = buildTimeline([], [sub({ id: 'q', remindDays: 1 })], [], NOW);
  check('a reminder not yet due does neither', quiet[0]?.urgency !== 'now' && !quiet[0]?.flagged);

  /* ------------------------------------------------ the right-hand column */

  check('an overdue row says how late', whenLabel({ urgency: 'overdue', days: -38 }) === '38 days late');
  check('a countdown counts', whenLabel({ urgency: 'soon', days: 5 }) === '5 days');
  check('one day is named', whenLabel({ urgency: 'soon', days: 1 }) === 'tomorrow');
  check('and today is', whenLabel({ urgency: 'soon', days: 0 }) === 'today');

  /*
    THE ONE A REALISTIC LIST CAUGHT. A passport inside its lead time passed its
    renew-by months ago, so `days` is a large negative number — and the obvious
    `days <= 0 ? 'today'` printed "today" beside a document that needed
    starting in June. "68 days late" is no better: the passport does not expire
    until February, so nothing is actually late. The window is open, which is a
    state and not a duration.
  */
  check('a wide-open window is not a countdown', whenLabel({ urgency: 'now', days: -68 }) === 'now');
  check('nor is a fresh one', whenLabel({ urgency: 'now', days: 0 }) === 'now');
  const openWindow = buildTimeline([], [], [paper({ id: 'w', holder: 'Nuno', expiresOn: '2027-02-11' })], NOW);
  check('and a real passport takes that path', whenLabel(openWindow[0]!) === 'now', `${openWindow[0]?.days}`);

  /* ---------------------------------------------------- what is left out */

  /*
    A lapsed warranty is not an action. The cover is gone and the item is still
    yours; putting every one at the top would bury the things that are still
    saveable under the things that aren't. A lapsed PASSPORT is a problem you
    still have to solve, so that one does appear — the asymmetry is the point.
  */
  const lapsed = buildTimeline([warranted('Old kettle', 12, 900)], [], [], NOW);
  check('a lapsed warranty is not in the list', lapsed.length === 0, keys(lapsed));
  const deadPaper = buildTimeline([], [], [paper({ id: 'x', expiresOn: '2026-01-01' })], NOW);
  check('a lapsed document is', deadPaper.length === 1 && deadPaper[0]!.urgency === 'overdue');

  // Cover that runs for years is not news either.
  check('a warranty years out stays quiet', buildTimeline([warranted('Fridge', 60, 30)], [], [], NOW).length === 0);

  // Beyond the horizon, a renewal and a document are both left alone.
  check('a renewal past the horizon is out', buildTimeline([], [sub({ cadence: 'yearly', anchorDate: '2027-06-01' })], [], NOW).length === 0);
  check(
    'so is a document with a year of runway',
    buildTimeline([], [], [paper({ kind: 'insurance', expiresOn: '2028-06-01' })], NOW).length === 0,
  );

  // An unreadable date can't be placed on a timeline, and inventing a position
  // for it would put it somewhere confident and wrong.
  check('a document with no date is skipped', buildTimeline([], [], [paper({ expiresOn: '' })], NOW).length === 0);

  /* --------------------------------------------------------------- naming */

  check('a document says whose it is', line[1]?.title === 'Passport — Nuno', line[1]?.title);
  check(
    'and drops the dash when nobody is named',
    buildTimeline([], [], [paper({ id: 'n', expiresOn: '2026-09-01' })], NOW)[0]?.title === 'Passport',
  );

  /* ------------------------------------------------------------- stability */

  /*
    Two entries in the same bucket on the same day must not swap places between
    renders. A list that reorders itself while you look at it reads as broken.
  */
  const tied = buildTimeline(
    [],
    [sub({ id: 'b', name: 'Bravo' }), sub({ id: 'a', name: 'Alpha' })],
    [],
    NOW,
  );
  check('ties break alphabetically', tied.map((e) => e.title).join() === 'Alpha,Bravo', tied.map((e) => e.title).join());
  check('and sorting is idempotent', keys(sortTimeline(sortTimeline(tied))) === keys(tied));

  /* ------------------------------------------------------------- the ring */

  /*
    SUBSCRIPTIONS ARE NOT IN THE RING, and the signature is the proof — it does
    not take them. A subscription cannot lapse: it renews, and renews again.
    Counting nine as nine healthy units would make the score rise when you take
    on a service and fall when you cancel one, which is backwards.
  */
  const tally = datedTally(
    [
      warranted('Fridge', 60, 30), // covered
      warranted('Headphones', 24, 710), // ending soon
      warranted('Old kettle', 12, 900), // lapsed
      item({ id: 'blank', name: 'Lamp' }), // no term at all
    ],
    [
      paper({ id: 'ok', expiresOn: '2031-01-01' }),
      paper({ id: 'due', expiresOn: '2026-10-01' }),
      paper({ id: 'gone', expiresOn: '2026-01-01' }),
      paper({ id: 'nodate', expiresOn: '' }),
    ],
    NOW,
  );

  check('in date counts both kinds', tally.inDate === 2, `${tally.inDate}`);
  check('so does needs-starting', tally.needsStarting === 2, `${tally.needsStarting}`);
  check('and lapsed', tally.lapsed === 2, `${tally.lapsed}`);
  check('undated records are counted separately', tally.noDate === 2, `${tally.noDate}`);

  /*
    The divisor is the tracked three, not everything. Including blanks would
    mean the score DROPS when you add a record with a date missing — punishing
    the one behaviour the app is trying to encourage — and the green wedge
    would stop matching the headline number.
  */
  check('the percentage divides by what is tracked', tally.percent === 33, `${tally.percent}`);

  const before = datedTally([warranted('Fridge', 60, 30)], [], NOW).percent;
  const after = datedTally([warranted('Fridge', 60, 30), item({ id: 'z', name: 'Lamp' })], [], NOW).percent;
  check('adding an undated record cannot lower the score', after === before, `${before} → ${after}`);

  check('nothing tracked is zero, not a divide by zero', datedTally([], [], NOW).percent === 0);
  check('and it reports the raw counts too', tally.items === 4 && tally.papers === 4);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
