/**
 * Recently deleted: the countdown, and getting things back.
 *
 *   npm run test:bin
 *
 * The delete dialog promised a bin for thirty days. There wasn't one — items
 * were soft-deleted, counted down and purged, and `restoreItem` had never been
 * called from anywhere. This file exists so the promise and the behaviour can't
 * drift apart again: the days quoted are the days the sweep uses, restoring
 * puts everything back, and erasing takes the photos with it.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import {
  activeItemCount,
  deletedItemCount,
  deletedItems,
  emptyBin,
  purgeExpiredDeletes,
  purgeItemNow,
  PURGE_AFTER_DAYS,
  restoreItem,
  softDeleteItem,
} from '@/db/repo';
import { FREE_ITEM_LIMIT, type Entitlements } from '@/db/types';
import {
  binCount,
  binSummary,
  canRestore,
  daysLeft,
  daysLeftLabel,
  restoreBlockedReason,
} from '@/lib/bin';
import { emptyForm, saveNewItem } from '@/lib/addItem';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const NOW = new Date('2026-08-13T09:00:00Z');
const DAY = 86_400_000;
const daysAgo = (n: number) => new Date(NOW.getTime() - n * DAY).toISOString();

const free: Entitlements = { proUnlock: false, reportUnlock: false };
const pro: Entitlements = { proUnlock: true, reportUnlock: false };

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;
  const form = (name: string) => ({ ...emptyForm('USD'), name });

  /* --------------------------------------------------------- the countdown */

  check('a fresh delete has the full window', daysLeft(daysAgo(0), NOW) === PURGE_AFTER_DAYS);
  check('a day in, one fewer', daysLeft(daysAgo(1), NOW) === PURGE_AFTER_DAYS - 1);
  check('the day before it goes', daysLeft(daysAgo(PURGE_AFTER_DAYS - 1), NOW) === 1);
  check('the day it goes', daysLeft(daysAgo(PURGE_AFTER_DAYS), NOW) === 0);

  // Something can sit past its date until the next launch, when the sweep
  // runs. "-3 days left" is not a thing to tell somebody.
  check('never negative', daysLeft(daysAgo(PURGE_AFTER_DAYS + 5), NOW) === 0);

  // A corrupt date must not hurry a record towards deletion.
  check('rubbish reads as freshly deleted', daysLeft('not a date', NOW) === PURGE_AFTER_DAYS);

  check('the label counts', daysLeftLabel(12) === '12 days left');
  check('one day is named, not numbered', daysLeftLabel(1) === 'Last day');
  check('and today says so', daysLeftLabel(0) === 'Goes today');

  check('one item reads singular', binCount(1) === '1 item');
  check('two do not', binCount(2) === '2 items');

  /* ------------------------------------------- the summary on the entry row */

  check('an empty bin says so', binSummary([], NOW) === 'Nothing here');
  const rows = [
    { deletedAt: daysAgo(2) },
    { deletedAt: daysAgo(29) },
    { deletedAt: daysAgo(10) },
  ] as never[];
  // The soonest, not the newest and not an average: the only deadline that
  // matters is the next one.
  check('it quotes the most urgent', binSummary(rows, NOW) === '3 items · last day', binSummary(rows, NOW));

  /* ------------------------------------------------------- round trip */

  await db.settings.update('singleton', { entitlements: pro });

  const id = await saveNewItem(form('Kettle'), property.id);
  await db.items.update(id, { roomId: 'r1', notes: 'bought in the sale' });

  const before = await activeItemCount(property.id);
  await softDeleteItem(id);

  check('it leaves the live list', (await activeItemCount(property.id)) === before - 1);
  check('and appears in the bin', (await deletedItemCount(property.id)) === 1);

  await restoreItem(id);
  const back = (await db.items.get(id))!;
  check('restoring returns it', (await activeItemCount(property.id)) === before);
  check('the bin is empty again', (await deletedItemCount(property.id)) === 0);
  check('with everything it had', back.notes === 'bought in the sale' && back.roomId === 'r1');

  /* ------------------------------------------------------- soonest first */

  const a = await saveNewItem(form('Oldest'), property.id);
  const b = await saveNewItem(form('Newest'), property.id);
  await softDeleteItem(a);
  await db.items.update(a, { deletedAt: daysAgo(20) });
  await softDeleteItem(b);
  await db.items.update(b, { deletedAt: daysAgo(1) });

  const order = (await deletedItems(property.id)).map((i) => i.name);
  check('the bin lists what goes first, first', order.join() === 'Oldest,Newest', order.join());

  /* ------------------------------------------------------- the cap */

  /*
    Deleting frees a slot immediately — deliberately, so somebody at the limit
    can make room. That makes an unchecked restore a hole you could drive
    fifteen items through: fill up, delete the lot, fill up again, restore the
    lot. So restoring is capped like adding.
  */
  check('a subscriber can always restore', canRestore(999, pro));
  check('with room, so can anyone', canRestore(FREE_ITEM_LIMIT - 1, free));
  check('at the line, no', !canRestore(FREE_ITEM_LIMIT, free));
  check('past it, no', !canRestore(FREE_ITEM_LIMIT + 4, free));

  const why = restoreBlockedReason(FREE_ITEM_LIMIT);
  check('and it says how to fix it', /subscribe/.test(why), why);
  // The one thing that must not be implied: that the item is at risk.
  check('while promising the item is safe', /stays here/.test(why), why);

  /* ------------------------------------------------- erasing takes the files */

  const withFile = await saveNewItem(form('Has a photo'), property.id, {
    blobId: 'blob-a',
    thumbBlobId: 'blob-b',
  });
  await db.blobs.bulkPut([
    { id: 'blob-a', mime: 'image/webp', bytes: 10, data: new Blob() },
    { id: 'blob-b', mime: 'image/webp', bytes: 10, data: new Blob() },
  ] as never[]);
  await db.docs.add({
    id: 'doc-a',
    itemId: withFile,
    kind: 'receipt',
    title: 'Receipt',
    storageMode: 'local',
    blobId: 'blob-a',
    schemaVersion: 2,
    createdAt: NOW.toISOString(),
    updatedAt: NOW.toISOString(),
  } as never);

  await softDeleteItem(withFile);
  await purgeItemNow(withFile);

  check('erasing removes the record', (await db.items.get(withFile)) === undefined);
  check('and its documents', (await db.docs.get('doc-a')) === undefined);
  check('and the files behind them', (await db.blobs.get('blob-a')) === undefined);
  check('including the thumbnail', (await db.blobs.get('blob-b')) === undefined);

  /* ------------------------------------------------------- emptying */

  const stillThere = await deletedItemCount(property.id);
  check('two are waiting', stillThere === 2, `${stillThere}`);
  const liveBefore = await activeItemCount(property.id);

  const wiped = await emptyBin(property.id);
  check('emptying takes them all', wiped === 2 && (await deletedItemCount(property.id)) === 0);
  check('and touches nothing outside the bin', (await activeItemCount(property.id)) === liveBefore);

  /* --------------------------------------------- the sweep agrees with us */

  /*
    The screen says "N days left" and the sweep decides when it actually goes.
    If those ever disagree, the app is lying on one screen or deleting early on
    the other.
  */
  const doomed = await saveNewItem(form('Out of time'), property.id);
  await softDeleteItem(doomed);
  await db.items.update(doomed, { deletedAt: daysAgo(PURGE_AFTER_DAYS - 1) });

  check('with a day left it survives a sweep', (await purgeExpiredDeletes(NOW.getTime())) === 0);
  check('and is still listed', (await deletedItemCount(property.id)) === 1);
  check('the screen agrees', daysLeft(daysAgo(PURGE_AFTER_DAYS - 1), NOW) === 1);

  await db.items.update(doomed, { deletedAt: daysAgo(PURGE_AFTER_DAYS + 1) });
  check('a day over and it goes', (await purgeExpiredDeletes(NOW.getTime())) === 1);
  check('the screen agreed it was due', daysLeft(daysAgo(PURGE_AFTER_DAYS + 1), NOW) === 0);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
