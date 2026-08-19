/**
 * Document attachment, deletion and backup survival.
 *
 *   npm run test:docs
 *
 * The things that would quietly lose a user's paperwork: a shared blob deleted
 * out from under a second reference, a PDF that doesn't survive the zip, and a
 * linked doc that restores without its URL.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import { DocValidationError, assertDocValid, createDoc, putBlob } from '@/db/repo';
import { blankCoverage, saveNewItem, emptyForm } from '@/lib/addItem';
import {
  attachFile,
  attachLink,
  changeDocKind,
  deleteDoc,
  docHeadline,
  docsWithFiles,
  docSubtitle,
  isBlobReferenced,
  renameDoc,
  titleFromFilename,
} from '@/lib/docs';
import { exportBundle, parseBundle, restoreBundle } from '@/lib/backup';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

// A tiny but real PDF, so the bytes going through the zip are a genuine file.
const PDF_BYTES = new TextEncoder().encode(
  '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n',
);

function pdf(name = 'warranty.pdf'): File {
  return new File([PDF_BYTES], name, { type: 'application/pdf' });
}

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;
  const itemId = await saveNewItem(
    {
      ...emptyForm('USD'),
      name: 'Bosch Dishwasher',
      purchaseDate: '2026-01-10',
      coverages: [blankCoverage({ unit: 'months', amount: '24' })],
    },
    property.id,
  );

  /* -------------------------------------------------------- validation */

  let threw = '';
  try {
    assertDocValid({ storageMode: 'linked', url: undefined, blobId: undefined });
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('a linked doc without a URL is refused', threw === 'DocValidationError', threw);

  threw = '';
  try {
    assertDocValid({ storageMode: 'local', url: 'https://x.com', blobId: undefined });
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('a local doc without a file is refused', threw === 'DocValidationError', threw);
  check('DocValidationError is exported for callers', new DocValidationError('x').message === 'x');

  /* ------------------------------------------------------------ titles */

  check('extension is stripped from the title', titleFromFilename('warranty.pdf') === 'Warranty');
  check(
    'underscores become spaces',
    titleFromFilename('bosch_extended_cover.PDF') === 'Bosch extended cover',
  );
  check('a dotfile-ish name degrades gracefully', titleFromFilename('.pdf') === '');

  /* ----------------------------------------------------------- attach */

  const warrantyDocId = await attachFile(itemId, 'warranty', pdf(), '');
  const receiptDocId = await attachFile(
    itemId,
    'receipt',
    new File([new Uint8Array([1, 2, 3, 4])], 'receipt.jpg', { type: 'image/jpeg' }),
    'Purchase receipt',
  );
  await attachLink(itemId, 'manual', 'bosch-home.com/manuals/SHXM4AY55N');

  const docs = await docsWithFiles(itemId);
  check('all three attach', docs.length === 3, `${docs.length}`);

  const warrantyDoc = docs.find((d) => d.id === warrantyDocId)!;
  check('title falls back to the filename', warrantyDoc.title === 'Warranty', warrantyDoc.title);
  check('the PDF mime is recorded', warrantyDoc.mime === 'application/pdf', warrantyDoc.mime);
  check('the byte count is recorded', warrantyDoc.bytes === PDF_BYTES.length, `${warrantyDoc.bytes}`);

  const linkDoc = docs.find((d) => d.storageMode === 'linked')!;
  check('a bare domain gains a scheme', linkDoc.url?.startsWith('https://') === true, linkDoc.url);
  check('the link title defaults to the host', linkDoc.title === 'bosch-home.com', linkDoc.title);
  check('a new link starts unchecked', linkDoc.linkStatus === 'unchecked');

  threw = '';
  try {
    await attachLink(itemId, 'manual', 'not a url');
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('a junk link is refused', threw === 'DocError', threw);

  threw = '';
  try {
    await attachFile(itemId, 'receipt', new File([], 'empty.pdf', { type: 'application/pdf' }));
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('an empty file is refused', threw === 'DocError', threw);

  /* --------------------------------------------------- reclassifying */

  // The reported case: a receipt photographed while the kind chip still said
  // warranty, discovered later.
  const misfiled = await attachFile(
    itemId,
    'warranty',
    new File([new Uint8Array([9, 9])], 'IMG_2201.jpg', { type: 'image/jpeg' }),
  );
  check('it starts out as a warranty', (await db.docs.get(misfiled))!.kind === 'warranty');
  check(
    'auto-titled after its kind',
    (await db.docs.get(misfiled))!.title === 'Warranty',
    (await db.docs.get(misfiled))!.title,
  );

  await changeDocKind(misfiled, 'receipt');
  const fixed = (await db.docs.get(misfiled))!;
  check('the kind changes', fixed.kind === 'receipt');
  check('the auto title follows it', fixed.title === 'Receipt', fixed.title);
  check('the row now reads Receipt', docHeadline(fixed) === 'Receipt');
  check('and adds no noisy subtitle', docSubtitle(fixed) === null);
  check('the file is untouched', fixed.blobId === (await db.docs.get(misfiled))!.blobId);
  check('updatedAt moves', fixed.updatedAt >= fixed.createdAt);

  // A title the user wrote is theirs, and must survive a type change.
  const named = await attachFile(
    itemId,
    'warranty',
    new File([new Uint8Array([8, 8])], 'x.pdf', { type: 'application/pdf' }),
    'Extended cover certificate',
  );
  await changeDocKind(named, 'receipt');
  check(
    'a hand-written title is preserved',
    (await db.docs.get(named))!.title === 'Extended cover certificate',
    (await db.docs.get(named))!.title,
  );
  check('while the kind still changes', (await db.docs.get(named))!.kind === 'receipt');

  const before = (await db.docs.get(named))!.updatedAt;
  await changeDocKind(named, 'receipt');
  check('changing to the same kind is a no-op', (await db.docs.get(named))!.updatedAt === before);

  await changeDocKind('does-not-exist', 'receipt');
  check('reclassifying a missing document does not throw', true);

  /* ------------------------------------------------------- renaming */

  // Attaching no longer asks for a title, so this is the only way one gets
  // written by hand. It has to behave like the attach path did.
  await renameDoc(named, '  Bosch cover, 5 year  ');
  const renamed = (await db.docs.get(named))!;
  check('a new title is saved, trimmed', renamed.title === 'Bosch cover, 5 year', renamed.title);
  check('and shows as the subtitle', docSubtitle(renamed) === 'Bosch cover, 5 year');

  await renameDoc(named, '   ');
  const blanked = (await db.docs.get(named))!;
  check('clearing it falls back to the kind', blanked.title === 'Receipt', blanked.title);
  check('so the row never goes nameless', docHeadline(blanked) === 'Receipt');
  check('and the empty title adds no subtitle', docSubtitle(blanked) === null);

  const stamp = (await db.docs.get(named))!.updatedAt;
  await renameDoc(named, 'Receipt');
  check('renaming to the same title is a no-op', (await db.docs.get(named))!.updatedAt === stamp);

  await renameDoc('does-not-exist', 'Anything');
  check('renaming a missing document does not throw', true);

  // Clean up so the counts below stay meaningful.
  await deleteDoc(misfiled);
  await deleteDoc(named);

  /* ---------------------------------------------- blobs are deduped */

  const blobCountBefore = await db.blobs.count();
  await attachFile(itemId, 'other', pdf('copy-of-warranty.pdf'));
  check(
    'the same file attached twice stores one blob',
    (await db.blobs.count()) === blobCountBefore,
    `${blobCountBefore} → ${await db.blobs.count()}`,
  );

  /* ------------------------------------------------------------ delete */

  const sharedBlobId = (await db.docs.get(warrantyDocId))!.blobId!;
  await deleteDoc(warrantyDocId);
  check('the deleted doc leaves the list', (await docsWithFiles(itemId)).length === 3);
  check(
    'a blob still referenced elsewhere survives',
    (await db.blobs.get(sharedBlobId)) !== undefined,
  );
  check('the shared blob is still reported as referenced', await isBlobReferenced(sharedBlobId));

  // Now remove the second reference: the blob should go.
  const copy = (await docsWithFiles(itemId)).find((d) => d.kind === 'other')!;
  await deleteDoc(copy.id);
  check('the orphaned blob is cleaned up', (await db.blobs.get(sharedBlobId)) === undefined);
  check('no phantom reference remains', !(await isBlobReferenced(sharedBlobId)));

  /* -------------------------------------------------- backup survival */

  const { blob } = await exportBundle();
  const parsed = await parseBundle(blob);
  check(
    'soft-deleted docs travel in the bundle',
    parsed.data.docs.length === 6,
    `${parsed.data.docs.length} docs`,
  );

  await Promise.all([db.docs.clear(), db.blobs.clear(), db.items.clear()]);
  await restoreBundle(parsed, 'replace');

  const restored = await docsWithFiles(itemId);
  check('documents come back', restored.length === 2, `${restored.length}`);

  const restoredReceipt = restored.find((d) => d.id === receiptDocId)!;
  check('the receipt survives with its title', restoredReceipt.title === 'Purchase receipt');
  check('its mime survives the zip', restoredReceipt.mime === 'image/jpeg', restoredReceipt.mime);

  const restoredLink = restored.find((d) => d.storageMode === 'linked')!;
  check('the linked doc keeps its URL', !!restoredLink.url, restoredLink.url);
  check('a linked doc restores without a blob', restoredLink.blobId === undefined);

  const restoredBlob = await db.blobs.get(restoredReceipt.blobId!);
  const bytes = new Uint8Array(await restoredBlob!.data.arrayBuffer());
  check('file bytes are identical after the round trip', bytes.join(',') === '1,2,3,4', bytes.join(','));

  /* ------------------------------------------ a doc needs a real item */

  threw = '';
  try {
    await createDoc({
      itemId,
      kind: 'receipt',
      storageMode: 'local',
      blobId: await putBlob(new Blob(['x'])),
    });
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('a valid doc still saves after all that', threw === '', threw);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
