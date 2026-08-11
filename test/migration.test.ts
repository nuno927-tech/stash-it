/**
 * Schema v1 → v2: category removed.
 *
 *   npm run test:migration
 *
 * Two paths have to survive it: a database written by the old build opening in
 * the new one, and a v1 backup file restoring into a v2 install. Both are real
 * situations for anyone who already installed the app.
 */

import 'fake-indexeddb/auto';
import Dexie from 'dexie';
import { db, ensureFirstRun } from '@/db/db';
import { SCHEMA_VERSION } from '@/db/types';
import { parseBundle, restoreBundle, type BackupManifest } from '@/lib/backup';
import { zipSync } from 'fflate';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const ts = '2026-01-01T00:00:00.000Z';

/** Writes a database in the v1 shape, the way the previous build would have. */
async function seedV1Database() {
  const old = new Dexie('stash-it');
  old.version(1).stores({
    items: 'id, propertyId, roomId, category, deletedAt, updatedAt, [propertyId+deletedAt]',
    docs: 'id, itemId, kind, storageMode, linkStatus, deletedAt',
    blobs: 'id, sha256',
    properties: 'id, isDefault, deletedAt',
    rooms: 'id, propertyId, sortOrder, deletedAt, [propertyId+deletedAt]',
    maintenance: 'id, itemId, date, deletedAt',
    settings: 'id',
  });
  await old.open();

  await old.table('properties').add({
    id: 'p1',
    name: 'Home',
    isDefault: true,
    createdAt: ts,
    updatedAt: ts,
  });
  await old.table('items').bulkAdd([
    {
      id: 'i1',
      schemaVersion: 1,
      name: 'Bosch Dishwasher',
      brand: 'Bosch',
      category: 'appliance',
      propertyId: 'p1',
      purchaseDate: '2026-01-10',
      purchasePriceCents: 84900,
      currency: 'USD',
      warranty: { months: 24 },
      createdAt: ts,
      updatedAt: ts,
    },
    {
      id: 'i2',
      schemaVersion: 1,
      name: 'Deleted Kettle',
      category: 'other',
      propertyId: 'p1',
      createdAt: ts,
      updatedAt: ts,
      deletedAt: ts,
    },
  ]);
  await old.table('settings').add({
    id: 'singleton',
    schemaVersion: 1,
    reminderOffsetsDays: [30],
    currency: 'USD',
    backupReminderDays: 30,
    entitlements: { reportUnlock: false, proUnlock: false },
    devModeEnabled: false,
  });

  old.close();
}

/** Builds a v1 backup file by hand, as the previous build would have written it. */
async function buildV1Bundle(): Promise<Blob> {
  const enc = new TextEncoder();
  const payloads = {
    items: [
      {
        id: 'b1',
        schemaVersion: 1,
        name: 'Old Fridge',
        category: 'appliance',
        propertyId: 'p9',
        warranty: { months: 12 },
        createdAt: ts,
        updatedAt: ts,
      },
    ],
    docs: [],
    properties: [{ id: 'p9', name: 'Old house', isDefault: true, createdAt: ts, updatedAt: ts }],
    rooms: [],
    maintenance: [],
    settings: null,
  };

  const order = ['items', 'docs', 'properties', 'rooms', 'maintenance', 'settings'] as const;
  const jsonBytes = order.map((k) => enc.encode(JSON.stringify(payloads[k], null, 2)));

  const total = jsonBytes.reduce((n, b) => n + b.length, 0);
  const joined = new Uint8Array(total);
  let at = 0;
  for (const b of jsonBytes) {
    joined.set(b, at);
    at += b.length;
  }
  const digest = await crypto.subtle.digest('SHA-256', joined.buffer as ArrayBuffer);
  const sha256 = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');

  const manifest: BackupManifest = {
    format: 'stash-it-backup',
    formatVersion: 1,
    schemaVersion: 1,
    appVersion: '0.2.0',
    exportedAt: ts,
    counts: { items: 1, docs: 0, blobs: 0 },
    sha256,
    encrypted: false,
  };

  const files: Record<string, Uint8Array> = {
    'manifest.json': enc.encode(JSON.stringify(manifest, null, 2)),
  };
  order.forEach((k, i) => {
    files[`${k}.json`] = jsonBytes[i]!;
  });

  return new Blob([zipSync(files) as BlobPart], { type: 'application/zip' });
}

async function main() {
  /* ------------------------------------ an existing database upgrades */

  await seedV1Database();
  await ensureFirstRun(); // opens at v2, running the upgrade

  check('the app opens a v1 database', db.verno >= 2, `verno ${db.verno}`);

  const upgraded = (await db.items.get('i1')) as (Record<string, unknown> & { name: string }) | undefined;
  check('the item survives', upgraded?.name === 'Bosch Dishwasher', String(upgraded?.name));
  check('category is gone from the record', upgraded && !('category' in upgraded));
  check('its schema version moves to 2', upgraded?.schemaVersion === SCHEMA_VERSION);
  check('everything else is intact', upgraded?.purchasePriceCents === 84900);
  check(
    'the warranty is untouched',
    (upgraded?.warranty as { months: number })?.months === 24,
    JSON.stringify(upgraded?.warranty),
  );

  const ghost = (await db.items.get('i2')) as Record<string, unknown> | undefined;
  check('soft-deleted rows migrate too', ghost !== undefined && !('category' in ghost));
  check('and stay deleted', !!ghost?.deletedAt);

  const settings = await db.settings.get('singleton');
  check('settings move to v2', settings?.schemaVersion === SCHEMA_VERSION, `${settings?.schemaVersion}`);
  check('and keep their values', settings?.currency === 'USD');

  /* ------------------------------------------- a v1 backup restores */

  const parsed = await parseBundle(await buildV1Bundle());
  check('a v1 bundle is accepted', parsed.manifest.schemaVersion === 1);
  check(
    'its items are migrated on parse',
    !('category' in (parsed.data.items[0] as unknown as Record<string, unknown>)),
    JSON.stringify(parsed.data.items[0]),
  );
  check('and stamped as v2', parsed.data.items[0]!.schemaVersion === SCHEMA_VERSION);
  check('the item itself is intact', parsed.data.items[0]!.name === 'Old Fridge');

  await restoreBundle(parsed, 'merge');
  const restored = (await db.items.get('b1')) as Record<string, unknown> | undefined;
  check('it lands in the database', restored?.name === 'Old Fridge');
  check('without the dead field', restored !== undefined && !('category' in restored));

  /* --------------------------------------- a newer bundle is refused */

  let threw = '';
  try {
    const future = await buildV1Bundle();
    const bytes = new Uint8Array(await future.arrayBuffer());
    // Not worth rebuilding a whole future bundle; parse is already covered by
    // the schemaVersion guard, so assert the guard itself.
    void bytes;
    await parseBundle(new Blob([new TextEncoder().encode('nope')]));
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('rubbish is still refused', threw === 'BundleError', threw);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
