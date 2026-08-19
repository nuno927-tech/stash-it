/**
 * Several policies on one product.
 *
 *   npm run test:coverage
 *
 * The rule this file exists to defend: the countdown belongs to whatever runs
 * out *first*. A couch with a lifetime frame and twelve months on the fabric
 * must not read "covered for life" — that is precisely the morning the fabric
 * cover ends and nobody was told.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import type { Coverage, Item } from '@/db/types';
import { blankCoverage, draftFromForm, emptyForm, formFromItem, saveNewItem } from '@/lib/addItem';
import { exportBundle, parseBundle, restoreBundle } from '@/lib/backup';
import { gapsFor } from '@/lib/dashboard';
import { searchAll } from '@/lib/search';
import { MAX_RINGS } from '@/components/WarrantyRing';
import {
  coverageArcs,
  coverageLabel,
  coverageSchedule,
  coverSummary,
  coverageTermLabel,
  coveragesOf,
  effectiveExpiry,
  hasLifetime,
  nextToLapse,
  toISODate,
  warrantyLabel,
  warrantyParts,
  warrantyProgress,
  warrantyState,
} from '@/lib/warranty';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const TODAY = new Date();

/** A purchase date `years` ago, so terms land at predictable distances. */
function boughtYearsAgo(years: number): string {
  const d = new Date(TODAY.getFullYear() - years, TODAY.getMonth(), TODAY.getDate());
  return toISODate(d);
}

function cover(over: Partial<Coverage>): Coverage {
  return { id: Math.random().toString(36).slice(2), label: 'Warranty', unit: 'years', amount: 1, ...over };
}

