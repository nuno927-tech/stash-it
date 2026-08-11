# Stash It — Data Model Specification

Version 1 (schema v1). Local-first, IndexedDB via Dexie. Nothing in this document
requires a network connection.

---

## Design rules

These constrain every decision below. Breaking one of them later is expensive.

1. **The device is the source of truth.** No server ever holds item data. A backend,
   if it exists, holds account records and anonymous usage counters only.
2. **Every record carries its schema version.** Migrations run on open, forward-only.
3. **Nothing is ever hard-deleted immediately.** Soft-delete with `deletedAt`, purge
   after 30 days. Users delete the wrong item; restoring from backup to fix one
   mistake is a terrible experience.
4. **Derived values are computed, never stored.** Warranty expiry is a function of
   `purchaseDate` and `warrantyMonths`. Storing the computed date guarantees drift.
5. **IDs are UUIDv7.** Time-sortable, collision-free across devices, and safe if you
   ever add sync. Never use auto-increment integers — they break the moment two
   devices merge.
6. **Blobs live outside the record.** Documents reference a blob by id; the blob
   table holds the bytes. Keeps item queries fast and export chunking simple.

---

## Entities

### Item

The product. One per physical thing the user owns.

```ts
interface Item {
  id: string;                  // uuidv7
  schemaVersion: number;       // 1

  name: string;                // "Bosch Dishwasher"
  brand?: string;              // "Bosch"        — needed for manual re-lookup
  model?: string;              // "SHXM4AY55N"   — needed for manual re-lookup
  serial?: string;
  category?: ItemCategory;
  propertyId: string;          // FK -> Property. Always set; default property exists.
  roomId?: string;             // FK -> Room. Nullable: "not assigned yet" is valid.

  purchaseDate?: string;       // ISO date, no time. Local calendar date.
  purchasePriceCents?: number; // integer minor units
  currency?: string;           // ISO 4217. Written at save time from the device
                               // default, then editable per item. Never resolved
                               // lazily — a stored total must not change meaning
                               // when the device locale changes.
  retailer?: string;

  warranty?: Warranty;
  extendedWarranty?: Warranty; // separate policy, separate term, separate provider

  notes?: string;
  thumbBlobId?: string;        // FK -> Blob. Small, square, generated on add.

  createdAt: string;           // ISO datetime UTC
  updatedAt: string;
  deletedAt?: string;          // soft delete
}

type ItemCategory =
  | 'appliance' | 'electronics' | 'tools' | 'furniture'
  | 'hvac' | 'outdoor' | 'vehicle' | 'other';
```

**Why `brand` and `model` are separate fields and not just part of `name`:** they are
the inputs to manual re-lookup when a linked URL dies. Buried in a display string
they are useless.

### Warranty

Embedded in Item, not its own table. It has no independent life.

```ts
interface Warranty {
  months: number;              // term length
  startsOn?: string;           // ISO date. Defaults to Item.purchaseDate.
  provider?: string;           // "Bosch" or "SquareTrade"
  policyNumber?: string;
  phone?: string;
  url?: string;
}
```

**Expiry is computed, never stored:**

```ts
function expiresOn(w: Warranty, purchaseDate?: string): string | null {
  const start = w.startsOn ?? purchaseDate;
  if (!start || !w.months) return null;
  return addMonths(parseISODate(start), w.months);   // calendar months, not 30-day
}

type WarrantyState = 'covered' | 'ending-soon' | 'expired' | 'unknown';
// ending-soon = expiry within 30 days. Drives the ring colour and the chip.
```

Use calendar month arithmetic (`addMonths`), not day counts. A 24-month warranty
bought on 31 Jan ends 31 Jan, not 30 Jan.

### Document

A receipt, manual, warranty card, or photo attached to an Item.

```ts
interface Doc {
  id: string;
  schemaVersion: number;
  itemId: string;              // FK -> Item
  kind: DocKind;
  title?: string;              // "Purchase receipt"

  storageMode: 'linked' | 'local';
  url?: string;                // set when linked
  blobId?: string;             // set when local — FK -> Blob

  // link health, only meaningful when storageMode === 'linked'
  lastCheckedAt?: string;
  linkStatus?: 'ok' | 'broken' | 'unchecked';

  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
}

type DocKind = 'receipt' | 'manual' | 'warranty' | 'photo' | 'other';
```

**One type, two modes.** A manual that starts linked and is later downloaded stays
the same record — only `storageMode`, `url` and `blobId` change. The UI and the
export logic never fork.

