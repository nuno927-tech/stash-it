import Dexie, { type Table } from 'dexie';
import { v7 as uuidv7 } from 'uuid';
import {
  SCHEMA_VERSION, SEED_ROOMS,
  type Item, type Doc, type BlobRecord, type Property,
  type Room, type MaintenanceEntry, type Settings,
} from './types';

export class StashDB extends Dexie {
  items!: Table<Item, string>;
  docs!: Table<Doc, string>;
  blobs!: Table<BlobRecord, string>;
  properties!: Table<Property, string>;
  rooms!: Table<Room, string>;
  maintenance!: Table<MaintenanceEntry, string>;
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