function item(over: Partial<Item>): Item {
  const ts = new Date().toISOString();
  return {
    id: 'x',
    schemaVersion: 2,
    name: 'Thing',
    propertyId: 'p',
    createdAt: ts,
    updatedAt: ts,
    ...over,
  };
}

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;

  /* ------------------------------------------------------- the couch */

  // Bought a year ago: fabric has run out, mattress/springs/cushions run on,
  // frame is forever.
  const couch = item({
    name: 'Sectional couch',
    purchaseDate: boughtYearsAgo(1),
    coverages: [
      cover({ label: 'Frame', unit: 'lifetime', amount: 0 }),
      cover({ label: 'Cushions', unit: 'years', amount: 10 }),
      cover({ label: 'Springs', unit: 'years', amount: 5 }),
      cover({ label: 'Mattress', unit: 'years', amount: 3 }),
      cover({ label: 'Fabric', unit: 'years', amount: 2, covers: 'Seam failure and pilling' }),
    ],
  });

  const schedule = coverageSchedule(couch);
  check('every policy is listed', schedule.length === 5, `${schedule.length}`);
  check(
    'soonest to lapse comes first',
    coverageLabel(schedule[0]!.coverage) === 'Fabric',
    coverageLabel(schedule[0]!.coverage),
  );
  check(
    'then in the order they run out',
    schedule.slice(0, 4).map((d) => coverageLabel(d.coverage)).join(',') ===
      'Fabric,Mattress,Springs,Cushions',
    schedule.map((d) => coverageLabel(d.coverage)).join(','),
  );
  check('lifetime sorts last', coverageLabel(schedule[4]!.coverage) === 'Frame');
  check('and carries no end date', schedule[4]!.end === null);
  check('and no countdown', schedule[4]!.daysLeft === null);

  const next = nextToLapse(couch)!;
  check('the countdown belongs to the fabric', coverageLabel(next.coverage) === 'Fabric');
  check('a year of a two-year term is left', next.daysLeft! > 300 && next.daysLeft! < 400, `${next.daysLeft}`);

  const parts = warrantyParts(couch);
  check('the list row names which policy', parts.which === 'Fabric', parts.which);
  check('and does not read as lifetime', parts.value !== 'Lifetime', parts.value);

  check('the item is not painted as expired', warrantyState(couch) === 'covered');
  check('what it covers is kept', schedule[0]!.coverage.covers === 'Seam failure and pilling');
  check('the term reads back', coverageTermLabel(schedule[0]!.coverage) === '2 years');
  check('a single year singularises', coverageTermLabel(cover({ amount: 1 })) === '1 year');
  check('lifetime says so', coverageTermLabel(cover({ unit: 'lifetime' })) === 'Lifetime');

  /* ------------------------------------ everything lapsed but the frame */

  const oldCouch = item({
    ...couch,
    purchaseDate: boughtYearsAgo(20),
  });
  check('nothing is still running', nextToLapse(oldCouch) === null);
  check('but a lifetime policy holds', warrantyState(oldCouch) === 'covered');
  check('and the label says which', warrantyLabel(oldCouch) === 'Lifetime', warrantyLabel(oldCouch));
  check('the ring shows full', warrantyProgress(oldCouch) === 1);

  const noFrame = item({
    ...oldCouch,
    coverages: oldCouch.coverages!.filter((c) => c.label !== 'Frame'),
  });
  check('without it, the item has expired', warrantyState(noFrame) === 'expired');
  check('and says how long ago', warrantyParts(noFrame).value === 'Ended');
  check('naming the last one to go', warrantyParts(noFrame).which === 'Cushions', warrantyParts(noFrame).which);

  /* --------------------------------------------------- the heat gun */

  const heatGun = item({
    name: 'DeWalt heat gun',
    purchaseDate: toISODate(new Date(TODAY.getFullYear(), TODAY.getMonth(), TODAY.getDate() - 30)),
    coverages: [
      cover({ label: 'Limited warranty', unit: 'years', amount: 3 }),
      cover({ label: 'Free service', unit: 'years', amount: 1 }),
      cover({ label: 'Money back', unit: 'days', amount: 90 }),
    ],
  });

  const gunNext = nextToLapse(heatGun)!;
  check('the short window wins', coverageLabel(gunNext.coverage) === 'Money back');
  check('and counts in days', warrantyParts(heatGun).unit === 'days left', warrantyParts(heatGun).unit);
  check('60 days of 90 remain', gunNext.daysLeft === 60, `${gunNext.daysLeft}`);
  // Still comfortable: the warning threshold is 30 days for every policy,
  // short window or not.
  check('60 days out is still covered', warrantyState(heatGun) === 'covered');
  const nearlyUp = item({
    ...heatGun,
    purchaseDate: toISODate(new Date(TODAY.getFullYear(), TODAY.getMonth(), TODAY.getDate() - 75)),
  });
  check('15 days out is ending soon', warrantyState(nearlyUp) === 'ending-soon');
  check(
    'and the item still runs on the refund window',
    coverageLabel(nextToLapse(nearlyUp)!.coverage) === 'Money back',
  );
  check(
    'the expiry is the soonest, not the longest',
    toISODate(effectiveExpiry(heatGun)!) === toISODate(gunNext.end!),
  );

  /* --------------------------------------------- records without a list */

  const legacy = item({
    name: 'Old record',
    purchaseDate: boughtYearsAgo(1),
    warranty: { months: 24, unit: 'months', amount: 24, provider: 'Bosch' },
    extendedWarranty: { months: 48, unit: 'months', amount: 48, provider: 'SquareTrade' },
  });

  const folded = coveragesOf(legacy);
  check('an old record reads as two policies', folded.length === 2, `${folded.length}`);
  check('the base one keeps the plain name', folded[0]!.label === 'Warranty');
  check('the second is named as extended', folded[1]!.label === 'Extended warranty');
  check('providers survive the fold', folded[1]!.provider === 'SquareTrade');
  check('nothing is written to the record', legacy.coverages === undefined);
  check(
    'and the base policy drives it, being sooner',
    coverageLabel(nextToLapse(legacy)!.coverage) === 'Warranty',
  );

  const empty = item({ name: 'Nothing recorded' });
  check('no policies means unknown', warrantyState(empty) === 'unknown');
  check('and nothing to show', warrantyParts(empty).value === '—');
  check('no lifetime either', !hasLifetime(empty));

  /* ------------------------------------------------------ through the form */

  const draft = draftFromForm(
    {
      ...emptyForm('USD'),
      name: 'Couch',
      purchaseDate: boughtYearsAgo(1),
      coverages: [
        blankCoverage({ label: 'Frame', unit: 'lifetime' }),
        blankCoverage({ label: 'Fabric', unit: 'years', amount: '2', covers: 'Pilling' }),
        blankCoverage({ label: 'Half-typed', unit: 'years', amount: '' }),
      ],
    },
    property.id,
  );
  check('a lifetime row saves without a number', draft.coverages?.length === 2, `${draft.coverages?.length}`);
  check('the blank row is dropped', !draft.coverages?.some((c) => c.label === 'Half-typed'));
  check('what it covers is saved', draft.coverages?.[1]?.covers === 'Pilling');
  check('lifetime is stored as a unit', draft.coverages?.[0]?.unit === 'lifetime');
  check('and carries no amount', draft.coverages?.[0]?.amount === 0);
  // Only dated policies can be expressed in the old fields; a lifetime one
  // has no months to put there.
  check('the legacy mirror takes the dated one', draft.warranty?.months === 24, JSON.stringify(draft.warranty));
  check('and leaves the second slot empty', draft.extendedWarranty === undefined);

  const savedId = await saveNewItem(
    {
      ...emptyForm('USD'),
      name: 'Saved couch',
      purchaseDate: boughtYearsAgo(1),
      coverages: [
        blankCoverage({ label: 'Frame', unit: 'lifetime' }),
        blankCoverage({ label: 'Fabric', unit: 'years', amount: '2' }),
      ],
    },
    property.id,
  );
  const saved = (await db.items.get(savedId))!;
  check('the list is stored', saved.coverages?.length === 2);
  check('and drives the saved record', coverageLabel(nextToLapse(saved)!.coverage) === 'Fabric');

  const backToForm = formFromItem(saved, 'USD');
  check('editing restores every row', backToForm.coverages.length === 2, `${backToForm.coverages.length}`);
  check('including the lifetime one', backToForm.coverages[0]?.unit === 'lifetime');
  check('with its name', backToForm.coverages[0]?.label === 'Frame');
  check('and a lifetime row has no amount to edit', backToForm.coverages[0]?.amount === '');

  /* ------------------------------------------------- what the row shows */

  const arcs = coverageArcs(couch);
  check('one arc per policy', arcs.length === 5, `${arcs.length}`);
  check('the first is the one running out', arcs[0]!.state === 'covered');
  check(
    'and they are ordered soonest first',
    arcs.every((a, i) => i === 0 || a.progress >= arcs[i - 1]!.progress - 0.5),
  );
  check('the lifetime arc is full', arcs[4]!.progress === 1);
  check(
    'the drawn ones are capped at four',
    Math.min(arcs.length, MAX_RINGS) === 4,
    `${Math.min(arcs.length, MAX_RINGS)}`,
  );

  const oneRing = coverageArcs(item({ name: 'Plain', purchaseDate: boughtYearsAgo(1), warranty: { months: 24 } }));
  check('a single warranty draws one arc', oneRing.length === 1, `${oneRing.length}`);
  const noRing = coverageArcs(empty);
  check('and nothing recorded still draws a track', noRing.length === 1);
  check('as an empty one', noRing[0]!.progress === 0 && noRing[0]!.state === 'unknown');

  // The count lives on the ring badge, so this line carries only the name.
  check(
    'the row names what ends first',
    coverSummary(couch) === 'Fabric ends first',
    String(coverSummary(couch)),
  );
  check('one policy gets no cover line', coverSummary(item({ warranty: { months: 12 } })) === null);
  check('nor does an item with none', coverSummary(empty) === null);
  check(
    'a lifetime-only survivor says so',
    coverSummary(oldCouch) === 'Covered for life',
    String(coverSummary(oldCouch)),
  );
  check(
    'and everything lapsed says that',
    coverSummary(noFrame) === 'Every policy has ended',
    String(coverSummary(noFrame)),
  );

  /* ------------------------------------------------------------- the rest */

  const gaps = gapsFor([saved], []);
  check(
    'a lifetime-only policy is not a missing warranty',
    !gaps.some((g) => g.kind === 'warranty'),
    gaps.map((g) => g.kind).join(','),
  );

  const hits = searchAll('fabric', { items: [saved], docs: [], rooms: [] });
  check('a policy name is searchable', hits.length === 1, `${hits.length} hits`);
  const covers = searchAll('pilling', { items: [couch], docs: [], rooms: [] });
  check('and so is what it covers', covers.length === 1, `${covers.length} hits`);

  /* --------------------------------------------------- backup round trip */

  const bundle = await exportBundle();
  const parsed = await parseBundle(new File([bundle.blob], bundle.filename));
  await restoreBundle(parsed, 'replace');

  const restored = (await db.items.get(savedId))!;
  check('coverages survive a backup', restored.coverages?.length === 2, `${restored.coverages?.length}`);
  check('lifetime survives', restored.coverages?.[0]?.unit === 'lifetime');
  check('and the countdown still points at the fabric', coverageLabel(nextToLapse(restored)!.coverage) === 'Fabric');

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