**Invariant:** `storageMode === 'linked'` requires `url`; `'local'` requires `blobId`.
Enforce in a single `assertDocValid()` used by both the add and edit paths.

### Blob

Bytes, stored separately from metadata.

```ts
interface Blob {
  id: string;
  data: ArrayBuffer;           // Dexie stores Blob/ArrayBuffer natively
  mime: string;
  bytes: number;
  sha256?: string;             // dedupe: same receipt attached twice stores once
  createdAt: string;
}
```

Never query this table for anything but a single id. It is the largest table by
orders of magnitude and the reason item queries must not join it.

### Property

Multiple properties is a Pro feature, but the entity exists from v1 so you never
migrate items into a relationship that did not exist.

```ts
interface Property {
  id: string;
  name: string;                // "Home", "Lake house", "Mom's"
  isDefault: boolean;          // exactly one true
  createdAt: string;
  deletedAt?: string;
}
```

**Free tier:** one property, created on first launch, UI hidden entirely.
**Pro:** the property switcher appears. No data migration, just a revealed control.

### Room

A real entity, not a string. Seeded on first launch so the user always picks from a
list rather than inventing one, but fully editable.

```ts
interface Room {
  id: string;                  // uuidv7
  propertyId: string;          // rooms belong to a property, not to the install
  name: string;                // "Kitchen"
  icon?: string;               // optional glyph key for the picker
  sortOrder: number;           // user-arrangeable; seeds get 100, 200, 300...
  isSeed: boolean;             // true for the pre-populated set, until edited
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
}
```

**Seed list, created per property on first launch:**

```ts
const SEED_ROOMS = [
  'Kitchen', 'Living Room', 'Dining Room', 'Primary Bedroom', 'Bedroom',
  'Bathroom', 'Laundry', 'Garage', 'Basement', 'Attic', 'Office',
  'Workshop', 'Outdoor', 'Storage',
];
```

Seeds are ordinary rows — the user can rename, reorder, or delete any of them. The
`isSeed` flag exists for exactly one purpose: if a user has never touched the room
list and every room is still an untouched seed, a later app version may add or
adjust seeds. Once a row is edited, `isSeed` flips to false and the app never
modifies it again.

**Deleting a room with items in it.** Never cascade. Offer two choices:

- *Move items to another room* — pick a destination, reassign, then soft-delete.
- *Leave items unassigned* — set `roomId` to `undefined`, then soft-delete.

Silently orphaning items to a dangling `roomId` is the bug that breaks the inventory
report months later.

**Rooms belong to a property, not the install.** A lake house has different rooms
than a home. Creating a property seeds it with its own copy of the list. This is why
`propertyId` sits on Room, and why the seeding runs on property creation rather than
on first launch of the app.

**Renaming is free.** One row changes; every item follows. That is the whole reason
for choosing an entity over a string.

**Uniqueness:** case-insensitive unique on `(propertyId, name)` among non-deleted
rows. Enforce in application code — IndexedDB cannot express a partial unique index.
Trim and collapse whitespace before comparing.

### MaintenanceEntry

Pro feature. Same reasoning — the table ships in v1 even if the UI does not.

```ts
interface MaintenanceEntry {
  id: string;
  itemId: string;
  date: string;                // ISO date
  kind: 'service' | 'repair' | 'part' | 'note';
  summary: string;
  costCents?: number;
  provider?: string;
  docIds?: string[];           // invoices attached as Docs
  createdAt: string;
  deletedAt?: string;
}
```

### Settings

Single-row table. Not localStorage — it needs to be in the export.

```ts
interface Settings {
  id: 'singleton';
  schemaVersion: number;
  reminderOffsetsDays: number[];   // free: [30]. Pro: user-defined, e.g. [90,30,7]
  currency: string;
  lastBackupAt?: string;
  backupReminderDays: number;      // default 30
  entitlements: Entitlements;
  devModeEnabled: boolean;
}

interface Entitlements {
  reportUnlock: boolean;
  proUnlock: boolean;
  source?: 'appstore' | 'playstore' | 'web';
  verifiedAt?: string;
}
```

**Entitlements are flags, not SKUs.** Check `proUnlock`, never "did they buy
product X". This is what makes the $15.99 upgrade path possible later without
rewriting every gate.

---

## Dexie schema

```ts
db.version(1).stores({
  items:        'id, propertyId, roomId, category, deletedAt, updatedAt, [propertyId+deletedAt]',
  docs:         'id, itemId, kind, storageMode, linkStatus, deletedAt',
  blobs:        'id, sha256',
  properties:   'id, isDefault, deletedAt',
  rooms:        'id, propertyId, sortOrder, deletedAt, [propertyId+deletedAt]',
  maintenance:  'id, itemId, date, deletedAt',
  settings:     'id',
});
```

