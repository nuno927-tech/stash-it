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
export const SCHEMA_VERSION = 4;

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

/**
 * One policy on one item.
 *
 * A product rarely has "a warranty". A couch has a lifetime frame, ten years
 * on the cushions, five on the springs and one on the fabric; a heat gun has
 * three years limited, a year of free service and ninety days to change your
 * mind. Two fixed slots — `warranty` and `extendedWarranty` — could hold two
 * of those and quietly lost the rest.
 *
 * `label` is what the policy is for, in the user's words: "Fabric", "Frame",
 * "Money back". `covers` is what it actually pays for, which is the part
 * nobody remembers three years later and the part a claim turns on.
 */
export interface Coverage {
  id: string;

  /** What it's for. Falls back to "Warranty" when the user leaves it blank. */
  label: string;

  /**
   * What it actually covers, in the user's own words — "parts and labour, not
   * accidental damage". Free text on purpose: every manufacturer words this
   * differently and a fixed list would force a wrong answer.
   */
  covers?: string;

  /**
   * `lifetime` never expires and never counts down. Stored as a unit rather
   * than as a 99-year term so nothing has to pretend to know an end date.
   */
  unit: CoverageUnit;
  /** Ignored when the unit is `lifetime`. */
  amount: number;

  /** Defaults to Item.purchaseDate when absent. */
  startsOn?: string;
  provider?: string;
  policyNumber?: string;
  phone?: string;
  url?: string;
}

export type CoverageUnit = WarrantyUnit | 'lifetime';

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

  /**
   * Every policy on this item, in the order the user entered them. Read it
   * through `coveragesOf()` in src/lib/warranty.ts, which folds in the two
   * legacy fields below for records written before this existed.
   */
  coverages?: Coverage[];

  /**
   * Superseded by `coverages`. Still written on save — as the first and second
   * entries of the list — so that a backup taken here restores into an older
   * build with its main warranty intact rather than with nothing at all.
   */
  warranty?: Warranty;
  extendedWarranty?: Warranty;

  notes?: string;
  /** Small, for lists. */
  thumbBlobId?: string;
  /**
   * Full size, for the viewer. `storePhoto` has always written this blob —
   * it just had nowhere to be recorded, so every photo ever taken left an
   * unreferenced copy of itself in the database. Optional because records
   * written before this field exist and only have the thumbnail.
   */
  photoBlobId?: string;

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

export type Cadence = 'weekly' | 'monthly' | 'quarterly' | 'yearly';

/**
 * A recurring charge — Netflix, Spotify, the gym.
 *
 * Its own table rather than a flag on Item, because it shares almost nothing
 * with one. An item has a room, a photo, coverage policies and documents; a
 * subscription has none of those and has a cadence, which no item has. Folded
 * into `items` it would mean every query, the search index, the gap-finder and
 * the warranty ring all learning to skip a kind of row they can't render.
 *
 * WHEN IT RENEWS is a cadence plus an anchor — one real renewal date — rather
 * than a day of the month. See lib/subscriptions.ts for why.
 *
 * WHAT IT COSTS is integer minor units, like an item's price. Never a float.
 */
export interface Subscription {
  id: string;
  schemaVersion: number;
  propertyId: string;
  /** What it's called. Taken from the catalogue, or typed. */
  name: string;
  /** Catalogue key when it's one of the known services — see lib/services.ts. */
  serviceId?: string;
  /** A logo fetched at entry for a service not in the catalogue. */
  logoBlobId?: string;

  cadence: Cadence;
  /** One real renewal date, ISO yyyy-mm-dd. Every other date derives from it. */
  anchorDate: string;
  amountCents: number;
  currency: string;

  /** Optional: when the user first subscribed. Never used for arithmetic. */
  startedDate?: string;

  /** 0, 1, 3 or 7. Zero means no reminder, and is the default. */
  remindDays?: number;

  /**
   * Split with somebody else.
   *
   * `amountCents` stays what *you* pay either way — every total in the app is
   * built from it, and a figure that sometimes means the whole bill and
   * sometimes your half would make the monthly total meaningless. These two
   * fields only record the arrangement: who the money goes to, and how it
   * gets there. Both free text, because "my sister", "the group account" and
   * "Dave, first of the month" are all real answers.
   */
  shared?: boolean;
  payTo?: string;
  payHow?: string;

  notes?: string;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
}

export const PAPER_KINDS = [
  'passport',
  'id',
  'licence',
  'visa',
  'vehicle',
  'insurance',
  'certification',
  'membership',
  'other',
] as const;

export type PaperKind = (typeof PAPER_KINDS)[number];

