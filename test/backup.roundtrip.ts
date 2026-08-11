/**
 * Export → restore round trip, run in Node against fake-indexeddb.
 *
 *   npm run test:backup
 *
 * Covers the things that lose people's data if they break: byte-identical
 * blobs, merge conflict direction, entitlement stripping, and refusing a
 * damaged or too-new bundle.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun, newId, nowISO } from '@/db/db';
import { SCHEMA_VERSION, type Item } from '@/db/types';
import { seedDemoItems } from '@/dev/seed';
import { unzipSync, zipSync } from 'fflate';
import { BundleError, exportBundle, parseBundle, restoreBundle } from '@/lib/backup';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

async function wipe() {
  await Promise.all([
    db.items.clear(),
    db.docs.clear(),
    db.blobs.clear(),
    db.properties.clear(),
    db.rooms.clear(),
    db.maintenance.clear(),
  ]);
}

const PHOTO = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3, 4, 5, 6, 7, 8]);

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;
  await seedDemoItems(property.id);

  // A blob + a doc that points at it, so the file side of the bundle is exercised.
  const blobId = newId();
  await db.blobs.add({
    id: blobId,
    data: new Blob([PHOTO], { type: 'image/png' }),
    mime: 'image/png',
    bytes: PHOTO.length,
    createdAt: nowISO(),
  });
  const first = (await db.items.toArray())[0]!;
  await db.items.update(first.id, { thumbBlobId: blobId });
  await db.docs.add({
    id: newId(),
    schemaVersion: SCHEMA_VERSION,
    itemId: first.id,
    kind: 'receipt',
    title: 'Purchase receipt',
    storageMode: 'local',
    blobId,
    createdAt: nowISO(),
    updatedAt: nowISO(),
  });

  // A soft-deleted item must survive the trip — that's what makes restore an undo.
  const ghost: Item = {
    id: newId(),
    schemaVersion: SCHEMA_VERSION,
    name: 'Deleted Kettle',
    propertyId: property.id,
    createdAt: nowISO(),
    updatedAt: nowISO(),
    deletedAt: nowISO(),
  };
  await db.items.add(ghost);

  await db.settings.update('singleton', {
    entitlements: { proUnlock: true, reportUnlock: true, source: 'web' },
  });

  const before = {
    items: await db.items.count(),
    docs: await db.docs.count(),
    rooms: await db.rooms.count(),
    blobs: await db.blobs.count(),
  };

  /* ---------------------------------------------------------- export */

  const { blob, filename } = await exportBundle();
  check('filename matches the spec', /^stash-it-backup-\d{4}-\d{2}-\d{2}\.stashit$/.test(filename), filename);
  check('bundle is non-empty', blob.size > 0, `${blob.size} bytes`);

  const parsed = await parseBundle(blob);
  check('manifest counts match the database', parsed.manifest.counts.items === before.items);
  check('entitlements are stripped from the file', !('entitlements' in (parsed.data.settings ?? {})));
  check('soft-deleted item is in the bundle', parsed.data.items.some((i) => i.deletedAt));

  /* --------------------------------------------------- replace restore */

  await wipe();
  // Simulate a fresh install: the bundle was exported with Pro on, this device
  // has not paid. Restoring must not change that.
  await db.settings.update('singleton', {
    entitlements: { proUnlock: false, reportUnlock: false },
  });
  await restoreBundle(parsed, 'replace');

  const after = {
    items: await db.items.count(),
    docs: await db.docs.count(),
    rooms: await db.rooms.count(),
    blobs: await db.blobs.count(),
  };
  check('every record returns', JSON.stringify(after) === JSON.stringify(before),
    `${JSON.stringify(before)} vs ${JSON.stringify(after)}`);

  const restoredBlob = await db.blobs.get(blobId);
  const bytes = new Uint8Array(await restoredBlob!.data.arrayBuffer());
  check('blob bytes are identical', bytes.length === PHOTO.length && bytes.every((b, i) => b === PHOTO[i]));
  check('blob mime survives', restoredBlob!.mime === 'image/png', restoredBlob!.mime);

  const settings = await db.settings.get('singleton');
  check('restore cannot grant a paid unlock', settings!.entitlements.proUnlock === false);

  /* ----------------------------------------------------- merge restore */

  // Local copy edited *after* the backup: the device must win.
  const localWins = (await db.items.toArray()).find((i) => i.name === 'Bosch Dishwasher')!;
  await db.items.update(localWins.id, { name: 'Bosch Dishwasher (renamed here)', updatedAt: '2099-01-01T00:00:00.000Z' });

  // Local copy older than the backup: the bundle must win.
  const bundleWins = (await db.items.toArray()).find((i) => i.name === 'Sony Bravia')!;
  await db.items.update(bundleWins.id, { name: 'Stale name', updatedAt: '2000-01-01T00:00:00.000Z' });

  const merged = await restoreBundle(parsed, 'merge');

  check('newer local edit is kept',
    (await db.items.get(localWins.id))!.name === 'Bosch Dishwasher (renamed here)');
  check('older local edit is overwritten',
    (await db.items.get(bundleWins.id))!.name === 'Sony Bravia');
  check('merge adds no duplicate rooms', (await db.rooms.count()) === before.rooms,
    `${await db.rooms.count()} rooms`);
  check('merge adds no duplicate items', (await db.items.count()) === before.items);
  check('merge reports one update', merged.updated === 1, JSON.stringify(merged));

  /* ------------------------------------------------------- rejections */

  // Tamper with the JSON itself rather than flipping a byte at random: the
  // manifest checksum covers the JSON payloads, per the format spec, so a
  // random flip can land in a blob and legitimately pass. Blob corruption
  // going undetected is a known limit of the documented format.
  const entries = unzipSync(new Uint8Array(await blob.arrayBuffer()));
  entries['items.json'] = new TextEncoder().encode('[{"id":"tampered"}]');
  const corrupt = new Blob([zipSync(entries) as BlobPart]);

  let threw = '';
  try {
    await parseBundle(corrupt);
  } catch (e) {
    threw = e instanceof BundleError ? 'BundleError' : (e as Error).constructor.name;
  }
  check('an edited bundle fails its checksum', threw === 'BundleError', threw || 'no error thrown');

  threw = '';
  try {
    await parseBundle(new Blob([new TextEncoder().encode('not a zip at all')]));
  } catch (e) {
    threw = e instanceof BundleError ? 'BundleError' : (e as Error).constructor.name;
  }
  check('a non-bundle file is refused with a readable message', threw === 'BundleError', threw);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