Only indexed fields are listed; Dexie stores the whole object regardless.

**The compound index `[propertyId+deletedAt]`** is the one the main list screen
uses on every render. Add it now.

**Expiry is not indexed** because it is computed. The list loads all non-deleted
items for the property and sorts in memory. At the scale of a home inventory —
hundreds of items, not millions — this is correct and simpler than maintaining a
denormalised sort key. Revisit only if someone has 5,000 items.

---

## Migrations

```ts
db.version(2).stores({ /* ... */ }).upgrade(async tx => {
  await tx.table('items').toCollection().modify(i => {
    i.schemaVersion = 2;
    // transform here
  });
});
```

Rules:

- Forward-only. Never write a downgrade path; older app versions must refuse to
  open a newer database rather than corrupt it.
- Additive changes need no data migration — absent optional fields read as
  `undefined`.
- Renames and type changes always get an explicit `upgrade()`, never a silent
  reinterpretation.
- **Test every migration against a real exported bundle from the previous version.**
  Keep one committed to the repo as a fixture.

---

## Backup bundle format

A zip named `stash-it-backup-YYYY-MM-DD.stashit`.

```
manifest.json          schema version, app version, counts, checksum
items.json             all items including soft-deleted
docs.json              all docs
properties.json
rooms.json
maintenance.json
settings.json          entitlements stripped
blobs/<blobId>.<ext>   one file per blob, extension from mime
```

```ts
interface Manifest {
  format: 'stash-it-backup';
  formatVersion: 1;
  schemaVersion: number;
  appVersion: string;
  exportedAt: string;
  counts: { items: number; docs: number; blobs: number };
  sha256: string;              // over the concatenated json files
  encrypted: boolean;
}
```

**Decisions baked in here:**

- **JSON, not a database dump.** Human-inspectable. A user with a corrupted install
  and a stuck restore can open the file and see their data — that alone will prevent
  support tickets.
- **Entitlements are stripped.** A backup must not be a way to hand someone else a
  paid unlock. Purchases restore through the store, not the file.
- **Soft-deleted records are included.** Restoring a backup should be able to undo an
  accidental delete.
- **Optional passphrase encryption** (AES-GCM via WebCrypto, PBKDF2 key derivation,
  salt in the manifest). Warn unmissably that a lost passphrase is unrecoverable.

### Restore semantics

Ask the user, every time, with no default:

- **Replace** — wipe local data, restore the bundle. For a new device.
- **Merge** — keep both, last-write-wins per record by `updatedAt`, matching on `id`.
  Blobs dedupe by `sha256`.

Merge is the harder path and the one people actually need. Build and test it first.

**Restore must handle a bundle whose `schemaVersion` is older than the app** by
running it through the same migration chain as the local database. Same code path,
no parallel implementation.

---

## Free tier enforcement

```ts
const FREE_ITEM_LIMIT = 15;

function canAddItem(count: number, e: Entitlements): boolean {
  return e.proUnlock || count < FREE_ITEM_LIMIT;
}
```

The count excludes soft-deleted items. Deleting an item must free a slot, or you
have built a trap.

**What the cap never touches:** reading, editing, exporting, or restoring existing
items. If a user restores a 40-item backup on a free install, all 40 items are
visible, editable and exportable — they simply cannot add a 41st. Locking restored
data behind a paywall is the fastest route to a one-star review and a refund.

---

## Resolved decisions

1. **Thumbnails are generated on add.** A ~200px square WebP written to the blob
   table alongside the full image, referenced by `Item.thumbBlobId`. Costs a few KB
   per item and keeps the list screen instant. Regenerate if the source photo is
   replaced.

2. **Currency is per item, with a device default.** `Settings.currency` seeds the
   field on the add screen; each item stores its own. The inventory report groups
   totals by currency and never converts — an app with no network has no business
   inventing exchange rates. Show separate subtotals per currency.

3. **Rooms are a real entity, seeded and editable.** See the Room section above.

---

## Still to decide

- **Item category vs. room.** Both are ways to slice the list. If the report groups
  by room, category may be redundant — worth watching in use before adding filters
  for both.
- **Photo retention.** When a user replaces an item's photo, keep the old blob for
  the 30-day purge window, or delete immediately? Consistency argues for the purge
  window; storage argues against.
