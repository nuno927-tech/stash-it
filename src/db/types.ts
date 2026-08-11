/**
 * Stash It — entity types. Mirrors stash-it-data-model.md (schema v1).
 *
 * Rules encoded here:
 *  - IDs are uuidv7 strings, never auto-increment.
 *  - Dates are ISO strings. Calendar dates are YYYY-MM-DD; timestamps are UTC.
 *  - Money is integer minor units. Never floats.
 *  - Derived values (warranty expiry) are NOT stored.
 */

export const SCHEMA_VERSION = 1;

export type ItemCategory =
  | 'appliance'
  | 'electronics'
  | 'tools'
  | 'furniture'
  | 'hvac'
  | 'outdoor'
  | 'vehicle'
  | 'other';

export const ITEM_CATEGORIES: ItemCategory[] = [
  'appliance', 'electronics', 'tools', 'furniture',
  'hvac', 'outdoor', 'vehicle', 'other',
];

export interface Warranty {
  months: number;
  /** Defaults to Item.purchaseDate when absent. */
  startsOn?: string;
  provider?: string;
  policyNumber?: string;
  phone?: string;
  url?: string;
}

export interface Item {
  id: string;
  schemaVersion: number;

  name: string;
  /** Kept separate from name: these are the inputs to manual re-lookup. */
  brand?: string;
  model?: string;
  serial?: string;
  category?: ItemCategory;
  propertyId: string;
  roomId?: string;

  purchaseDate?: string;
  purchasePriceCents?: number;
  /** Written at save time from the device default, then editable per item. */
  currency?: string;
  retailer?: string;

  warranty?: Warranty;
  extendedWarranty?: Warranty;

  notes?: string;
  thumbBlobId?: string;

  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
}

export type DocKind = 'receipt' | 'manual' | 'warranty' | 'photo' | 'other';
export type StorageMode = 'linked' | 'local';
export type LinkStatus = 'ok' | 'broken' | 'unchecked';

export interface Doc {
  id: string;
  schemaVersion: number;
  itemId: string;
  kind: DocKind;
  title?: string;

  storageMode: StorageMode;
  url?: string;
  blobId?: string;

  lastCheckedAt?: string;
  linkStatus?: LinkStatus;

  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
}

export interface BlobRecord {
  id: string;
  data: Blob;
  mime: string;
  bytes: number;
  sha256?: string;
  createdAt: string;
}

export interface Property {
  id: string;
  name: string;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
}

export interface Room {
  id: string;
  propertyId: string;
  name: string;
  sortOrder: number;
  /** True until the user edits this row; lets future versions adjust untouched seeds. */
  isSeed: boolean;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
}

export type MaintenanceKind = 'service' | 'repair' | 'part' | 'note';

export interface MaintenanceEntry {
  id: string;
  schemaVersion: number;
  itemId: string;
  date: string;
  kind: MaintenanceKind;
  summary: string;
  costCents?: number;
  provider?: string;
  docIds?: string[];
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
}

/** Flags, never SKU checks — this is what makes the upgrade path possible. */
export interface Entitlements {
  reportUnlock: boolean;
  proUnlock: boolean;
  source?: 'appstore' | 'playstore' | 'web';
  verifiedAt?: string;
}

export interface Settings {
  id: 'singleton';
  schemaVersion: number;
  reminderOffsetsDays: number[];
  currency: string;
  lastBackupAt?: string;
  backupReminderDays: number;
  entitlements: Entitlements;
  devModeEnabled: boolean;
}

export const SEED_ROOMS = [
  'Kitchen', 'Living Room', 'Dining Room', 'Primary Bedroom', 'Bedroom',
  'Bathroom', 'Laundry', 'Garage', 'Basement', 'Attic', 'Office',
  'Workshop', 'Outdoor', 'Storage',
];

export const FREE_ITEM_LIMIT = 15;
