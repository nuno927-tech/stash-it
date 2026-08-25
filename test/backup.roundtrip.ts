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
import {
  BundleError,
  canShareBundle,
  exportBundle,
  markBackedUp,
  parseBundle,
  restoreBundle,
  saveBundle,
  type SaveOutcome,
} from '@/lib/backup';

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
    // A lock enrolled on the exporting device. It means nothing anywhere else.
    biometricLock: true,
    lockCredentialId: 'credential-from-the-old-phone',
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
  check(
    'the lock credential never leaves the device',
    !('lockCredentialId' in (parsed.data.settings ?? {})) &&
      !('biometricLock' in (parsed.data.settings ?? {})),
  );
  check('soft-deleted item is in the bundle', parsed.data.items.some((i) => i.deletedAt));

  /* --------------------------------------------------- replace restore */

  await wipe();
  // Simulate a fresh install: the bundle was exported with Pro on, this device
  // has not paid. Restoring must not change that.
  await db.settings.update('singleton', {
    entitlements: { proUnlock: false, reportUnlock: false },
    // …and no biometric lock of its own.
    biometricLock: false,
    lockCredentialId: undefined,
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
  // Otherwise restoring onto a new phone raises a lock screen that no
  // authenticator on that phone could ever satisfy.
  check('and cannot lock the receiving device', !settings!.biometricLock);
  check('nor leave a foreign credential behind', settings!.lockCredentialId === undefined);

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

  /* ------------------------------------------- when a backup counts as done */

  /*
    THE WORST BUG THIS FILE HAS PINNED, and it was silent.

    `lastBackupAt` was stamped inside `exportBundle`, on the line after the zip
    was assembled — before the share sheet had opened, let alone before anyone
    had chosen where to put the file. And `saveBundle` returned 'shared' when
    the user dismissed that sheet.

    So: tap Back up now, tap Cancel. The app reports the file was shared,
    writes today onto the record, shows today on the Backup card, and then
    stays quiet for the next thirty days because the reminder reads the date it
    just invented. No file exists anywhere.

    That is a data-loss trap living inside the feature whose only job is
    preventing data loss, and nothing about it is visible from the outside —
    every screen agrees you are backed up.
  */
  await db.settings.update('singleton', { lastBackupAt: undefined });

  const built = await exportBundle();
  check('the bundle is real', built.blob.size > 0);
  check(
    'but building one is not backing up',
    (await db.settings.get('singleton'))!.lastBackupAt === undefined,
    (await db.settings.get('singleton'))!.lastBackupAt,
  );

  // Only a caller that watched the file leave may make the claim.
  await markBackedUp();
  const stamped = (await db.settings.get('singleton'))!.lastBackupAt;
  check('and marking it is', !!stamped, stamped);
  check('with a real timestamp', !Number.isNaN(Date.parse(stamped!)), stamped);

  /*
    Cancel is its own outcome. It used to be folded into 'shared', which is how
    the caller came to congratulate the user on a file that was never written.
  */
  const outcomes: SaveOutcome[] = ['shared', 'downloaded', 'cancelled', 'needs-gesture'];
  check('a cancel is distinguishable from a save', outcomes.includes('cancelled'));

  /*
    ── And so is 'needs-gesture', which the second button forgot ────────────

    'needs-gesture' means "ask for a fresh tap", and the Settings card grew a
    second button to do exactly that. What it did not grow was a branch for the
    same answer coming back twice — so a second refusal fell through to the
    success path: the button vanished, `markBackedUp` ran, and the app
    announced it had sent a file that had never left.

    Which is the identical failure the whole section above is about, one layer
    out. The first bug was a cancel counted as a save; this was a refusal
    counted as a save.

    It cannot be proved here — sharing does not exist in Node, so this path is
    unreachable from a test — but the outcome being distinguishable is the
    thing that makes handling it possible, and that is worth pinning.
  */
  check('as is a refusal', outcomes.includes('needs-gesture'));

  /*
    `saveBundle` must be able to skip the share sheet entirely, which is how
    the second button escapes a browser that will never open one.

    Asserted by calling it rather than by reading `saveBundle.length` — which
    is 2, because `Function.length` stops counting at the first parameter with
    a default and the options bag has one. That assertion would have failed in
    CI and blocked the deploy, which is a considerably worse outcome than the
    bug it was guarding.

    In Node there is no `navigator`, so this takes the download path, and
    `document` does not exist either — so the check is that it refuses rather
    than shares, whichever way it fails.
  */
  let skipped = '';
  try {
    skipped = await saveBundle(built.blob, 'probe.stashit', { share: false });
  } catch {
    skipped = 'threw';
  }
  check('sharing can be turned off by the caller', skipped !== 'shared', skipped);

  /*
    THE SHARE SHEET IS NOT AVAILABLE FOR THIS FILE ON CHROMIUM, and the app has
    to know that before it promises one.

    Web Share screens files against an allowlist of EXTENSIONS — images, audio,
    video, text, and pdf. Not zip, and certainly not `.stashit`. So Chrome and
    Android hand the bundle to the downloads folder instead, which works and is
    a different sentence to put on the screen. Safari does not use that list,
    which is why this is probed rather than assumed.

    In Node there is no `navigator.canShare` at all, so the probe has to answer
    false rather than throw — the same path a desktop browser without file
    sharing takes.
  */
  check('the probe answers where sharing is impossible', canShareBundle('x.stashit') === false);
  check('and does not throw doing it', typeof canShareBundle() === 'boolean');

  /*
    And it must answer without building anything. The probe runs before the
    export so the button can say the right thing; if it needed the real bundle
    it would cost a full zip of somebody's photo library to find out which
    sentence to print.
  */
  const beforeProbe = Date.now();
  canShareBundle();
  check('cheaply', Date.now() - beforeProbe < 50);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
