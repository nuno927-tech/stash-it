/**
 * Stash It — entity types. Mirrors stash-it-data-model.md (schema v1).
 *
 * Rules encoded here:
 *  - IDs are uuidv7 strings, never auto-increment.
 *  - Dates are ISO strings. Calendar dates are YYYY-MM-DD; timestamps are UTC.
 *  - Money is integer minor units. Never floats.
 *  - Derived values (warranty expiry) are NOT stored.
 */

/**
 * v2 dropped `Item.category`. Room answers "where is it" and the icon comes
 * from the item's own words, which left category with no job worth a decision
 * during add. See db.ts for the migration.
 */
export const SCHEMA_VERSION = 2;

export type WarrantyUnit = 'days' | 'months' | 'years';

export interface Warranty {
  /**
   * Kept for records written before units existed, and as a rough equivalent
   * for anything reading this file without understanding `unit`. When `unit`
   * and `amount` are present they are the source of truth — read the term
   * through `termOf()` in src/lib/warranty.ts rather than touching either.
   */
  months: number;

  /** How the user expressed the term. A 90-day warranty counts down in days. */
  unit?: WarrantyUnit;
  /** The number the user typed, in `unit`. */
  amount?: number;

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

  /**
   * Preferences. Optional because records written before they existed are
   * still valid — read them through `prefsFrom` in src/lib/prefs.ts, which
   * supplies the defaults, rather than touching them directly.
   */
  theme?: 'system' | 'light' | 'dark';
  sounds?: boolean;
  haptics?: boolean;
  roomsView?: 'collapsed' | 'expanded';

  /**
   * Biometric lock. `lockCredentialId` is the WebAuthn credential this device
   * enrolled — meaningless anywhere else, which is why both are stripped from
   * a backup rather than travelling with it.
   */
  biometricLock?: boolean;
  lockCredentialId?: string;

  /**
   * Google Drive backup. The client ID is public by design — it's locked to
   * an origin, not a secret — so unlike the lock credential it travels in a
   * backup, which is what makes a restore onto a new phone still know where
   * its backups live.
   */
  driveClientId?: string;
  lastDriveBackupAt?: string;

  /** What the greeting calls you. Empty means asked and declined. */
  displayName?: string;
  /** Set once the welcome has been answered, either way. */
  onboardedAt?: string;
}

export const SEED_ROOMS = [
  'Kitchen', 'Living Room', 'Family Room', 'Dining Room', 'Primary Bedroom',
  'Bedroom', 'Bathroom', 'Laundry', 'Garage', 'Basement', 'Attic', 'Office',
  'Workshop', 'Outdoor', 'Storage',
];

/**
 * Seeds added after the first release, with the room they should follow.
 * Applied to existing properties by the Dexie v3 upgrade, and skipped when the
 * user already has a room by that name.
 */
export const LATER_SEED_ROOMS: { name: string; after: string }[] = [
  { name: 'Family Room', after: 'Living Room' },
];

export const FREE_ITEM_LIMIT = 15;
