/**
 * The Add form's logic, kept out of the component so it can be tested in Node.
 *
 * Everything that decides what gets written to the database lives here; the
 * screen only collects strings.
 */

import { activeItemCount, canAddItem, createItem, updateItem } from '@/db/repo';
import { db } from '@/db/db';
import { FREE_ITEM_LIMIT, type Item, type ItemCategory, type Warranty } from '@/db/types';

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
  category: ItemCategory | '';
  roomId: string;
  purchaseDate: string;
  price: string;
  currency: string;
  warrantyMonths: string;
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
    category: '',
    roomId: '',
    purchaseDate: '',
    price: '',
    currency,
    warrantyMonths: '',
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
    category: item.category ?? '',
    roomId: item.roomId ?? '',
    purchaseDate: item.purchaseDate ?? '',
    price: item.purchasePriceCents == null ? '' : (item.purchasePriceCents / 100).toFixed(2),
    currency: item.currency ?? fallbackCurrency,
    warrantyMonths: item.warranty?.months ? String(item.warranty.months) : '',
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

export const WARRANTY_PRESETS: { months: number; label: string }[] = [
  { months: 12, label: '1 year' },
  { months: 24, label: '2 years' },
  { months: 36, label: '3 years' },
  { months: 60, label: '5 years' },
];

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

  const months = Number(form.warrantyMonths);
  let warranty: Warranty | undefined;
  if (form.warrantyMonths.trim() && Number.isFinite(months) && months > 0) {
    warranty = {
      months: Math.round(months),
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
    category: form.category || undefined,
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
 * Editing never touches the cap — the item already exists, and blocking edits
 * on a full free tier would be punishing people for data they already have.
 *
 * `thumbBlobId` is only overwritten when a new photo came in, so saving an edit
 * without touching the photo keeps it.
 */
export async function saveEditedItem(
  id: string,
  form: AddItemForm,
  propertyId: string,
  photo?: PhotoRefs,
): Promise<string> {
  const draft = draftFromForm(form, propertyId, photo);
  const patch: Partial<Item> = { ...draft };
  if (!photo) delete patch.thumbBlobId;
  await updateItem(id, patch);
  return id;
}