/**
 * A document that expires — a passport, a licence, a residence permit.
 *
 * ── Why this is a table and not an Item ───────────────────────────────────
 * The same reasoning as Subscription. A passport has no room, no photo, no
 * brand, no purchase price and no warranty; an item has no issuing authority
 * and never needs renewing eight months before it stops working. Folded into
 * `items` it would count against the free cap, appear under "what's in the
 * garage", and pollute every dashboard figure that means "things you own".
 *
 * ── What is deliberately NOT here ─────────────────────────────────────────
 * No scan, and no document number.
 *
 * The database is unencrypted by design and says so (see lib/lock.ts), and
 * backups are plaintext zips that drive.ts will put in the user's Drive on a
 * schedule. A receipt for a kettle in that file is fine. A passport scan is
 * not, and a passport number sitting next to a name is a better identity-theft
 * package than the scan would be. Storing a partial number behind a warning
 * would be a half-measure, and half-measures with warnings attached are how
 * people leak things.
 *
 * Both wait for real at-rest encryption — the PRF extension can derive a key
 * from the passkey the lock already creates — which needs a passcode fallback
 * and a backup format change. Until then this app promises "nothing to leak"
 * and keeps the promise.
 *
 * What's left is the useful part anyway. Nobody needs a passport scan in an
 * app; they need to know it expires in March and renewals take two months.
 */
export interface Paper {
  id: string;
  schemaVersion: number;
  propertyId: string;

  kind: PaperKind;
  /** What the user calls it: "Nuno's passport", "Van MOT". */
  label: string;
  /**
   * Whose it is. A household has four passports and they do not expire
   * together, so the list is unreadable without this.
   */
  holder?: string;

  /** ISO yyyy-mm-dd. The only required date, and the one printed on it. */
  expiresOn: string;
  issuedOn?: string;

  /**
   * How long before expiry this actually needs dealing with, in days.
   *
   * THE REASON THIS FEATURE IS WORTH BUILDING. A warranty's useful date is its
   * expiry. A passport's is not: renewals routinely take weeks, and many
   * countries refuse entry without three to six months left on it. A passport
   * "valid until March" stops being usable for travel around the previous
   * summer, and an app that counts down to March is telling you something
   * true and useless.
   *
   * A field rather than a rule, because the right answer depends on the
   * document, the country and where you're going — and an app that states a
   * confident wrong lead time is worse than one that asks. Defaults per kind
   * live in lib/papers.ts.
   */
  leadDays?: number;

  /** Who issues it, for the renewal: "HM Passport Office", "DVLA". */
  authority?: string;
  /** Where the physical one is. "Fireproof box", "Mum's house". */
  storedAt?: string;

  /*
    NO `remindDays`, unlike Subscription, and the difference is the point.

    There was one, copied across, and it was the same control twice: the lead
    time already decides the day this document starts asking, so a reminder
    some days before that day is a slightly longer lead time wearing a second
    switch. A subscription earns its reminder because a charge lands on one
    day with nothing else warning you; here the lead time IS the warning, it
    never turns itself off, and it drives the sorting and the colour too.
  */

  notes?: string;
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

  /*
    Reminders that arrive while the app is closed.

    Device state, like the biometric lock: an endpoint belongs to one browser
    on one phone and means nothing anywhere else, so both are stripped from a
    backup. Restoring onto a new handset must not leave it believing it is
    subscribed to a push channel that was never registered for it.
  */
  pushEnabled?: boolean;
  pushEndpoint?: string;
  /** When the sender was last told, and what it was told. Both device state. */
  pushSyncedAt?: string;
  pushWakes?: number[];
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
  /** Set when the tour was finished or skipped; stops it being offered. */
  tourDoneAt?: string;
  /** When "remind me later" comes due. Absent means no reminder pending. */
  tourRemindAt?: string;

  /**
   * Tipping. `donateMonthly` is a reminder, not a subscription — Venmo has no
   * way to schedule a payment from a link, so the app can only ask again.
   */
  donateMonthly?: boolean;
  donateLastAt?: string;
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

/**
 * How many records the free tier holds, counting everything.
 *
 * ── It counts all three kinds now, and that is a reversal ─────────────────
 * Subscriptions and documents were both deliberately exempt, on the argument
 * that the cap prices storage and neither one holds an attachment. That
 * argument is sound and it made the cap incoherent in practice: a collection
 * of 15 items, 40 subscriptions and 30 documents sat inside the free tier
 * while a 16th kettle did not, so the limit stopped meaning "how much of this
 * app you are using" and started meaning "how many kettles".
 *
 * One number over everything is a rule people can hold in their heads. 25
 * rather than 15 because it now has three kinds to cover — the point is to
 * mark where a free tier ends, not to make an ordinary household hit it in a
 * week.
 *
 * The cap has only ever blocked NEW records. Nothing above it is hidden,
 * locked or degraded; everything already saved stays editable and exportable.
 */
export const FREE_ITEM_LIMIT = 25;
