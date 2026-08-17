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
import { activeItemCount, canAddItem } from '@/db/repo';
import { FREE_ITEM_LIMIT, SCHEMA_VERSION } from '@/db/types';
import {
  blankCoverage,
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
import { cardFilled } from '@/components/useAutoAdvance';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

/*
  A purchase date by default. It became required for new items when the form
  was rebuilt into sections — the countdown is arithmetic on it — so a helper
  without one would now be testing the refusal on every single case.
*/
function form(over: Partial<AddItemForm> = {}): AddItemForm {
  return { ...emptyForm('USD'), name: 'Test item', purchaseDate: '2026-03-01', ...over };
}

/** One plain warranty, the way the form holds it. */
function cover(over: Partial<Parameters<typeof blankCoverage>[0]> = {}) {
  return [blankCoverage({ amount: '24', ...over })];
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

  /*
    The purchase date. Required on a new item because every countdown in the
    app subtracts from it: a warranty length with no start date produces an
    item that permanently reads "no warranty recorded", however much cover was
    typed in.
  */
  let dateMsg = '';
  try {
    draftFromForm(form({ purchaseDate: '' }), property.id);
  } catch (e) {
    dateMsg = (e as Error).message;
  }
  check('a new item without a date is refused', /purchase date/i.test(dateMsg), dateMsg);
  check('and the message says why', /countdown/i.test(dateMsg), dateMsg);

  // Edits opt out — see the note in draftFromForm. Records predate the rule,
  // and some purchase dates are honestly unknown; an invented one counts down
  // to a day that means nothing, which is worse than none at all.
  check(
    'an edit of a dateless record is allowed through',
    draftFromForm(form({ purchaseDate: '' }), property.id, undefined, false).name === 'Test item',
  );

  /* ------------------------------------------------- the coverage default */

  /*
    A new policy row starts on "Warranty" rather than unpicked. `toCoverage`
    already fell back to that name for a blank label, so the empty row was
    asking a question it was going to answer the same way anyway — while
    looking, with none of the six buttons lit, like something you had to
    answer before saving.
  */
  check('a blank form starts on Warranty', emptyForm('USD').coverages[0]!.label === 'Warranty');
  check('and so does a second policy', blankCoverage().label === 'Warranty');
  check('an explicit label still wins', blankCoverage({ label: 'Fabric' }).label === 'Fabric');
  // The fallback stays, for records and forms built before this default.
  check(
    'a cleared label still saves as Warranty',
    draftFromForm(form({ coverages: cover({ label: '' }) }), property.id).coverages?.[0]?.label ===
      'Warranty',
  );

  /* -------------------------------------------------------------- shape */

  const draft = draftFromForm(
    form({
      name: '  Bosch Dishwasher  ',
      brand: 'Bosch',
      model: '  ',
      purchaseDate: '2026-03-12',
      price: '$849.00',
      coverages: cover({ provider: 'Bosch Home' }),
      notes: '',
    }),
    property.id,
  );

  check('name is trimmed', draft.name === 'Bosch Dishwasher', draft.name);
  check('blank optional fields are dropped, not stored empty', draft.model === undefined);
  check('empty notes are dropped', draft.notes === undefined);
  check('price becomes integer cents', draft.purchasePriceCents === 84900);
  check('currency is stamped on the item', draft.currency === 'USD');
  check('a coverage is built', draft.coverages?.length === 1, JSON.stringify(draft.coverages));
  check('it takes the default name', draft.coverages?.[0]?.label === 'Warranty');
  check('provider survives', draft.coverages?.[0]?.provider === 'Bosch Home');
  // The two old fields are still written, so a backup opened on a phone that
  // hasn't updated shows one warranty rather than none.
  check('the legacy field is mirrored', draft.warranty?.months === 24, JSON.stringify(draft.warranty));
  check('with its provider', draft.warranty?.provider === 'Bosch Home');

  const noWarranty = draftFromForm(form({ coverages: cover({ amount: '' }) }), property.id);
  check('a blank term saves no coverage', noWarranty.coverages === undefined);
  check('and no legacy warranty either', noWarranty.warranty === undefined);
  const zero = draftFromForm(form({ coverages: cover({ amount: '0' }) }), property.id);
  check('zero is not a term', zero.coverages === undefined);

  /* ------------------------------------------------- expiry integration */

  const id = await saveNewItem(
    form({ name: 'Kettle', purchaseDate: '2026-01-31', coverages: cover() }),
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
  check('schema version is stamped', saved.schemaVersion === SCHEMA_VERSION, String(saved.schemaVersion));
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
  const atLimit = new ItemLimitError(FREE_ITEM_LIMIT).message;
  check('the cap message names the way out', /subscribe/.test(atLimit), atLimit);
  check('and promises nothing is lost', /editable/.test(atLimit), atLimit);
  check('at the line it asks for one', /Remove one/.test(atLimit), atLimit);

  // Over the line — the lapsed subscriber — needs different arithmetic and a
  // different reassurance. "Remove one" there would be simply untrue.
  const over = new ItemLimitError(30).message;
  check('over the line it counts properly', /remove 16/.test(over), over);
  check('and leads with what was not taken', /Nothing has been removed/.test(over), over);

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

  /* ------------------------------------------- lapsing back to free */

  /*
    The case that will actually happen: someone subscribes, fills the app up,
    then stops paying. Nothing of theirs may be deleted, hidden or locked —
    they made those records. The only thing that stops is adding more.
  */
  {
    await db.settings.update('singleton', {
      entitlements: { proUnlock: true, reportUnlock: false },
    });
    const before = await activeItemCount(property.id);
    for (let i = 0; i < 20; i++) {
      await saveNewItem(form({ name: `Pro item ${i}` }), property.id);
    }
    const full = await activeItemCount(property.id);
    check('a subscriber can pass the cap', full === before + 20, `${full}`);

    // The subscription lapses.
    await db.settings.update('singleton', {
      entitlements: { proUnlock: false, reportUnlock: false },
    });
    const lapsed = (await db.settings.get('singleton'))!;

    check('adding is refused', !canAddItem(full, lapsed.entitlements));
    check(
      'but every item is still there',
      (await activeItemCount(property.id)) === full,
      `${await activeItemCount(property.id)}`,
    );

    // Still fully usable: readable, editable, and it comes out in a backup.
    const one = (await db.items.filter((i) => i.name === 'Pro item 7').toArray())[0]!;
    await saveEditedItem(one.id, formFromItem({ ...one, name: 'Renamed while free' }, 'USD'), property.id);
    check(
      'and editing one still works',
      (await db.items.get(one.id))!.name === 'Renamed while free',
    );

    let refused = '';
    try {
      await saveNewItem(form({ name: 'One too many' }), property.id);
    } catch (e) {
      refused = (e as Error).message;
    }
    check('the save path refuses too', refused.includes('free tier holds'), refused);
    // "Delete one" would be wrong here — they'd have to remove sixteen.
    check('and the message counts honestly', refused.includes(`remove ${full - FREE_ITEM_LIMIT + 1}`), refused);
    check('while promising nothing was taken', refused.includes('Nothing has been removed'), refused);

    // Clean up so the cap tests below start from a known place.
    for (const i of await db.items.filter((x) => x.name.startsWith('Pro item') || x.name === 'Renamed while free').toArray()) {
      await db.items.delete(i.id);
    }
    await db.settings.update('singleton', {
      entitlements: { proUnlock: true, reportUnlock: false },
    });
  }

  /* -------------------------------------------------------------- edit */

  const editId = await saveNewItem(
    form({
      name: 'Editable Kettle',
      price: '49.99',
      coverages: cover({ amount: '12' }),
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
  check('edit round-trips the term', edited.coverages?.[0]?.amount === 12);
  check('and its unit', edited.coverages?.[0]?.unit === 'months');

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
  cleared.coverages = cleared.coverages.map((c) => ({ ...c, amount: '' }));
  await saveEditedItem(editId, cleared, property.id);
  check(
    'clearing the term removes the cover',
    (await db.items.get(editId))!.coverages === undefined,
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

  /* ------------------------------------------------ when a card is finished */

  /*
    The rule behind auto-advance, after it got this wrong once.

    Each form card used to watch the field that mattered most, so answering
    that one scrolled the page away from the three beside it that hadn't been
    touched. "Answering the last question in a card takes you to the next one"
    only works if it means the LAST question — a card is not finished because
    its most important answer arrived.
  */
  check('every field filled is finished', cardFilled('Passport', 'Nuno'));
  check('one still empty is not', !cardFilled('Passport', ''));
  check('and neither is the last one', !cardFilled('Passport', 'Nuno', ''));

  // A space bar is not an answer.
  check('whitespace does not count', !cardFilled('Passport', '   '));

  // Booleans for the controls that aren't text — a room chosen, a toggle set.
  check('a chosen control counts', cardFilled('Passport', true));
  check('an unchosen one does not', !cardFilled('Passport', false));
  check('and undefined is empty, not absent', !cardFilled(undefined));

  /*
    Vacuously true, and deliberately so: a section with nothing to fill in is
    a section you are finished with. Worth pinning because `[].every()` is the
    kind of thing that surprises people reading the call site.
  */
  check('a card with no fields is complete', cardFilled());

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
