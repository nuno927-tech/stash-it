/**
 * Add-item logic, run in Node against fake-indexeddb.
 *
 *   npm run test:add
 *
 * The form is deliberately thin — everything worth testing lives in
 * src/lib/addItem.ts, so this exercises the real code path the screen uses.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import { activeItemCount } from '@/db/repo';
import { FREE_ITEM_LIMIT } from '@/db/types';
import {
  draftFromForm,
  emptyForm,
  formFromItem,
  ItemLimitError,
  parseMoneyToCents,
  saveEditedItem,
  saveNewItem,
  ValidationError,
  type AddItemForm,
} from '@/lib/addItem';
import { effectiveExpiry, toISODate, warrantyLabel, warrantyState } from '@/lib/warranty';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

function form(over: Partial<AddItemForm> = {}): AddItemForm {
  return { ...emptyForm('USD'), name: 'Test item', ...over };
}

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;

  /* ------------------------------------------------------------- money */

  const money: [string, number | undefined][] = [
    ['849', 84900],
    ['849.00', 84900],
    ['1,299.99', 129999],
    ['$1,299.99', 129999],
    ['£849.50', 84950],
    ['1.299,99', 129999], // German style: comma is the decimal
    ['1.299', 129900], // ambiguous, treated as thousands — three digits after
    ['0.05', 5],
    ['', undefined],
    ['abc', undefined],
  ];
  for (const [input, expected] of money) {
    const got = parseMoneyToCents(input);
    check(`money "${input}" → ${expected}`, got === expected, got === expected ? '' : `got ${got}`);
  }

  /* -------------------------------------------------------- validation */

  let threw = '';
  try {
    draftFromForm(form({ name: '   ' }), property.id);
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('a blank name is refused', threw === 'ValidationError', threw);
  check('ValidationError carries a usable message', new ValidationError('x').message === 'x');

  /* -------------------------------------------------------------- shape */

  const draft = draftFromForm(
    form({
      name: '  Bosch Dishwasher  ',
      brand: 'Bosch',
      model: '  ',
      category: 'appliance',
      purchaseDate: '2026-03-12',
      price: '$849.00',
      warrantyMonths: '24',
      warrantyProvider: 'Bosch Home',
      notes: '',
    }),
    property.id,
  );

  check('name is trimmed', draft.name === 'Bosch Dishwasher', draft.name);
  check('blank optional fields are dropped, not stored empty', draft.model === undefined);
  check('empty notes are dropped', draft.notes === undefined);
  check('price becomes integer cents', draft.purchasePriceCents === 84900);
  check('currency is stamped on the item', draft.currency === 'USD');
  check('warranty is built', draft.warranty?.months === 24, JSON.stringify(draft.warranty));
  check('warranty provider survives', draft.warranty?.provider === 'Bosch Home');

  const noWarranty = draftFromForm(form({ warrantyMonths: '' }), property.id);
  check('no months means no warranty object', noWarranty.warranty === undefined);
  const zero = draftFromForm(form({ warrantyMonths: '0' }), property.id);
  check('zero months means no warranty object', zero.warranty === undefined);

  /* ------------------------------------------------- expiry integration */

  const id = await saveNewItem(
    form({ name: 'Kettle', purchaseDate: '2026-01-31', warrantyMonths: '24' }),
    property.id,
  );
  const saved = (await db.items.get(id))!;
  const expiry = effectiveExpiry(saved);
  check(
    'calendar-month expiry from the saved record',
    expiry !== null && toISODate(expiry) === '2028-01-31',
    expiry ? toISODate(expiry) : 'null',
  );
  check('saved item is covered today', warrantyState(saved) === 'covered', warrantyLabel(saved));
  check('id is a uuidv7', /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-/.test(id), id);
  check('schema version is stamped', saved.schemaVersion === 1);
  check('createdAt and updatedAt are set', !!saved.createdAt && !!saved.updatedAt);

  /* -------------------------------------------------------------- cap */

  await db.settings.update('singleton', {
    entitlements: { proUnlock: false, reportUnlock: false },
  });

  while ((await activeItemCount(property.id)) < FREE_ITEM_LIMIT) {
    await saveNewItem(form({ name: `Filler ${await activeItemCount(property.id)}` }), property.id);
  }

  threw = '';
  try {
    await saveNewItem(form({ name: 'One too many' }), property.id);
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('the cap blocks item 16', threw === 'ItemLimitError', threw || 'nothing thrown');
  check(
    'the cap message names the way out',
    /Pro/.test(new ItemLimitError().message) && /editable/.test(new ItemLimitError().message),
  );

  // Deleting must free a slot immediately — otherwise the cap is a trap.
  const victim = (await db.items.toArray()).find((i) => i.name.startsWith('Filler'))!;
  await db.items.update(victim.id, { deletedAt: new Date().toISOString() });
  const after = await saveNewItem(form({ name: 'After a delete' }), property.id);
  check('a soft delete frees a slot', !!after);

  // Pro lifts it entirely.
  await db.settings.update('singleton', {
    entitlements: { proUnlock: true, reportUnlock: false },
  });
  const proItem = await saveNewItem(form({ name: 'Past the cap with Pro' }), property.id);
  check('Pro lifts the cap', !!proItem);
  check(
    'count is past the free limit',
    (await activeItemCount(property.id)) > FREE_ITEM_LIMIT,
    `${await activeItemCount(property.id)} items`,
  );

  /* -------------------------------------------------------------- edit */

  const editId = await saveNewItem(
    form({
      name: 'Editable Kettle',
      price: '49.99',
      warrantyMonths: '12',
      purchaseDate: '2026-02-01',
    }),
    property.id,
    { blobId: 'blob-full', thumbBlobId: 'blob-thumb' },
  );
  const original = (await db.items.get(editId))!;
  check('photo thumb is stored on create', original.thumbBlobId === 'blob-thumb');

  // Editing without touching the photo must keep it.
  await saveEditedItem(
    editId,
    formFromItem({ ...original, name: 'Renamed Kettle' }, 'USD'),
    property.id,
  );
  const edited = (await db.items.get(editId))!;
  check('edit renames', edited.name === 'Renamed Kettle', edited.name);
  check('edit keeps the existing photo', edited.thumbBlobId === 'blob-thumb', edited.thumbBlobId);
  check('edit preserves createdAt', edited.createdAt === original.createdAt);
  check('edit moves updatedAt forward', edited.updatedAt >= original.updatedAt);
  check('edit round-trips the price', edited.purchasePriceCents === 4999);
  check('edit round-trips the warranty', edited.warranty?.months === 12);

  // A new photo replaces the old reference.
  await saveEditedItem(editId, formFromItem(edited, 'USD'), property.id, {
    blobId: 'blob-full-2',
    thumbBlobId: 'blob-thumb-2',
  });
  check(
    'a new photo replaces the old one',
    (await db.items.get(editId))!.thumbBlobId === 'blob-thumb-2',
  );

  // Clearing the warranty must actually remove it, not leave a stale object.
  const cleared = formFromItem((await db.items.get(editId))!, 'USD');
  cleared.warrantyMonths = '';
  await saveEditedItem(editId, cleared, property.id);
  check(
    'clearing months removes the warranty',
    (await db.items.get(editId))!.warranty === undefined,
    JSON.stringify((await db.items.get(editId))!.warranty),
  );

  // Editing is never blocked by the cap — the item already exists.
  await db.settings.update('singleton', {
    entitlements: { proUnlock: false, reportUnlock: false },
  });
  const overCap = await activeItemCount(property.id);
  await saveEditedItem(
    editId,
    { ...formFromItem((await db.items.get(editId))!, 'USD'), name: 'Edited past the cap' },
    property.id,
  );
  check(
    'edits work past the free cap',
    (await db.items.get(editId))!.name === 'Edited past the cap',
    `${overCap} items`,
  );

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
