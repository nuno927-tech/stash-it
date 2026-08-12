/**
 * Warranty units and document naming.
 *
 *   npm run test:units
 *
 * The point of units: someone who typed "90 days" is watching a 90-day clock.
 * Showing them "2m" on day one answers a question they didn't ask.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import type { Item } from '@/db/types';
import { blankCoverage, emptyForm, draftFromForm, formFromItem, saveNewItem } from '@/lib/addItem';
import { attachFile, docHeadline, docSubtitle, isMachineFilename, titleFromFilename } from '@/lib/docs';
import {
  countsInDays,
  effectiveExpiry,
  termLabel,
  termOf,
  termToMonths,
  toISODate,
  warrantyLabel,
  warrantyParts,
  warrantyState,
} from '@/lib/warranty';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const ts = '2026-01-01T00:00:00.000Z';

/** An item bought `daysAgo` days ago with the given term. */
function withTerm(unit: 'days' | 'months' | 'years', amount: number, daysAgo = 0): Item {
  const bought = new Date();
  bought.setDate(bought.getDate() - daysAgo);
  return {
    id: `${unit}-${amount}`,
    schemaVersion: 1,
    name: 'Thing',
    propertyId: 'p1',
    purchaseDate: toISODate(bought),
    warranty: { months: termToMonths({ unit, amount }), unit, amount },
    createdAt: ts,
    updatedAt: ts,
  };
}

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;

  /* --------------------------------------------------------- the term */

  check('a day term reads back as days', termOf(withTerm('days', 90).warranty)?.unit === 'days');
  check('a year term reads back as years', termOf(withTerm('years', 3).warranty)?.amount === 3);
  check('90 days is about 3 months', termToMonths({ unit: 'days', amount: 90 }) === 3);
  check('3 years is 36 months', termToMonths({ unit: 'years', amount: 3 }) === 36);
  check('a sub-month term still counts as one', termToMonths({ unit: 'days', amount: 5 }) === 1);

  // Records written before units existed only have months, and mean months.
  const legacy: Item = {
    id: 'legacy',
    schemaVersion: 1,
    name: 'Old record',
    propertyId: 'p1',
    purchaseDate: '2026-01-31',
    warranty: { months: 24 },
    createdAt: ts,
    updatedAt: ts,
  };
  check('a legacy record reads as months', termOf(legacy.warranty)?.unit === 'months');
  check('a legacy record keeps its amount', termOf(legacy.warranty)?.amount === 24);
  check(
    'and still expires on the calendar month',
    toISODate(effectiveExpiry(legacy)!) === '2028-01-31',
    toISODate(effectiveExpiry(legacy)!),
  );

  /* ------------------------------------------------------------ expiry */

  const d90 = withTerm('days', 90);
  const expected = new Date();
  expected.setDate(expected.getDate() + 90);
  check(
    'a 90-day term expires in exactly 90 days',
    toISODate(effectiveExpiry(d90)!) === toISODate(expected),
    `${toISODate(effectiveExpiry(d90)!)} vs ${toISODate(expected)}`,
  );

  // Days are exact; months are calendar. 1 month from 31 Jan is not 31 days.
  const jan31Months: Item = { ...withTerm('months', 1), purchaseDate: '2026-01-31' };
  check(
    'one month from 31 Jan lands on 28 Feb',
    toISODate(effectiveExpiry(jan31Months)!) === '2026-02-28',
    toISODate(effectiveExpiry(jan31Months)!),
  );
  const jan31Days: Item = { ...withTerm('days', 31), purchaseDate: '2026-01-31' };
  check(
    'thirty-one days from 31 Jan lands on 3 Mar',
    toISODate(effectiveExpiry(jan31Days)!) === '2026-03-03',
    toISODate(effectiveExpiry(jan31Days)!),
  );

  /* ------------------------------------------------------------ labels */

  check('a 90-day term counts down in days', warrantyLabel(d90) === '90 days', warrantyLabel(d90));
  check('it still says days at day 61', warrantyLabel(withTerm('days', 90, 29)) === '61 days');
  check('and at day 89', warrantyLabel(withTerm('days', 90, 1)) === '89 days');
  check('a 180-day term does not switch to months', warrantyLabel(withTerm('days', 180)) === '180 days');
  check('the day-based flag is set', countsInDays(d90));

  // A month-based term keeps the old, compact behaviour.
  check('a 24-month term reads as years', warrantyLabel(withTerm('months', 24)) === '2y', warrantyLabel(withTerm('months', 24)));
  check('a month term is not day-based', !countsInDays(withTerm('months', 24)));
  check('singular day', warrantyLabel(withTerm('days', 1)) === '1 day', warrantyLabel(withTerm('days', 1)));

  /* ------------------------------------------- the last six months, in days */

  // Once there's less than half a year left, a month-based term switches to a
  // daily countdown: "5m" and "4m" are the same glance, and the window to do
  // something about it closes while the label still says "1m".
  const twelveMonths = withTerm('months', 12);
  check(
    'a year out, months are enough',
    warrantyLabel(twelveMonths) === '11m',
    warrantyLabel(twelveMonths),
  );

  // Seven months elapsed of a twelve-month term: five to go.
  const fiveLeft = withTerm('months', 12, 213);
  check(
    'inside six months it counts days',
    /^\d+ days$/.test(warrantyLabel(fiveLeft)),
    warrantyLabel(fiveLeft),
  );

  // Either side of the boundary, on a term long enough that the old rule would
  // never have switched.
  const justOver = withTerm('years', 5, 5 * 365 - 200);
  const justUnder = withTerm('years', 5, 5 * 365 - 150);
  check('just over six months still reads in months', /m$/.test(warrantyLabel(justOver)), warrantyLabel(justOver));
  check('just under six months reads in days', /days$/.test(warrantyLabel(justUnder)), warrantyLabel(justUnder));

  /* ------------------------------------------------------------- the parts */

  const parts = warrantyParts(fiveLeft);
  check('the number is split from its unit', /^\d+$/.test(parts.value), parts.value);
  check('and the unit says what it is', parts.unit === 'days left', parts.unit);

  const long = warrantyParts(withTerm('years', 5));
  check('a long term keeps the compact value', long.value === '4y 11m', long.value);
  check('with a bare unit', long.unit === 'left', long.unit);

  const gone = warrantyParts(withTerm('months', 12, 400));
  check('an expired item says so', gone.value === 'Ended', gone.value);
  check('and how long ago', /ago$/.test(gone.unit), gone.unit);

  const none = warrantyParts({ ...withTerm('months', 12), warranty: undefined });
  check('no warranty, no number', none.value === '—' && none.unit === 'no warranty');

  check('term label reads naturally', termLabel(withTerm('days', 90).warranty) === '90 days');
  check('and singularises', termLabel(withTerm('years', 1).warranty) === '1 year');

  /* ------------------------------------------------------------- state */

  check('a fresh 90-day term is covered', warrantyState(withTerm('days', 90)) === 'covered');
  check('a 20-day term is ending soon', warrantyState(withTerm('days', 20)) === 'ending-soon');
  check('a lapsed day term is expired', warrantyState(withTerm('days', 30, 40)) === 'expired');

  /* ------------------------------------------------------ through the form */

  const draft = draftFromForm(
    {
      ...emptyForm('USD'),
      name: 'Kettle',
      coverages: [blankCoverage({ unit: 'days', amount: '90' })],
    },
    property.id,
  );
  check('the form stores the unit', draft.coverages?.[0]?.unit === 'days');
  check('the form stores the amount', draft.coverages?.[0]?.amount === 90);
  check('and a months equivalent for older builds', draft.warranty?.months === 3);

  const id = await saveNewItem(
    {
      ...emptyForm('USD'),
      name: 'Day Kettle',
      coverages: [blankCoverage({ unit: 'days', amount: '90' })],
      purchaseDate: toISODate(new Date()),
    },
    property.id,
  );
  const saved = (await db.items.get(id))!;
  check('a saved day term counts down in days', warrantyLabel(saved) === '90 days', warrantyLabel(saved));

  const back = formFromItem(saved, 'USD');
  check('editing restores the unit', back.coverages[0]?.unit === 'days', back.coverages[0]?.unit);
  check('editing restores the amount', back.coverages[0]?.amount === '90', back.coverages[0]?.amount);

  const legacyForm = formFromItem(legacy, 'USD');
  check('a legacy record edits as months', legacyForm.coverages[0]?.unit === 'months');
  check('with its month count intact', legacyForm.coverages[0]?.amount === '24');

  /* -------------------------------------------------- document naming */

  check('a camera filename is recognised', isMachineFilename('IMG_20260810_143022.jpg'));
  check('a Pixel filename is recognised', isMachineFilename('PXL_20260810_143022.jpg'));
  check('a bare UUID is recognised', isMachineFilename('7b1f0f4e-1c2d-4a3b-9f8e-2a1b3c4d5e6f.pdf'));
  check('a digit soup is recognised', isMachineFilename('20260810143022.pdf'));
  check('a scanner name is recognised', isMachineFilename('scan0001.pdf'));
  check('a real name is not', !isMachineFilename('bosch_extended_cover.pdf'));

  check('a camera filename yields no title', titleFromFilename('IMG_4021.jpg') === '');
  check('a real filename still becomes a title', titleFromFilename('bosch_cover.pdf') === 'Bosch cover');

  const camera = await attachFile(
    id,
    'receipt',
    new File([new Uint8Array([1, 2, 3])], 'IMG_20260810_143022.jpg', { type: 'image/jpeg' }),
  );
  const cameraDoc = (await db.docs.get(camera))!;
  check('a photographed receipt is titled Receipt', cameraDoc.title === 'Receipt', cameraDoc.title);
  check('the row headline is the kind', docHeadline(cameraDoc) === 'Receipt');
  check('and there is no noisy subtitle', docSubtitle(cameraDoc) === null);

  const named = await attachFile(
    id,
    'warranty',
    new File([new Uint8Array([4, 5, 6])], 'extended_cover_2028.pdf', { type: 'application/pdf' }),
  );
  const namedDoc = (await db.docs.get(named))!;
  check('a meaningful filename survives as the subtitle', docSubtitle(namedDoc) === 'Extended cover 2028', String(docSubtitle(namedDoc)));
  check('the headline is still the kind', docHeadline(namedDoc) === 'Warranty');

  // A document saved before this rule, with a junk title, must still read well.
  await db.docs.update(camera, { title: 'IMG_20260810_143022' });
  check(
    'an already-saved junk title is suppressed',
    docSubtitle((await db.docs.get(camera))!) === null,
  );

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
