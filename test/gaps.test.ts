/**
 * What still needs doing.
 *
 *   npm run test:gaps
 *
 * The ordering is the part with an opinion in it, and it isn't by count. A
 * receipt can't be recreated — no shop reissues one from three years ago — so
 * it leads even when only one item is missing one and forty are missing a
 * photo you could take this afternoon.
 */

import { gapsFor } from '@/lib/dashboard';
import type { Doc, Item } from '@/db/types';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const ts = '2026-08-01T00:00:00.000Z';

function item(id: string, over: Partial<Item> = {}): Item {
  return {
    id,
    schemaVersion: 2,
    name: id,
    propertyId: 'p1',
    purchaseDate: '2026-01-01',
    thumbBlobId: `thumb-${id}`,
    warranty: { months: 24, unit: 'months', amount: 24 },
    createdAt: ts,
    updatedAt: ts,
    ...over,
  };
}

function doc(id: string, itemId: string, kind: Doc['kind'], over: Partial<Doc> = {}): Doc {
  return {
    id,
    schemaVersion: 2,
    itemId,
    kind,
    title: kind,
    storageMode: 'local',
    createdAt: ts,
    updatedAt: ts,
    ...over,
  } as Doc;
}

function countOf(gaps: ReturnType<typeof gapsFor>, kind: string): number {
  return gaps.find((g) => g.kind === kind)?.count ?? 0;
}

function main() {
  /* --------------------------------------------------------- the complete */

  const whole = [item('a')];
  const wholeDocs = [doc('d1', 'a', 'receipt')];
  check('a complete item has no gaps', gapsFor(whole, wholeDocs).length === 0);

  /* ------------------------------------------------------------ each gap */

  const gaps = gapsFor(
    [
      item('noreceipt'),
      item('nophoto', { thumbBlobId: undefined }),
      item('nodate', { purchaseDate: undefined }),
      item('noterm', { warranty: undefined }),
    ],
    [
      doc('d1', 'nophoto', 'receipt'),
      doc('d2', 'nodate', 'receipt'),
      doc('d3', 'noterm', 'receipt'),
    ],
  );

  check('a missing receipt is counted', countOf(gaps, 'receipt') === 1);
  check('a missing photo is counted', countOf(gaps, 'photo') === 1);
  check('a missing date is counted', countOf(gaps, 'date') === 1);
  check('a missing term is counted', countOf(gaps, 'warranty') === 1);

  /* ------------------------------------------------------------ ordering */

  // One missing receipt against forty missing photos: the receipt still leads,
  // because it's the one that can't be fixed later.
  const lopsided = gapsFor(
    [
      item('r'),
      ...Array.from({ length: 40 }, (_, i) => item(`p${i}`, { thumbBlobId: undefined })),
    ],
    Array.from({ length: 40 }, (_, i) => doc(`d${i}`, `p${i}`, 'receipt')),
  );
  check('consequence beats volume', lopsided[0]!.kind === 'receipt', lopsided[0]!.kind);
  check('and the photo pile is second', lopsided[1]!.kind === 'photo');
  check('with the real count', lopsided[1]!.count === 40, String(lopsided[1]!.count));

  /* -------------------------------------------------------- what counts */

  // A warranty *document* is not a warranty *length*. An item can have the
  // policy PDF attached and still nothing to count down, and the countdown is
  // what every warning in the app is built on.
  const paperOnly = gapsFor(
    [item('x', { warranty: undefined })],
    [doc('d1', 'x', 'receipt'), doc('d2', 'x', 'warranty')],
  );
  check('paperwork is not a term', countOf(paperOnly, 'warranty') === 1);

  // A zero-month legacy warranty is an absent one, not a zero-length one.
  const zero = gapsFor([item('z', { warranty: { months: 0 } })], [doc('d1', 'z', 'receipt')]);
  check('a zero-month warranty counts as missing', countOf(zero, 'warranty') === 1);

  // Extended cover on its own is still cover.
  const extOnly = gapsFor(
    [item('e', { warranty: undefined, extendedWarranty: { months: 12 } })],
    [doc('d1', 'e', 'receipt')],
  );
  check('extended cover alone is enough', countOf(extOnly, 'warranty') === 0);

  /* ---------------------------------------------------------- the deleted */

  // Soft-deleted records must not generate work. Nagging someone about an item
  // they threw away is the fastest way to make them ignore the card.
  const deleted = gapsFor(
    [item('gone', { deletedAt: ts, thumbBlobId: undefined, purchaseDate: undefined })],
    [],
  );
  check('a deleted item asks for nothing', deleted.length === 0);

  // …and neither does a deleted receipt count as one that exists.
  const trashedDoc = gapsFor([item('t')], [doc('d1', 't', 'receipt', { deletedAt: ts })]);
  check('a deleted receipt is a missing receipt', countOf(trashedDoc, 'receipt') === 1);

  /* -------------------------------------------------------------- labels */

  const one = gapsFor([item('solo', { thumbBlobId: undefined })], [doc('d', 'solo', 'receipt')]);
  check('one item reads as singular', one[0]!.label === '1 item has no photo', one[0]!.label);

  const two = gapsFor(
    [item('a1', { thumbBlobId: undefined }), item('a2', { thumbBlobId: undefined })],
    [doc('d1', 'a1', 'receipt'), doc('d2', 'a2', 'receipt')],
  );
  check('two read as plural', two[0]!.label === '2 items have no photo', two[0]!.label);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
