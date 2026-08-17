/**
 * The Add form's logic, kept out of the component so it can be tested in Node.
 *
 * Everything that decides what gets written to the database lives here; the
 * screen only collects strings.
 */

import { activeItemCount, canAddItem, createItem, updateItem } from '@/db/repo';
import { db, newId } from '@/db/db';
import {
  FREE_ITEM_LIMIT,
  type Coverage,
  type CoverageUnit,
  type Item,
  type Warranty,
  type WarrantyUnit,
} from '@/db/types';
import { formatMoneyInput } from './format';
import { coveragesOf, DEFAULT_COVERAGE_LABEL, termToMonths } from './warranty';

export class ValidationError extends Error {}
/**
 * The cap, refused politely.
 *
 * Takes the count because "delete one" is wrong for the case that actually
 * matters: someone who subscribed, added thirty items, and then let the
 * subscription lapse. Nothing of theirs is removed or hidden — every item
 * stays readable, editable and exportable — but they'd have to remove sixteen
 * to get under the line, and being told to "delete one" reads as a bug on top
 * of a disappointment.
 */
export class ItemLimitError extends Error {
  constructor(count = FREE_ITEM_LIMIT) {
    const over = count - FREE_ITEM_LIMIT + 1;
    super(
      count > FREE_ITEM_LIMIT
        ? `You have ${count} items and the free tier holds ${FREE_ITEM_LIMIT}. Nothing has been removed — everything you've saved stays editable and exportable. To add more, subscribe again or remove ${over}.`
        : `Free tier holds ${FREE_ITEM_LIMIT} items. Remove one, or subscribe — everything you've already saved stays editable and exportable either way.`,
    );
  }
}

/**
 * One policy as the form holds it: strings, because that's what an input
 * gives you, and a `key` that never reaches the database so React can tell
 * two blank rows apart.
 */
export interface CoverageDraft {
  key: string;
  label: string;
  covers: string;
  unit: CoverageUnit;
  amount: string;
  provider: string;
  policyNumber: string;
  phone: string;
  url: string;
}

export function blankCoverage(overrides: Partial<CoverageDraft> = {}): CoverageDraft {
  return {
    key: newId(),
    /*
      Pre-selected rather than blank. Almost every policy anyone records is
      just "the warranty", and `toCoverage` already falls back to this name
      when the field is left empty — so the blank row was asking a question it
      was going to answer the same way regardless, and showing "What is this
      one for?" over a row of unpicked buttons made it look required.
    */
    label: DEFAULT_COVERAGE_LABEL,
    covers: '',
    unit: 'months',
    amount: '',
    provider: '',
    policyNumber: '',
    phone: '',
    url: '',
    ...overrides,
  };
}

export interface AddItemForm {
  name: string;
  roomId: string;
  purchaseDate: string;
  price: string;
  currency: string;
  /**
   * Every policy on the item. Starts as one blank row, so the common case —
   * a single warranty — looks exactly like the single field it replaced.
   */
  coverages: CoverageDraft[];
  /** All optional, and each says so in its own placeholder. */
  brand: string;
  model: string;
  serial: string;
  retailer: string;
  notes: string;
}

export function emptyForm(currency: string): AddItemForm {
  return {
    name: '',
    roomId: '',
    purchaseDate: '',
    price: '',
    currency,
    coverages: [blankCoverage()],
    brand: '',
    model: '',
    serial: '',
    retailer: '',
    notes: '',
  };
}

/** Fills the form from an existing item, for the edit path. */
export function formFromItem(item: Item, fallbackCurrency: string): AddItemForm {
  return {
    name: item.name,
    roomId: item.roomId ?? '',
    purchaseDate: item.purchaseDate ?? '',
    // Grouped on the way in as well as while typing, so an edit doesn't show
    // a differently formatted number than the one just entered.
    price:
      item.purchasePriceCents == null
        ? ''
        : formatMoneyInput(
            (item.purchasePriceCents / 100).toFixed(2),
            item.currency ?? fallbackCurrency,
          ),
    currency: item.currency ?? fallbackCurrency,
    // Reads through coveragesOf, so an item saved before this existed edits as
    // the one or two policies it always had rather than as an empty list.
    coverages: coveragesFor(item),
    brand: item.brand ?? '',
    model: item.model ?? '',
    serial: item.serial ?? '',
    retailer: item.retailer ?? '',
    notes: item.notes ?? '',
  };
}

