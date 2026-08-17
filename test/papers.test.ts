/**
 * Papers: documents that expire, and when they actually need dealing with.
 *
 *   npm run test:papers
 *
 * The one idea worth testing here is that the printed expiry date is not the
 * date that matters. Every assertion below is some version of "did the lead
 * time get applied, and did it get applied to the right thing".
 */

// Pinned before anything imports, for the reason spelled out in subs.test.ts:
// these are date calculations, and a UTC machine never sees a 25-hour day.
process.env.TZ = 'America/New_York';

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import { activePapers, createPaper, deletePaper, updatePaper, canAddItem, activeItemCount } from '@/db/repo';
import { FREE_ITEM_LIMIT, SCHEMA_VERSION, type Paper, type PaperKind } from '@/db/types';
import {
  DEFAULT_LEAD_DAYS,
  daysUntilExpiry,
  daysUntilRenewBy,
  expiryLabel,
  holders,
  leadDaysFor,
  needsRenewing,
  nextUp,
  paperLabel,
  paperState,
  renewBy,
  reminderDue,
  sortPapers,
} from '@/lib/papers';
import { exportBundle, parseBundle, restoreBundle } from '@/lib/backup';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const iso = (d: Date | null) =>
  d
    ? `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
    : 'null';

function paper(over: Partial<Paper> = {}): Paper {
  return {
    id: 'x',
    schemaVersion: SCHEMA_VERSION,
    propertyId: 'p',
    kind: 'passport' as PaperKind,
    label: 'Passport',
    expiresOn: '2027-06-15',
    createdAt: '',
    updatedAt: '',
    ...over,
  };
}

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;

  /* ------------------------------------------------------- the lead time */

  check('a passport defaults to eight months', DEFAULT_LEAD_DAYS.passport === 240);
  check('and an MOT to one', DEFAULT_LEAD_DAYS.vehicle === 30);
  check('the default applies when nothing is set', leadDaysFor(paper()) === 240);
  check('and an override wins', leadDaysFor(paper({ leadDays: 30 })) === 30);

  /*
    Zero is a real answer — "don't warn me early, tell me on the day" — and the
    obvious `paper.leadDays || DEFAULT` would silently replace it with 240.
  */
  check('zero is a lead time, not a missing one', leadDaysFor(paper({ leadDays: 0 })) === 0);

  /* -------------------------------------------------------- the renew-by */

  check('renew-by is expiry minus the lead', iso(renewBy(paper())) === '2026-10-18', iso(renewBy(paper())));
  check(
    'a zero lead renews on the day it expires',
    iso(renewBy(paper({ leadDays: 0 }))) === '2027-06-15',
  );
  check('an unreadable date has no renew-by', renewBy(paper({ expiresOn: 'soon' })) === null);
  check('and neither does an impossible one', renewBy(paper({ expiresOn: '2027-02-31' })) === null);

  /*
    The lead is subtracted by the calendar, not by milliseconds. 240 days back
    from 15 June 2027 crosses a clock change; doing it in arithmetic on
    timestamps lands an hour out and, on the wrong day, a whole day out.
  */
  const across = renewBy(paper({ expiresOn: '2027-03-20', leadDays: 150 }));
  check('the subtraction crosses a clock change intact', iso(across) === '2026-10-21', iso(across));

  /* ------------------------------------------------------------ counting */

  const now = new Date(2026, 9, 1); // 1 October 2026, expiry 15 June 2027
  check('days to expiry counts the printed date', daysUntilExpiry(paper(), now) === 257, `${daysUntilExpiry(paper(), now)}`);
  // 257 − 240. The gap between these two numbers is the entire feature.
  check('days to renew-by is much sooner', daysUntilRenewBy(paper(), now) === 17, `${daysUntilRenewBy(paper(), now)}`);

  /* -------------------------------------------------------------- states */

  check('a long way off is valid', paperState(paper(), now) === 'valid');
  check(
    'inside the lead time it wants renewing',
    paperState(paper(), new Date(2026, 10, 1)) === 'renew',
  );
  check('on the renew-by date itself, already', paperState(paper(), new Date(2026, 9, 18)) === 'renew');
  check('the day before, not yet', paperState(paper(), new Date(2026, 9, 17)) === 'valid');
  check('past the printed date it is expired', paperState(paper(), new Date(2027, 6, 1)) === 'expired');
  check('on the printed date it is still valid', paperState(paper(), new Date(2027, 5, 15)) !== 'expired');

  /*
    A date that won't parse is not bad news. Reporting "expired" for a record
    whose expiry field is empty or mistyped would be the app inventing a
    problem, and it would sit at the top of the list shouting about it.
  */
  check('an unreadable date is not an expiry', paperState(paper({ expiresOn: '' }), now) === 'valid');

  /* -------------------------------------------------------------- labels */

  const far = paperLabel(paper(), now);
  check('a valid one says when to start', far.startsWith('Start '), far);
  check('and names a month and year when that is months away', /\d{4}/.test(paperLabel(paper(), new Date(2026, 0, 1))));
  check('but a day when starting is imminent', !/\d{4}/.test(far), far);

  const due = paperLabel(paper(), new Date(2026, 10, 1));
  check('one inside its lead says renew now', due.startsWith('Renew now'), due);
  /*
    And names the EXPIRY, not the renew-by. The renew-by is in the past by
    then, and "renew by 18 October" printed in November is the app telling you
    off with a date that has already gone.
  */
  check('naming the expiry, not a date that has passed', due.includes('15 Jun') || due.includes('Jun 15'), due);

  const gone = paperLabel(paper(), new Date(2027, 6, 1));
  check('an expired one is in the past tense', gone.startsWith('Expired '), gone);

  check('no date, said plainly', paperLabel(paper({ expiresOn: '' }), now) === 'No expiry date');
  check('the printed fact stands alone', expiryLabel(paper()).startsWith('Valid to '), expiryLabel(paper()));

  /* ------------------------------------------------------------- sorting */

  /*
    THE CASE THE WHOLE FILE IS FOR. A passport expiring in nine months needs
    starting before a driving licence expiring in four, because one needs eight
    months of runway and the other needs two. Sorted by the printed date they
    come out backwards — which is the mistake a calendar reminder makes, and
    the reason this is worth being an app feature rather than a note.
  */
  const july = new Date(2026, 6, 1);
  const passport = paper({ id: 'passport', label: 'Passport', kind: 'passport', expiresOn: '2027-04-01' });
  const licence = paper({ id: 'licence', label: 'Licence', kind: 'licence', expiresOn: '2026-11-01' });

  check('the licence expires first', licence.expiresOn < passport.expiresOn);
  const order = sortPapers([licence, passport], july).map((p) => p.id);
  check('but the passport needs starting first', order[0] === 'passport', order.join(' → '));

  check('a paper with no date sinks', sortPapers([paper({ id: 'broken', expiresOn: '' }), passport], july)[1]!.id === 'broken');

  /* ------------------------------------------------------- what needs you */

  /*
    One of each state at the same moment, on 15 August 2026:

      mot       expired 10 July                       expired
      passport  renew-by 4 August, expires April       renew
      licence   renew-by 2 September                   valid
      contents  renew-by December 2027                 valid
  */
  const august = new Date(2026, 7, 15);
  const set = [
    passport,
    licence,
    paper({ id: 'mot', kind: 'vehicle', label: 'MOT', expiresOn: '2026-07-10' }),
    paper({ id: 'far', kind: 'insurance', label: 'Contents', expiresOn: '2028-01-01' }),
  ];
  check('one of each state', ['mot', 'passport', 'licence', 'far'].map((id) => paperState(set.find((p) => p.id === id)!, august)).join() === 'expired,renew,valid,valid');

  const jobs = needsRenewing(set, august);
  check('two of the four need something', jobs.length === 2, jobs.map((p) => p.id).join(', '));
  check('and the ones that do not are left alone', !jobs.some((p) => p.id === 'far' || p.id === 'licence'));
  check('worst first — the one already expired', jobs[0]!.id === 'mot', jobs[0]!.id);

  /*
    Next up skips everything already overdue. A "coming next" that keeps
    naming the thing you are late for is a second copy of the alert above it.
  */
  check('next up is the soonest that is still fine', nextUp(set, august)?.id === 'licence', nextUp(set, august)?.id);
  check('and nothing valid means nothing next', nextUp(jobs, august) === null);
  check('an empty list needs nothing', needsRenewing([], august).length === 0);

  /* ----------------------------------------------------------- reminders */

  /*
    Measured against the renew-by, not the expiry. A reminder three days before
    a passport expires is a reminder three days before a holiday is cancelled.
  */
  const remind = paper({ remindDays: 7 });
  check('seven days before renew-by is due', reminderDue(remind, new Date(2026, 9, 12)));
  check('eight is not', !reminderDue(remind, new Date(2026, 9, 10)));
  check('no reminder set, never due', !reminderDue(paper(), new Date(2026, 9, 18)));
  check(
    'and it fires nowhere near the printed date',
    !reminderDue(remind, new Date(2027, 5, 10)),
  );

  /* --------------------------------------------- a real household, in order */

  /*
    Ten documents, sorted by the app, on 17 August 2026. This is the case the
    whole module exists for and it only shows up on a realistic set: Nuno's
    passport expires in FEBRUARY and the car's MOT expires in SEPTEMBER, five
    months sooner — and the passport still has to come first, because it needed
    starting in June and the MOT needs starting now.

    Ordered by the printed date this list comes out backwards, and coming out
    backwards is precisely the mistake a calendar reminder makes.
  */
  const day = new Date(2026, 7, 17);
  const home = [
    paper({ id: 'mot', kind: 'vehicle', label: 'MOT', expiresOn: '2026-09-08' }),
    paper({ id: 'nuno-pp', kind: 'passport', label: 'Passport', holder: 'Nuno', expiresOn: '2027-02-11' }),
    paper({ id: 'ana-pp', kind: 'passport', label: 'Passport', holder: 'Ana', expiresOn: '2031-09-30' }),
    paper({ id: 'gym', kind: 'membership', label: 'Gym', expiresOn: '2026-08-31' }),
    paper({ id: 'contents', kind: 'insurance', label: 'Home contents', expiresOn: '2026-11-20' }),
  ];

  check('the MOT expires five months before the passport',
    home[0]!.expiresOn < home[1]!.expiresOn);
  check(
    'and the passport still sorts above it',
    sortPapers(home, day).map((p) => p.id)[0] === 'nuno-pp',
    sortPapers(home, day).map((p) => p.id).join(' → '),
  );
  check('three of the five need starting', needsRenewing(home, day).length === 3, needsRenewing(home, day).map((p) => p.id).join(', '));
  check('and the next one after those is the contents policy', nextUp(home, day)?.id === 'contents');

  /*
    The dashboard prints this gap as a rounded number of months, and rounding
    breaks at the near end: 18 days is "1 month" and 10 days is "0 months" — a
    countdown that has visibly stopped counting, on the row that matters most.
    Home switches to days under 45; this pins the boundary that forces it.
  */
  const nearly = daysUntilRenewBy(paper({ kind: 'membership', expiresOn: '2026-09-20' }), day);
  check('a paper can be days from needing you, not months', nearly !== null && nearly < 45 && nearly > 0, `${nearly}`);
  check('and rounding it to months would say zero', Math.round((nearly ?? 0) / 30) === 0, `${nearly}`);

  /* -------------------------------------------------------------- holders */

  check(
    'holders are listed once each, sorted',
    holders([paper({ holder: 'Sam' }), paper({ holder: 'Ada' }), paper({ holder: 'Sam' })]).join() === 'Ada,Sam',
  );
  check('and nobody named is an empty list', holders([paper(), paper({ holder: '  ' })]).length === 0);

  /* ------------------------------------------------------------ the table */

  const id = await createPaper({
    propertyId: property.id,
    kind: 'passport',
    label: "Nuno's passport",
    expiresOn: '2031-03-04',
    holder: 'Nuno',
    authority: 'HM Passport Office',
    storedAt: 'Fireproof box',
  });
  const rows = await activePapers(property.id);
  check('it saves', rows.length === 1 && rows[0]!.id === id);
  check('stamped with the current schema', rows[0]!.schemaVersion === SCHEMA_VERSION);

  /*
    Nothing sensitive is stored, and the type is the enforcement. If a document
    number or a scan is ever added, this fails and whoever added it has to come
    and read the note on the Paper type about plaintext backups first.
  */
  const fields = Object.keys(rows[0]!);
  const banned = ['number', 'reference', 'documentNumber', 'scanBlobId', 'blobId', 'photoBlobId'];
  check(
    'no document number and no scan on the record',
    !fields.some((f) => banned.includes(f)),
    fields.join(', '),
  );

  await updatePaper(id, { leadDays: 300 });
  check('and updates', (await db.papers.get(id))!.leadDays === 300);

  /*
    Papers do not count against the free cap, for the same reason subscriptions
    don't: the cap prices storage, and a paper has no attachments at all.
  */
  const settings = (await db.settings.get('singleton'))!;
  const before = await activeItemCount(property.id);
  check('a paper is not an item', before === 0, `${before}`);
  check('and the cap is untouched by one', canAddItem(before, settings.entitlements));

  // The cap counts items and nothing else. Fifteen papers on top of a full
  // fifteen items is still fine, and has to be — a passport is not storage.
  for (let i = 0; i < 15; i++) {
    await createPaper({ propertyId: property.id, kind: 'other', label: `Doc ${i}`, expiresOn: '2030-01-01' });
  }
  check('sixteen papers do not fill a fifteen-item tier', canAddItem(await activeItemCount(property.id), settings.entitlements));
  check('and they are all there', (await activePapers(property.id)).length === 16);
  for (const p of (await activePapers(property.id)).filter((p) => p.id !== id)) await deletePaper(p.id);

  /* --------------------------------------------------------- the round trip */

  const bundle = await exportBundle();
  const parsed = await parseBundle(bundle.blob);
  check('papers ride along in a backup', parsed.data.papers.length === 1);
  check('with their lead time', parsed.data.papers[0]!.leadDays === 300);
  check('and where the paper one lives', parsed.data.papers[0]!.storedAt === 'Fireproof box');

  await deletePaper(id);
  check('deleting is a hard delete', (await activePapers(property.id)).length === 0);

  await restoreBundle(parsed, 'merge');
  const back = await activePapers(property.id);
  check('and a restore brings it back', back.length === 1 && back[0]!.storedAt === 'Fireproof box');

  /*
    A bundle written before papers existed has no papers.json. That file
    contributes zero bytes to the checksum, so every older backup still
    verifies — which is why the table was appended to TABLE_ORDER rather than
    slotted in beside subscriptions where it reads better.
  */
  check('the table is always an array, never undefined', Array.isArray(parsed.data.papers));

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

void main();
