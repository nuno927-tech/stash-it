/**
 * Preferences and photo removal.
 *
 *   npm run test:prefs
 *
 * The photo case is a regression test: Remove used to look like it worked and
 * then quietly restore the photo, because "removed" and "untouched" were the
 * same value by the time they reached the database.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import { putBlob } from '@/db/repo';
import {
  emptyForm,
  formFromItem,
  saveEditedItem,
  saveNewItem,
} from '@/lib/addItem';
import { attachFile } from '@/lib/docs';
import { DEFAULT_PREFS, prefsFrom, resolveTheme, setPref } from '@/lib/prefs';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;

  /* -------------------------------------------------------- preferences */

  const fresh = await db.settings.get('singleton');
  check('a record written before prefs existed still reads', prefsFrom(fresh).theme === 'system');
  check('sounds default to on', prefsFrom(fresh).sounds === true);
  check('haptics default to on', prefsFrom(fresh).haptics === true);
  check('undefined settings still yield defaults', prefsFrom(undefined).theme === DEFAULT_PREFS.theme);

  await setPref('theme', 'light');
  await setPref('sounds', false);
  check('a preference persists', prefsFrom(await db.settings.get('singleton')).theme === 'light');
  // Explicitly stored `false` has to win over a default of true — the whole
  // point of a default is that it stops applying once someone answers.
  check('turning one off persists', prefsFrom(await db.settings.get('singleton')).sounds === false);

  await setPref('sounds', true);
  check(
    'turning it back on persists too',
    prefsFrom(await db.settings.get('singleton')).sounds === true,
  );

  check('system resolves to dark when the device is dark', resolveTheme('system', true) === 'dark');
  check('system resolves to light when it is not', resolveTheme('system', false) === 'light');
  check('an explicit choice ignores the device', resolveTheme('light', true) === 'light');
  check('dark stays dark', resolveTheme('dark', false) === 'dark');

  /* ------------------------------------------------------ photo removal */

  const photoBlob = await putBlob(new Blob([new Uint8Array([9, 9, 9])], { type: 'image/webp' }));
  const thumbBlob = await putBlob(new Blob([new Uint8Array([1, 1, 1])], { type: 'image/webp' }));

  const id = await saveNewItem({ ...emptyForm('USD'), purchaseDate: '2026-03-01', name: 'Photographed Kettle' }, property.id, {
    blobId: photoBlob,
    thumbBlobId: thumbBlob,
  });
  check('the item starts with a photo', (await db.items.get(id))!.thumbBlobId === thumbBlob);
  // Both sizes are recorded. Before this, only the thumbnail was — so every
  // photo ever taken left its full-size original in the database with nothing
  // pointing at it, invisible and impossible to clean up.
  check(
    'and with the full-size original',
    (await db.items.get(id))!.photoBlobId === photoBlob,
    String((await db.items.get(id))!.photoBlobId),
  );

  // Editing something else must not disturb the photo.
  await saveEditedItem(
    id,
    { ...formFromItem((await db.items.get(id))!, 'USD'), name: 'Renamed Kettle' },
    property.id,
  );
  check(
    'an unrelated edit keeps the photo',
    (await db.items.get(id))!.thumbBlobId === thumbBlob,
    String((await db.items.get(id))!.thumbBlobId),
  );
  check('and keeps the file', (await db.blobs.get(thumbBlob)) !== undefined);

  // Now remove it explicitly.
  await saveEditedItem(id, formFromItem((await db.items.get(id))!, 'USD'), property.id, null);
  check(
    'removing clears the reference',
    (await db.items.get(id))!.thumbBlobId === undefined,
    String((await db.items.get(id))!.thumbBlobId),
  );
  check('and clears the full-size reference too', (await db.items.get(id))!.photoBlobId === undefined);
  check('and bins the orphaned thumbnail', (await db.blobs.get(thumbBlob)) === undefined);
  check('and the orphaned original with it', (await db.blobs.get(photoBlob)) === undefined);

  /* ------------------- a shared file survives one of its owners leaving */

  const shared = await putBlob(new Blob([new Uint8Array([7, 7, 7])], { type: 'image/webp' }));
  const itemA = await saveNewItem({ ...emptyForm('USD'), purchaseDate: '2026-03-01', name: 'Item A' }, property.id, {
    blobId: shared,
    thumbBlobId: shared,
  });
  await attachFile(
    itemA,
    'photo',
    new File([new Uint8Array([7, 7, 7])], 'same.webp', { type: 'image/webp' }),
  );

  await saveEditedItem(itemA, formFromItem((await db.items.get(itemA))!, 'USD'), property.id, null);
  check(
    'a file still referenced by a document survives removal',
    (await db.blobs.get(shared)) !== undefined,
  );

  /* ------------------------------------------------- replacing a photo */

  const first = await putBlob(new Blob([new Uint8Array([2, 2])], { type: 'image/webp' }));
  const second = await putBlob(new Blob([new Uint8Array([3, 3])], { type: 'image/webp' }));
  const swap = await saveNewItem({ ...emptyForm('USD'), purchaseDate: '2026-03-01', name: 'Swappable' }, property.id, {
    blobId: first,
    thumbBlobId: first,
  });
  await saveEditedItem(swap, formFromItem((await db.items.get(swap))!, 'USD'), property.id, {
    blobId: second,
    thumbBlobId: second,
  });
  check('replacing points at the new file', (await db.items.get(swap))!.thumbBlobId === second);
  check('and bins the old one', (await db.blobs.get(first)) === undefined);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
