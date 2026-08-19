/**
 * Search matching and ranking.
 *
 *   npm run test:search
 *
 * Pure functions over fixtures — no database needed. The cases that matter are
 * the ones a person actually hits: half a serial read off a plate, an accent
 * they didn't type, and two words that live in different fields.
 */

import type { Doc, Item, Paper, Room, Subscription } from '@/db/types';
import { matchSummary, normalize, searchAll, terms } from '@/lib/search';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const ts = '2026-01-01T00:00:00.000Z';

function item(over: Partial<Item> & { name: string }): Item {
  return {
    id: over.name.toLowerCase().replace(/\s+/g, '-'),
    schemaVersion: 1,
    propertyId: 'p1',
    createdAt: ts,
    updatedAt: ts,
    ...over,
  };
}

const rooms: Room[] = [
  { id: 'r-kitchen', propertyId: 'p1', name: 'Kitchen', sortOrder: 1, isSeed: true, createdAt: ts, updatedAt: ts },
  { id: 'r-garage', propertyId: 'p1', name: 'Garage', sortOrder: 2, isSeed: true, createdAt: ts, updatedAt: ts },
];

const items: Item[] = [
  item({
    name: 'Bosch Dishwasher',
    brand: 'Bosch',
    model: 'SHXM4AY55N',
    serial: 'FD-9401-22817',
    retailer: "Lowe's",
    roomId: 'r-kitchen',
    warranty: { months: 24, provider: 'Bosch Home', policyNumber: 'BH-77123' },
    notes: 'Installed by Kelly Plumbing',
  }),
  item({
    name: 'DeWalt Table Saw',
    brand: 'DeWalt',
    model: 'DWE7491RS',
    roomId: 'r-garage',
  }),
  item({ name: 'Séries 8 Oven', brand: 'Bosch', roomId: 'r-kitchen', category: 'appliance' }),
  item({ name: 'Deleted Thing', deletedAt: ts }),
  item({ name: 'Kitchen Scales', category: 'other' }),
];

const docs: Doc[] = [
  {
    id: 'd1',
    schemaVersion: 1,
    itemId: 'dewalt-table-saw',
    kind: 'warranty',
    title: 'Extended cover certificate',
    storageMode: 'local',
    blobId: 'b1',
    createdAt: ts,
    updatedAt: ts,
  },
  {
    id: 'd2',
    schemaVersion: 1,
    itemId: 'bosch-dishwasher',
    kind: 'receipt',
    title: 'Gone receipt',
    storageMode: 'local',
    blobId: 'b2',
    createdAt: ts,
    updatedAt: ts,
    deletedAt: ts,
  },
];

const papers: Paper[] = [
  {
    id: 'pp',
    schemaVersion: 1,
    propertyId: 'p1',
    kind: 'passport',
    label: 'Passport',
    holder: 'Nuno',
    authority: 'HM Passport Office',
    storedAt: 'Desk drawer',
    expiresOn: '2027-02-11',
    createdAt: ts,
    updatedAt: ts,
  },
  {
    id: 'mot',
    schemaVersion: 1,
    propertyId: 'p1',
    kind: 'vehicle',
    label: 'MOT',
    holder: 'Golf',
    expiresOn: '2026-07-10',
    createdAt: ts,
    updatedAt: ts,
  },
  { id: 'gone', schemaVersion: 1, propertyId: 'p1', kind: 'passport', label: 'Old passport', expiresOn: '2020-01-01', createdAt: ts, updatedAt: ts, deletedAt: ts },
];

const subs: Subscription[] = [
  {
    id: 'nflx',
    schemaVersion: 1,
    propertyId: 'p1',
    name: 'Netflix',
    cadence: 'monthly',
    anchorDate: '2026-08-22',
    amountCents: 1549,
    currency: 'USD',
    notes: 'Shared with Kelly',
    createdAt: ts,
    updatedAt: ts,
  },
];

const input = { items, docs, rooms, papers, subs };
const names = (q: string) => searchAll(q, input).map((h) => h.title);

/* ---------------------------------------------------------- normalising */

check('accents fold', normalize('Séries') === 'series', normalize('Séries'));
check('terms split on whitespace', terms('  bosch   kitchen ').join('|') === 'bosch|kitchen');
check('an empty query returns nothing', searchAll('   ', input).length === 0);

/* -------------------------------------------------------------- basics */

check('finds by name', names('dishwasher')[0] === 'Bosch Dishwasher', names('dishwasher').join(', '));
check('finds by brand', names('dewalt')[0] === 'DeWalt Table Saw');
check('finds by model', names('DWE7491')[0] === 'DeWalt Table Saw');
check('is case-insensitive', names('BOSCH').length === 2, names('BOSCH').join(', '));
check('accented names answer to unaccented queries', names('series')[0] === 'Séries 8 Oven');

/* ------------------------------------------------------------- serials */

