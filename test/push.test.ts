/**
 * Reminders: which days wake the phone, and what is said when it does.
 *
 *   npm run test:push
 *
 * The privacy design lives or dies on one property, and it is asserted here:
 * the schedule that would be uploaded contains DATES AND NOTHING ELSE. Every
 * word of a notification is composed on the device and never leaves it.
 */

// Dates, so: pinned. See the note at the top of subs.test.ts.
process.env.TZ = 'America/New_York';

import 'fake-indexeddb/auto';
import { SCHEMA_VERSION, type Item, type Paper, type Subscription } from '@/db/types';
import { compose, pushSchedule, verdict, vapidBytes, wakeDates, wakeTimes, noteFor } from '@/lib/push';
import { MAX_WAKES, syncDue, syncPayload, wakesChanged } from '@/lib/pushSync';
import { setEndingSoonDays } from '@/lib/warranty';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const NOW = new Date(2026, 7, 17); // 17 August 2026

function warranted(name: string, months: number, ago: number): Item {
  const bought = new Date(NOW.getFullYear(), NOW.getMonth(), NOW.getDate() - ago);
  const iso = `${bought.getFullYear()}-${String(bought.getMonth() + 1).padStart(2, '0')}-${String(bought.getDate()).padStart(2, '0')}`;
  return {
    id: name,
    schemaVersion: SCHEMA_VERSION,
    propertyId: 'p',
    name,
    purchaseDate: iso,
    warranty: { months, unit: 'months', amount: months },
    createdAt: '',
    updatedAt: '',
  } as Item;
}

function sub(over: Partial<Subscription> = {}): Subscription {
  return {
    id: 's',
    schemaVersion: SCHEMA_VERSION,
    propertyId: 'p',
    name: 'Netflix',
    cadence: 'monthly',
    anchorDate: '2026-09-01',
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
    expiresOn: '2027-06-15',
    createdAt: '',
    updatedAt: '',
    ...over,
  };
}