function coveragesFor(item: Item): CoverageDraft[] {
  const existing = coveragesOf(item).map((c) =>
    blankCoverage({
      label: c.label,
      covers: c.covers ?? '',
      unit: c.unit,
      amount: c.unit === 'lifetime' ? '' : String(c.amount),
      provider: c.provider ?? '',
      policyNumber: c.policyNumber ?? '',
      phone: c.phone ?? '',
      url: c.url ?? '',
    }),
  );
  return existing.length ? existing : [blankCoverage()];
}

/**
 * Presets per unit. Days lead with 30/60/90 because those are the numbers
 * retailers actually print on returns and short cover.
 */
export const WARRANTY_PRESETS: Record<WarrantyUnit, number[]> = {
  days: [14, 30, 60, 90, 180],
  months: [3, 6, 12, 18, 24],
  years: [1, 2, 3, 5, 10],
};

export const UNIT_LABEL: Record<CoverageUnit, string> = {
  days: 'Days',
  months: 'Months',
  years: 'Years',
  lifetime: 'Lifetime',
};

/**
 * Names people actually find on paperwork, offered as one tap each.
 *
 * Not a fixed list — the field stays free text, because the couch that says
 * "sinuous spring system" is not going to be talked out of it. These are the
 * ones common enough to be worth saving the typing.
 */
export const COVERAGE_LABELS = [
  'Warranty',
  'Limited warranty',
  'Extended warranty',
  'Parts and labour',
  'Money back',
  'Free service',
];

/** Examples of what a policy covers, shown as the field's placeholder. */
export const COVERS_PLACEHOLDER = 'Parts and labour, not accidental damage';

/**
 * Money is stored as integer minor units, never a float. Accepts what people
 * actually type: currency symbols, thousands separators, a stray space.
 *
 * Both separators are ambiguous across locales — "1.299" is one thousand two
 * hundred and ninety-nine euros in Germany and one pound thirty in the UK. The
 * rule here: the last separator followed by exactly two digits is the decimal
 * point. Anything else is a thousands separator.
 */
export function parseMoneyToCents(input: string): number | undefined {
  const cleaned = input.replace(/[^\d.,-]/g, '').trim();
  if (!cleaned) return undefined;

  const lastDot = cleaned.lastIndexOf('.');
  const lastComma = cleaned.lastIndexOf(',');
  const lastSep = Math.max(lastDot, lastComma);

  let whole = cleaned;
  let frac = '';
  if (lastSep !== -1 && cleaned.length - lastSep - 1 === 2) {
    whole = cleaned.slice(0, lastSep);
    frac = cleaned.slice(lastSep + 1);
  }

  const digits = whole.replace(/[^\d-]/g, '');
  if (!digits || digits === '-') return undefined;

  const value = Number(`${digits}.${frac || '0'}`);
  if (!Number.isFinite(value)) return undefined;
  return Math.round(value * 100);
}

function clean(s: string): string | undefined {
  const t = s.trim();
  return t ? t : undefined;
}

export interface PhotoRefs {
  blobId: string;
  thumbBlobId: string;
}

/** Shapes the form into an Item. Exported so tests can assert on it directly. */
export function draftFromForm(
  form: AddItemForm,
  propertyId: string,
  photo?: PhotoRefs,
  /**
   * Whether a purchase date must be present. True when creating; on an edit,
   * true only if the record already had one — see the note below.
   */
  needDate = true,
): Omit<Item, 'id' | 'schemaVersion' | 'createdAt' | 'updatedAt'> {
  const name = form.name.trim();
  if (!name) throw new ValidationError('Give the item a name.');

  /*
    A new item needs a purchase date. Every countdown in the app is arithmetic
    on it — a warranty length with no start is a number with nothing to
    subtract from, and the item lands in the collection permanently reading
    "no warranty recorded" no matter how much cover was typed in.

    Edits are not held to it. Records saved before this rule exist, and so do
    items whose date is honestly unknown; blocking those would either strand
    them or push someone into inventing a date, and an invented date is worse
    than an absent one. It counts down to a day that means nothing, silently.
  */
  if (needDate && !form.purchaseDate.trim()) {
    throw new ValidationError('Add the purchase date — the warranty countdown is measured from it.');
  }

  const coverages = form.coverages.map(toCoverage).filter((c): c is Coverage => c !== null);

  return {
    name,
    brand: clean(form.brand),
    model: clean(form.model),
    serial: clean(form.serial),
    propertyId,
    roomId: clean(form.roomId),
    purchaseDate: clean(form.purchaseDate),
    purchasePriceCents: parseMoneyToCents(form.price),
    currency: form.currency,
    retailer: clean(form.retailer),
    coverages: coverages.length ? coverages : undefined,
    // The two old fields are still written from the first two dated policies.
    // They're what an older build — or a backup opened on a phone that hasn't
    // updated — knows how to read, and one warranty is a much better failure
    // than none. Nothing in this build reads them when `coverages` is present.
    ...legacyPair(coverages),
    notes: clean(form.notes),
    thumbBlobId: photo?.thumbBlobId,
    photoBlobId: photo?.blobId,
  };
}

