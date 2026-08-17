import Dexie, { type Table } from 'dexie';
import { v7 as uuidv7 } from 'uuid';
import {
  LATER_SEED_ROOMS, SCHEMA_VERSION, SEED_ROOMS,
  type Item, type Doc, type BlobRecord, type Property,
  type Room, type MaintenanceEntry, type Settings, type Subscription,
} from './types';

export class StashDB extends Dexie {
  items!: Table<Item, string>;
  docs!: Table<Doc, string>;
  blobs!: Table<BlobRecord, string>;
  properties!: Table<Property, string>;
  rooms!: Table<Room, string>;
  maintenance!: Table<MaintenanceEntry, string>;
  subscriptions!: Table<Subscription, string>;
  settings!: Table<Settings, string>;

  constructor() {
    super('stash-it');

    // Migrations are forward-only. An older app build must refuse to open a newer
    // database rather than reinterpret it. Never write a downgrade path.
    this.version(1).stores({
      items: 'id, propertyId, roomId, category, deletedAt, updatedAt, [propertyId+deletedAt]',
      docs: 'id, itemId, kind, storageMode, linkStatus, deletedAt',
      blobs: 'id, sha256',
      properties: 'id, isDefault, deletedAt',
      rooms: 'id, propertyId, sortOrder, deletedAt, [propertyId+deletedAt]',
      maintenance: 'id, itemId, date, deletedAt',
      settings: 'id',
    });

    // v2: category removed. Room says where a thing is and the icon comes from
    // the item's own words, so category was a question with no consequence.
    // Dropping the index requires a version bump; the upgrade clears the
    // stored values so nothing is left behind referencing a field that no
    // longer exists in the type.
    this.version(2)
      .stores({
        items: 'id, propertyId, roomId, deletedAt, updatedAt, [propertyId+deletedAt]',
      })
      .upgrade(async (tx) => {
        await tx
          .table('items')
          .toCollection()
          .modify((item: Record<string, unknown>) => {
            delete item.category;
            item.schemaVersion = SCHEMA_VERSION;
          });
        for (const name of ['docs', 'maintenance']) {
          await tx
            .table(name)
            .toCollection()
            .modify((row: Record<string, unknown>) => {
              row.schemaVersion = SCHEMA_VERSION;
            });
        }
        await tx
          .table('settings')
          .toCollection()
          .modify((row: Record<string, unknown>) => {
            row.schemaVersion = SCHEMA_VERSION;
          });
      });

    /**
     * v3 changes no record shape — only the seeded data — so SCHEMA_VERSION
     * stays at 2. Dexie's version tracks the database; SCHEMA_VERSION tracks
     * what a record looks like, which is what backups care about.
     *
     * Adds rooms introduced after release, skipping any a user already has
     * under that name. Renamed and user-made rooms are never touched.
     */
    this.version(3).upgrade(async (tx) => {
      const rooms = tx.table('rooms');
      const all = (await rooms.toArray()) as Room[];
      const ts = nowISO();

      for (const property of (await tx.table('properties').toArray()) as Property[]) {
        const mine = all.filter((r) => r.propertyId === property.id && !r.deletedAt);

        for (const seed of LATER_SEED_ROOMS) {
          const taken = mine.some((r) => r.name.toLowerCase() === seed.name.toLowerCase());
          if (taken) continue;

          // Slot it just after its neighbour, or at the end if that room has
          // been renamed or removed.
          const after = mine.find((r) => r.name.toLowerCase() === seed.after.toLowerCase());
          const next = after
            ? mine.filter((r) => r.sortOrder > after.sortOrder).sort((a, b) => a.sortOrder - b.sortOrder)[0]
            : undefined;
          const sortOrder = after
            ? Math.floor((after.sortOrder + (next?.sortOrder ?? after.sortOrder + 200)) / 2)
            : Math.max(0, ...mine.map((r) => r.sortOrder)) + 100;

          await rooms.add({
            id: newId(),
            propertyId: property.id,
            name: seed.name,
            sortOrder,
            isSeed: true,
            createdAt: ts,
            updatedAt: ts,
          });
        }
      }
    });

    /**
     * v4: subscriptions.
     *
     * A new table, and no existing record changes shape. They are restamped to
     * SCHEMA_VERSION 3 anyway, because that field answers "does this match the
     * current shape" rather than "which migration last touched it" — leaving
     * items at 2 while newly created ones say 3 would make
     * `record.schemaVersion === SCHEMA_VERSION` a question with no useful
     * answer. Writing the same constant to every row is idempotent, so an
     * interrupted upgrade simply runs again.
     */
    this.version(4)
      .stores({
        subscriptions: 'id, propertyId, deletedAt, anchorDate, [propertyId+deletedAt]',
      })
      .upgrade(async (tx) => {
        for (const name of ['items', 'docs', 'maintenance', 'settings']) {
          await tx
            .table(name)
            .toCollection()
            .modify((row: Record<string, unknown>) => {
              row.schemaVersion = SCHEMA_VERSION;
            });
        }
      });
  }
}

export const db = new StashDB();

export const nowISO = () => new Date().toISOString();
export const newId = () => uuidv7();

function deviceCurrency(): string {
  try {
    const region = new Intl.Locale(navigator.language).region;
    const map: Record<string, string> = {
      US: 'USD', GB: 'GBP', CA: 'CAD', AU: 'AUD', NZ: 'NZD',
      IE: 'EUR', DE: 'EUR', FR: 'EUR', ES: 'EUR', IT: 'EUR', NL: 'EUR',
      JP: 'JPY', IN: 'INR', BR: 'BRL', MX: 'MXN', ZA: 'ZAR',
    };
    return (region && map[region]) || 'USD';
  } catch {
    return 'USD';
  }
}

/** Seeds a new property with its own copy of the room list. */
export async function seedRoomsForProperty(propertyId: string): Promise<void> {
  const ts = nowISO();
  await db.rooms.bulkAdd(
    SEED_ROOMS.map((name, i) => ({
      id: newId(),
      propertyId,
      name,
      sortOrder: (i + 1) * 100,
      isSeed: true,
      createdAt: ts,
      updatedAt: ts,
    })),
  );
}

/** Idempotent. Safe to call on every launch. */
export async function ensureFirstRun(): Promise<void> {
  await db.transaction('rw', db.properties, db.rooms, db.settings, async () => {
    let property = await db.properties.filter((p) => !p.deletedAt).first();

    if (!property) {
      const ts = nowISO();
      property = {
        id: newId(),
        name: 'Home',
        isDefault: true,
        createdAt: ts,
        updatedAt: ts,
      };
      await db.properties.add(property);
      await seedRoomsForProperty(property.id);
    }

    const settings = await db.settings.get('singleton');
    if (!settings) {
      await db.settings.add({
        id: 'singleton',
        schemaVersion: SCHEMA_VERSION,
        reminderOffsetsDays: [30],
        currency: deviceCurrency(),
        backupReminderDays: 30,
        entitlements: { reportUnlock: false, proUnlock: false },
        devModeEnabled: false,
      });
    }
  });
}