check('partial serial matches', names('22817')[0] === 'Bosch Dishwasher', names('22817').join(', '));
check(
  'serial punctuation is ignored',
  names('fd940122817')[0] === 'Bosch Dishwasher',
  names('fd940122817').join(', '),
);
check('model punctuation is ignored', names('shxm-4ay55n')[0] === 'Bosch Dishwasher');

/* ------------------------------------------------- other fields, docs */

check('finds by room', names('garage')[0] === 'DeWalt Table Saw');
check('finds by retailer', names('lowe')[0] === 'Bosch Dishwasher');
check('finds by notes', names('kelly')[0] === 'Bosch Dishwasher');
check('finds by warranty provider', names('BH-77123')[0] === 'Bosch Dishwasher');
check('finds by document title', names('certificate')[0] === 'DeWalt Table Saw');
check('a deleted document does not match', names('gone receipt').length === 0);

/* ---------------------------------------------------------- AND terms */

check(
  'two terms across two fields',
  names('bosch kitchen').length === 2,
  names('bosch kitchen').join(', '),
);
check('every term must match', names('bosch garage').length === 0);
check(
  'name plus room narrows',
  names('dishwasher kitchen').join(',') === 'Bosch Dishwasher',
  names('dishwasher kitchen').join(', '),
);

/* ----------------------------------------------------------- excludes */

check('soft-deleted items never appear', names('deleted').length === 0);

/* ------------------------------------------------------------ ranking */

// "kitchen" hits one item's name and two others' room. The name must win.
check(
  'a name match outranks a room match',
  names('kitchen')[0] === 'Kitchen Scales',
  names('kitchen').join(', '),
);

const boschHits = searchAll('bosch', input);
check(
  'an exact brand match outranks a substring',
  boschHits[0]!.title === 'Bosch Dishwasher',
  boschHits.map((h) => `${h.title}:${Math.round(h.score)}`).join(', '),
);
check('scores descend', boschHits.every((h, i) => i === 0 || h.score <= boschHits[i - 1]!.score));

/* ------------------------------------------------------------ summary */

check('a name-only match explains nothing', matchSummary(searchAll('dishwasher', input)[0]!) === null);
check(
  'a serial match says so',
  matchSummary(searchAll('22817', input)[0]!) === 'Matched on serial number',
  String(matchSummary(searchAll('22817', input)[0]!)),
);
check(
  'a document match says so',
  matchSummary(searchAll('certificate', input)[0]!) === 'Matched on a document',
  String(matchSummary(searchAll('certificate', input)[0]!)),
);

/* ------------------------------------------------------------- safety */

check('regex metacharacters are literal, not wildcards', searchAll('a.*', input).length === 0);
check('a wildcard-looking query matches nothing', searchAll('.*', input).length === 0);
check('a lone bracket does not throw', searchAll('[', input).length === 0);
check('short punctuation-stripped terms do not run wild', searchAll('n-', input).length === 0);

/* ------------------------------------------------------ all three kinds */

/*
  THE GAP THIS CLOSED. The one search field in the app lived on the Items tab
  and only ever looked at items, which was right until the app grew two more
  tables. Typing "passport" returned nothing — and an empty result does not
  read as "wrong tab", it reads as the app having lost your passport.
*/
check('a document is findable at all', names('passport').includes('Passport'), names('passport').join(', '));
check('by the kind, not just the label', names('mot').includes('MOT'));
check('by who it belongs to', names('nuno').includes('Passport'));
check('by who issued it', names('hm passport office').includes('Passport'));
check('and by where it is kept', names('drawer').includes('Passport'));

check('a subscription is findable', names('netflix').includes('Netflix'));
check('and by its notes', names('kelly plumbing').includes('Bosch Dishwasher'));

// Deleted records stay deleted, whatever table they are in.
check('a deleted document does not surface', !names('old passport').includes('Old passport'));

/*
  ONE LIST, RANKED TOGETHER, not three lists stacked. Someone searching a word
  wants the closest match to it and neither knows nor cares which table it came
  from — "golf" is the car's MOT, and it beats the notes of a dishwasher.
*/
const golf = searchAll('golf', input);
check('kinds compete on the same scale', golf[0]?.title === 'MOT', golf.map((h) => h.title).join(', '));
check('and each result knows what it is', golf[0]?.kind === 'paper', golf[0]?.kind);

// A word that hits two kinds returns both, so the badge in the UI is the only
// thing telling them apart — which is why it exists.
const kelly = searchAll('kelly', input);
check('a word can match across kinds', new Set(kelly.map((h) => h.kind)).size === 2, kelly.map((h) => `${h.kind}:${h.title}`).join(', '));

check(
  'the why-line names a document field',
  matchSummary(searchAll('drawer', input)[0]!) === 'Matched on where it is kept',
  String(matchSummary(searchAll('drawer', input)[0]!)),
);

// Every term still has to land, whatever mix of kinds is in play.
check('two words that never co-occur find nothing', searchAll('passport netflix', input).length === 0);
check('two words on one document do', names('passport nuno').includes('Passport'));

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