/** A form row becomes a policy, or nothing at all when it's still blank. */
function toCoverage(draft: CoverageDraft): Coverage | null {
  const label = draft.label.trim();

  if (draft.unit === 'lifetime') {
    return {
      id: draft.key,
      label: label || DEFAULT_COVERAGE_LABEL,
      covers: clean(draft.covers),
      unit: 'lifetime',
      amount: 0,
      provider: clean(draft.provider),
      policyNumber: clean(draft.policyNumber),
      phone: clean(draft.phone),
      url: clean(draft.url),
    };
  }

  const amount = Number(draft.amount);
  // A row with a name but no term is someone who started typing and stopped;
  // saving it would put a policy on the item that can never count down.
  if (!draft.amount.trim() || !Number.isFinite(amount) || amount <= 0) return null;

  return {
    id: draft.key,
    label: label || DEFAULT_COVERAGE_LABEL,
    covers: clean(draft.covers),
    unit: draft.unit,
    amount: Math.round(amount),
    provider: clean(draft.provider),
    policyNumber: clean(draft.policyNumber),
    phone: clean(draft.phone),
    url: clean(draft.url),
  };
}

function legacyPair(coverages: Coverage[]): Pick<Item, 'warranty' | 'extendedWarranty'> {
  const dated = coverages.filter((c) => c.unit !== 'lifetime');
  return {
    warranty: asWarranty(dated[0]),
    extendedWarranty: asWarranty(dated[1]),
  };
}

function asWarranty(c: Coverage | undefined): Warranty | undefined {
  if (!c) return undefined;
  const unit = c.unit as WarrantyUnit;
  return {
    months: termToMonths({ unit, amount: c.amount }),
    unit,
    amount: c.amount,
    startsOn: c.startsOn,
    provider: c.provider,
    policyNumber: c.policyNumber,
    phone: c.phone,
    url: c.url,
  };
}

/**
 * Re-checks the cap at save time rather than trusting whatever the FAB thought
 * when the screen opened — a delete or a restore may have happened since.
 */
export async function saveNewItem(
  form: AddItemForm,
  propertyId: string,
  photo?: PhotoRefs,
): Promise<string> {
  const draft = draftFromForm(form, propertyId, photo);

  const settings = await db.settings.get('singleton');
  const count = await activeItemCount(propertyId);
  if (settings && !canAddItem(count, settings.entitlements)) throw new ItemLimitError(count);

  return createItem(draft);
}

/**
 * Three photo outcomes, and they must stay distinguishable:
 *
 *   undefined  the user didn't touch the photo — keep whatever is there
 *   PhotoRefs  a new photo — replace
 *   null       the user removed it — clear the reference and bin the file
 *
 * Collapsing "removed" into "untouched" was a real bug: Remove looked like it
 * worked, then the photo came back on the next render.
 */
export type PhotoEdit = PhotoRefs | null | undefined;

/**
 * Editing never touches the cap — the item already exists, and blocking edits
 * on a full free tier would be punishing people for data they already have.
 */
export async function saveEditedItem(
  id: string,
  form: AddItemForm,
  propertyId: string,
  photo?: PhotoEdit,
): Promise<string> {
  const previous = await db.items.get(id);
  // Can't clear a date that was there; not made to invent one that never was.
  const draft = draftFromForm(form, propertyId, photo ?? undefined, !!previous?.purchaseDate);
  const patch: Partial<Item> = { ...draft };

  if (photo === undefined) {
    delete patch.thumbBlobId;
    delete patch.photoBlobId;
  } else if (photo === null) {
    patch.thumbBlobId = undefined;
    patch.photoBlobId = undefined;
  }

  await updateItem(id, patch);

  // Clean up the files we just stopped pointing at, unless something else
  // still references them — blobs dedupe by hash, so they can be shared. Both
  // sizes, because a photo is two blobs and orphaning the larger one is how
  // storage grows without anything to show for it.
  if (photo !== undefined) {
    const dropped = [
      previous?.thumbBlobId !== patch.thumbBlobId ? previous?.thumbBlobId : undefined,
      previous?.photoBlobId !== patch.photoBlobId ? previous?.photoBlobId : undefined,
    ].filter(Boolean) as string[];

    if (dropped.length) {
      const { isBlobReferenced } = await import('./docs');
      for (const blobId of dropped) {
        if (!(await isBlobReferenced(blobId))) await db.blobs.delete(blobId);
      }
    }
  }

  return id;
}
