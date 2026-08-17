/**
 * Documents staged during add.
 *
 *   npm run test:staged
 *
 * The rule that matters: nothing touches the database until the item exists.
 * Abandoning the add form must leave no blobs and no orphaned documents.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import { emptyForm, saveNewItem } from '@/lib/addItem';
import { attachStaged, docsWithFiles, DocError, stageDoc, stageLink } from '@/lib/docs';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const file = (name: string, bytes: number[], type = 'application/pdf') =>
  new File([new Uint8Array(bytes)], name, { type });

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;

  /* ------------------------------------------------- staging is inert */

  const blobsBefore = await db.blobs.count();
  const docsBefore = await db.docs.count();

  const receipt = stageDoc('receipt', file('IMG_20260810.jpg', [1, 2, 3], 'image/jpeg'));
  const warranty = stageDoc('warranty', file('cover.pdf', [4, 5, 6]));
  const manual = stageDoc('manual', file('manual.pdf', [7, 8, 9]));

  check('staging writes no blob', (await db.blobs.count()) === blobsBefore);
  check('staging writes no document', (await db.docs.count()) === docsBefore);
  check('each staged file gets its own key', new Set([receipt.key, warranty.key, manual.key]).size === 3);
  check('the kind is carried', receipt.kind === 'receipt');

  let threw = '';
  try {
    stageDoc('receipt', new File([], 'empty.pdf', { type: 'application/pdf' }));
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('an empty file is refused at staging time', threw === 'DocError', threw);
  check('DocError is the type callers can catch', new DocError('x') instanceof DocError);

  /* --------------------------------------- abandoning leaves no trace */

  check('abandoning the form leaves no blobs', (await db.blobs.count()) === blobsBefore);
  check('abandoning the form leaves no documents', (await db.docs.count()) === docsBefore);

  /* ------------------------------------------ flushing against an item */

  const id = await saveNewItem({ ...emptyForm('USD'), purchaseDate: '2026-03-01', name: 'Bosch Dishwasher' }, property.id);
  const written = await attachStaged(id, [receipt, warranty, manual]);
  check('all three are written', written === 3, `${written}`);

  const docs = await docsWithFiles(id);
  check('the item has three documents', docs.length === 3, `${docs.length}`);
  check('they belong to the new item', docs.every((d) => d.itemId === id));
  check(
    'kinds survive staging',
    ['receipt', 'warranty', 'manual'].every((k) => docs.some((d) => d.kind === k)),
    docs.map((d) => d.kind).join(', '),
  );

  const photographed = docs.find((d) => d.kind === 'receipt')!;
  check('a camera filename still becomes the kind', photographed.title === 'Receipt', photographed.title);
  const named = docs.find((d) => d.kind === 'warranty')!;
  check('a real filename still becomes the title', named.title === 'Cover', named.title);

  check('bytes are stored', photographed.bytes === 3, `${photographed.bytes}`);
  check('mime survives', photographed.mime === 'image/jpeg', photographed.mime);

  /* ------------------------------------------------------------ dedupe */

  const second = await saveNewItem({ ...emptyForm('USD'), purchaseDate: '2026-03-01', name: 'Second item' }, property.id);
  const blobsNow = await db.blobs.count();
  await attachStaged(second, [stageDoc('receipt', file('cover.pdf', [4, 5, 6]))]);
  check(
    'an identical file attached to another item reuses the blob',
    (await db.blobs.count()) === blobsNow,
    `${blobsNow} → ${await db.blobs.count()}`,
  );
  check('but the second item gets its own document', (await docsWithFiles(second)).length === 1);

  /* --------------------------------------------------- staged links */

  /*
    A link was the one attachment you couldn't make while adding an item: the
    dialog wrote straight to the database and there was no row yet, so the
    control was simply missing from the add form and present on the item page.
    It stages now, like a file.
  */
  const staged = stageLink('manual', 'bosch-home.com/manuals/SHXM4AY55N');
  check('a staged link holds no file', staged.file === undefined);
  check('and carries a normalised url', staged.url === 'https://bosch-home.com/manuals/SHXM4AY55N', staged.url);
  check('titled by hostname when nobody writes one', staged.title === 'bosch-home.com', staged.title);
  check('www is not part of a name', stageLink('manual', 'www.ikea.com/x').title === 'ikea.com');

  // Refused here rather than on save. Being told "that doesn't look like a web
  // address" two screens after typing it is not a useful place to find out.
  let bad = '';
  try {
    stageLink('manual', 'not a url');
  } catch (e) {
    bad = (e as Error).message;
  }
  check('rubbish is refused at the dialog', /web address/.test(bad), bad);
  check('and so is nothing at all', (() => {
    try { stageLink('manual', '   '); return ''; } catch (e) { return (e as Error).message; }
  })().includes('Paste a link'));

  const withLink = await saveNewItem(
    { ...emptyForm('USD'), purchaseDate: '2026-03-01', name: 'Dishwasher' },
    property.id,
  );
  const blobsAtLink = await db.blobs.count();
  check('one link written', (await attachStaged(withLink, [staged])) === 1);

  const linked = (await docsWithFiles(withLink))[0]!;
  check('it lands as a linked document', linked.storageMode === 'linked', linked.storageMode);
  check('with the url intact', linked.url === 'https://bosch-home.com/manuals/SHXM4AY55N', linked.url);
  check('and no blob behind it', (await db.blobs.count()) === blobsAtLink);

  // A file and a link in the same batch, which is the realistic case.
  const mixed = await saveNewItem(
    { ...emptyForm('USD'), purchaseDate: '2026-03-01', name: 'Mixed' },
    property.id,
  );
  const bothWritten = await attachStaged(mixed, [
    stageDoc('receipt', file('till.pdf', [9, 9, 9])),
    stageLink('manual', 'example.com/manual.pdf'),
  ]);
  check('both kinds attach together', bothWritten === 2, `${bothWritten}`);
  const both = await docsWithFiles(mixed);
  check('one stored, one linked', both.filter((d) => d.storageMode === 'linked').length === 1);

  /* ------------------------------------------- nothing staged is fine */

  const bare = await saveNewItem({ ...emptyForm('USD'), purchaseDate: '2026-03-01', name: 'No paperwork' }, property.id);
  check('attaching nothing writes nothing', (await attachStaged(bare, [])) === 0);
  check('and the item is still fine', (await docsWithFiles(bare)).length === 0);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
