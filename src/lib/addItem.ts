/**
 * The Add form's logic, kept out of the component so it can be tested in Node.
 *
 * Everything that decides what gets written to the database lives here; the
 * screen only collects strings.
 */

import { activeItemCount, canAddItem, createItem, updateItem } from '@/db/repo';
import { db } from '@/db/db';
import { FREE_ITEM_LIMIT, type Item, type Warranty, type WarrantyUnit } from '@/db/types';
import { termOf, termToMonths } from './warranty';

export class ValidationError extends Error {}
export class ItemLimitError extends Error {
  constructor() {
    super(
      `Free tier holds ${FREE_ITEM_LIMIT} items. Delete one, or unlock Pro — everything you've already saved stays editable and exportable either way.`,
    );
  }
}

export interface AddItemForm {
  name: string;
  roomId: string;
  purchaseDate: string;
  price: string;
  currency: string;
  warrantyUnit: WarrantyUnit;
  warrantyAmount: string;
  /** Behind "More details". */
  brand: string;
  model: string;
  serial: string;
  retailer: string;
  warrantyProvider: string;
  policyNumber: string;
  warrantyPhone: string;
  warrantyUrl: string;
  notes: string;
}

export function emptyForm(currency: string): AddItemForm {
  return {
    name: '',
    roomId: '',
    purchaseDate: '',
    price: '',
    currency,
    warrantyUnit: 'months',
    warrantyAmount: '',
    brand: '',
    model: '',
    serial: '',
    retailer: '',
    warrantyProvider: '',
    policyNumber: '',
    warrantyPhone: '',
    warrantyUrl: '',
    notes: '',
  };
}

/** Fills the form from an existing item, for the edit path. */
export function formFromItem(item: Item, fallbackCurrency: string): AddItemForm {
  return {
    name: item.name,
    roomId: item.roomId ?? '',
    purchaseDate: item.purchaseDate ?? '',
    price: item.purchasePriceCents == null ? '' : (item.purchasePriceCents / 100).toFixed(2),
    currency: item.currency ?? fallbackCurrency,
    warrantyUnit: termOf(item.warranty)?.unit ?? 'months',
    warrantyAmount: termOf(item.warranty) ? String(termOf(item.warranty)!.amount) : '',
    brand: item.brand ?? '',
    model: item.model ?? '',
    serial: item.serial ?? '',
    retailer: item.retailer ?? '',
    warrantyProvider: item.warranty?.provider ?? '',
    policyNumber: item.warranty?.policyNumber ?? '',
    warrantyPhone: item.warranty?.phone ?? '',
    warrantyUrl: item.warranty?.url ?? '',
    notes: item.notes ?? '',
  };
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

export const UNIT_LABEL: Record<WarrantyUnit, string> = {
  days: 'Days',
  months: 'Months',
  years: 'Years',
};

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
): Omit<Item, 'id' | 'schemaVersion' | 'createdAt' | 'updatedAt'> {
  const name = form.name.trim();
  if (!name) throw new ValidationError('Give the item a name.');

  const amount = Number(form.warrantyAmount);
  let warranty: Warranty | undefined;
  if (form.warrantyAmount.trim() && Number.isFinite(amount) && amount > 0) {
    const term = { unit: form.warrantyUnit, amount: Math.round(amount) };
    warranty = {
      // `months` stays populated as the rough equivalent, so a backup restored
      // into an older build still shows something sensible.
      months: termToMonths(term),
      unit: term.unit,
      amount: term.amount,
      provider: clean(form.warrantyProvider),
      policyNumber: clean(form.policyNumber),
      phone: clean(form.warrantyPhone),
      url: clean(form.warrantyUrl),
    };
  }

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
    warranty,
    notes: clean(form.notes),
    thumbBlobId: photo?.thumbBlobId,
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
  if (settings && !canAddItem(count, settings.entitlements)) throw new ItemLimitError();

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
  const draft = draftFromForm(form, propertyId, photo ?? undefined);
  const patch: Partial<Item> = { ...draft };

  if (photo === undefined) delete patch.thumbBlobId;
  else if (photo === null) patch.thumbBlobId = undefined;

  await updateItem(id, patch);

  // Clean up the file we just stopped pointing at, unless something else
  // still references it — blobs dedupe by hash, so they can be shared.
  const orphan = previous?.thumbBlobId;
  if (orphan && photo !== undefined && orphan !== patch.thumbBlobId) {
    const { isBlobReferenced } = await import('./docs');
    if (!(await isBlobReferenced(orphan))) await db.blobs.delete(orphan);
  }

  return id;
}