function main() {
  setEndingSoonDays(30);

  /* ------------------------------------------------------ what earns a wake */

  /*
    A DOCUMENT wakes you on its renew-by date — the day it stops being fine and
    starts being "start now". Not its expiry: by then the point has gone, which
    is the mistake the whole papers feature exists to avoid.
  */
  const doc = pushSchedule([], [], [paper({ expiresOn: '2026-10-01', leadDays: 30 })], NOW);
  check('a document wakes you on its renew-by', doc[0]?.on === '2026-09-01', doc[0]?.on);
  check('not on its expiry', !doc.some((w) => w.on === '2026-10-01'));

  /*
    A WARRANTY wakes you the day it enters the ending-soon window — the same
    threshold the ring and the list use, so the dashboard and the notification
    can never disagree about what counts as soon.
  */
  const warranty = pushSchedule([warranted('Headphones', 24, 690)], [], [], NOW);
  check('a warranty wakes you when it turns amber', warranty.length === 1, `${warranty.length}`);

  /*
    A SUBSCRIPTION WAKES YOU ONLY IF YOU ASKED. Nine monthly services would
    otherwise mean nine notifications a month for money that leaves whether you
    know or not — which is how people learn to swipe reminders away.
  */
  check('a plain renewal wakes nobody', pushSchedule([], [sub()], [], NOW).length === 0);
  const asked = pushSchedule([], [sub({ remindDays: 3 })], [], NOW);
  check('one with a reminder does', asked[0]?.on === '2026-08-29', asked[0]?.on);

  /* ------------------------------------------------------------- the window */

  check('nothing beyond the horizon', pushSchedule([], [], [paper({ expiresOn: '2030-01-01' })], NOW).length === 0);
  // Yesterday's threshold has already passed; the dashboard is carrying it.
  const gone = pushSchedule([], [], [paper({ id: 'g', expiresOn: '2026-08-16', leadDays: 0 })], NOW);
  check('nothing already behind us', gone.length === 0, gone[0]?.on);
  // Today does count — something crossing this morning is what a reminder is for.
  const today = pushSchedule([], [], [paper({ id: 't', expiresOn: '2026-08-17', leadDays: 0 })], NOW);
  check('but today does', today[0]?.on === '2026-08-17', today[0]?.on);

  check('an unreadable date is skipped', pushSchedule([], [], [paper({ expiresOn: '' })], NOW).length === 0);

  /* -------------------------------------------------------------- the words */

  check('one thing is named', compose(['Passport — Nuno']).title === 'Passport — Nuno');
  check('and says where to look', compose(['A']).body === 'Needs a look in Stash it.');

  const two = compose(['MOT — Golf', 'Passport — Nuno']);
  check('two are counted and both named', two.title === '2 things need you', two.title);
  check('joined with an and', two.body === 'MOT — Golf and Passport — Nuno', two.body);

  /*
    Two named and the rest counted. A lock screen truncates, so five names
    become three and an ellipsis — which is a worse version of saying "and 3
    more" deliberately.
  */
  const five = compose(['E', 'D', 'C', 'B', 'A']);
  check('five are two and a count', five.body === 'A, B and 3 more', five.body);
  check('sorted, so the same day reads the same twice', compose(['B', 'A']).body === 'A and B');

  /*
    NAMES, NOT DETAIL. A lock screen is readable by anyone holding the phone,
    so the notification says which thing and not what about it. Everything else
    is one tap into an app that can ask for a fingerprint first.
  */
  const named = pushSchedule([], [], [paper({ expiresOn: '2026-10-01', leadDays: 30, holder: 'Nuno' })], NOW);
  check('a document is named with its holder', named[0]?.title === 'Passport — Nuno', named[0]?.title);
  check('and carries no date in the text', !/\d/.test(named[0]!.title + named[0]!.body), named[0]?.body);

  /* ------------------------------- the property the privacy claim rests on */

  /*
    THE ONE THAT MATTERS. Only the dates would ever be uploaded. If this ever
    starts carrying a title, a name or an amount, the design has quietly become
    an ordinary cloud reminder service and the copy on the settings card has
    become a lie.
  */
  const mixed = pushSchedule(
    [warranted('Headphones', 24, 690)],
    [sub({ name: 'Netflix', remindDays: 3 })],
    [paper({ expiresOn: '2026-10-01', leadDays: 30, holder: 'Nuno' })],
    NOW,
  );
  const uploaded = wakeDates(mixed);
  check('what leaves is a list of strings', uploaded.every((d) => typeof d === 'string'));
  check('every one a bare date', uploaded.every((d) => /^\d{4}-\d{2}-\d{2}$/.test(d)), uploaded.join(' '));

  const asText = JSON.stringify(uploaded);
  check('no item name is in it', !asText.includes('Headphones'), asText);
  check('no service name either', !asText.includes('Netflix'), asText);
  check('nor a document or a person', !asText.includes('Passport') && !asText.includes('Nuno'), asText);

  // Day granularity, never a timestamp: the hour you did something is itself
  // information, and nothing here needs it.
  check('no times, only days', !asText.includes('T') && !asText.includes(':'), asText);

  /* ------------------------------------------------------- reading it back */

  check('today’s note is found', noteFor(mixed, new Date(2026, 8, 1))?.on === '2026-09-01');
  check('and a quiet day has none', noteFor(mixed, new Date(2026, 8, 2)) === null);

  /* --------------------------------------------------- what is uploaded */

  /*
    THE PAYLOAD, ASSERTED AS A WHOLE. Not "does it contain a name" — that only
    catches the fields you thought to check. This pins the complete set of keys,
    so ANY addition fails here and has to be argued for rather than slipped in.
  */
  const browserSub = {
    endpoint: 'https://fcm.googleapis.com/wp/abc123',
    keys: { p256dh: 'BPk...', auth: 'k9s...' },
    expirationTime: null,
  };
  const payload = syncPayload(browserSub, mixed)!;
  check('the payload has exactly three keys', Object.keys(payload).sort().join() === 'endpoint,keys,wakes', Object.keys(payload).join());
  check('and the keys object exactly two', Object.keys(payload.keys).sort().join() === 'auth,p256dh');

  const wire = JSON.stringify(payload);
  for (const secret of ['Headphones', 'Netflix', 'Passport', 'Nuno', '1549', 'renew', 'needs']) {
    check(`no "${secret}" on the wire`, !wire.includes(secret));
  }

  check('a subscription with no keys is refused', syncPayload({ endpoint: 'x', expirationTime: null }, mixed) === null);

  /*
    Instants, not dates, and this is a deliberate loosening of the phase 1
    shape. The sender has to know when your morning is or it fires at a fixed
    hour UTC, which is the middle of the night for most of the world. The cost
    is that the hour reveals a rough offset; the alternative is a reminder
    nobody keeps switched on.
  */
  check('wakes are epoch seconds', payload.wakes.every((n) => Number.isInteger(n) && n > 1_700_000_000));
  check('sorted', payload.wakes.every((n, i, a) => i === 0 || n >= a[i - 1]!));

  const nine = new Date(wakeTimes([{ on: '2026-09-04', title: 't', body: 'b' }], 9)[0]! * 1000);
  check('and land at the hour asked for, locally', nine.getHours() === 9, `${nine.getHours()}`);
  check('on the right day', nine.getDate() === 4 && nine.getMonth() === 8);

  // The cap is a fingerprint guard as much as a size one — see MAX_WAKES.
  const many = Array.from({ length: 80 }, (_, i) => ({ on: `2026-09-${String((i % 28) + 1).padStart(2, '0')}`, title: 't', body: 'b' }));
  check('a long list is truncated', syncPayload(browserSub, many)!.wakes.length === MAX_WAKES, `${syncPayload(browserSub, many)!.wakes.length}`);

  /* ------------------------------------------------------- when it syncs */

  /*
    Weekly, not on every change. A sender told the moment anything changes can
    watch you use the app — the times of day, an evening spent entering
    receipts. None of that is in the payload and all of it is in the timing.
  */
  check('never synced means due', syncDue(undefined));
  check('yesterday is not', !syncDue(new Date(Date.now() - 86_400_000).toISOString()));
  check('but eight days ago is', syncDue(new Date(Date.now() - 8 * 86_400_000).toISOString()));
  check('and a corrupt stamp is', syncDue('not a date'));

  check('an unchanged list is not worth a request', !wakesChanged([1, 2, 3], [1, 2, 3]));
  check('a changed one is', wakesChanged([1, 2, 3], [1, 2, 4]));
  check('so is a shorter one', wakesChanged([1, 2], [1, 2, 3]));

  /* ----------------------------------------------------------- the verdict */

  const base = { supported: true, iosBrowser: false, standalone: false, permission: 'default' as const, hasKey: true };
  check('a capable browser is ready', verdict(base) === 'ready');
  check('no support is said plainly', verdict({ ...base, supported: false }) === 'unsupported');
  check('a blocked permission is its own answer', verdict({ ...base, permission: 'denied' }) === 'denied');
  check('and an unconfigured build is too', verdict({ ...base, hasKey: false }) === 'no-key');

  /*
    iOS is checked BEFORE the key, and the order is the point. Web push there
    only exists for a PWA on the Home Screen, so "add it to your Home Screen"
    is a step the user can take — while "this build has no key" is not their
    problem and not their fix.
  */
  const iphone = { ...base, iosBrowser: true, standalone: false, hasKey: false };
  check('an iPhone in Safari is told to install', verdict(iphone) === 'needs-install');
  check('and once installed, it proceeds normally', verdict({ ...iphone, standalone: true }) === 'no-key');

  /* --------------------------------------------------------- the VAPID key */

  // base64url — '-' and '_' rather than '+' and '/', and no padding. Getting
  // this wrong produces a subscription the push service silently never uses.
  const bytes = vapidBytes('BFy-abc_123');
  check('the key decodes to bytes', bytes instanceof Uint8Array && bytes.length > 0, `${bytes.length}`);
  check('over a real ArrayBuffer', bytes.buffer instanceof ArrayBuffer);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
