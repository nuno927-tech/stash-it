/**
 * Dev-only fixtures. The four items from the concept mockup, with purchase
 * dates computed *relative to today* so they always land in the state they are
 * meant to demonstrate: covered, ending soon, and expired.
 *
 * Never imported by production code paths — Settings gates it behind
 * `devModeEnabled`.
 */

import { db, newId, nowISO } from '@/db/db';
import { SCHEMA_VERSION, type Item } from '@/db/types';
import { addMonths, toISODate } from '@/lib/warranty';

/** A purchase date `monthsOfCover` long that still has `daysLeft` to run. */
function purchaseDateFor(monthsOfCover: number, daysLeft: number): string {
  const end = new Date();
  end.setDate(end.getDate() + daysLeft);
  return toISODate(addMonths(end, -monthsOfCover));
}

type Fixture = Omit<Item, 'id' | 'schemaVersion' | 'createdAt' | 'updatedAt' | 'propertyId'>;

function fixtures(): Fixture[] {
  return [
    {
      name: 'LG Refrigerator',
      brand: 'LG',
      model: 'LRFDS3016S',
      purchaseDate: purchaseDateFor(60, 853), // 2y 4m left, as per the mockup
      purchasePriceCents: 219_900,
      currency: 'USD',
      retailer: 'Best Buy',
      warranty: { months: 60, provider: 'LG Electronics' },
    },
    {
      name: 'Bosch Dishwasher',
      brand: 'Bosch',
      model: 'SHXM4AY55N',
      purchaseDate: purchaseDateFor(24, 21), // ending soon
      purchasePriceCents: 84_900,
      currency: 'USD',
      retailer: 'Lowe’s',
      warranty: { months: 24, provider: 'Bosch Home', phone: '1-800-944-2904' },
    },
    {
      name: 'DeWalt Table Saw',
      brand: 'DeWalt',
      model: 'DWE7491RS',
      purchaseDate: purchaseDateFor(36, 609), // 1y 8m left, as per the mockup
      purchasePriceCents: 64_900,
      currency: 'USD',
      retailer: 'Home Depot',
      warranty: { months: 36, provider: 'DeWalt' },
    },
    {
      name: 'Sony Bravia',
      brand: 'Sony',
      model: 'XR55A80K',
      purchaseDate: purchaseDateFor(12, -430), // long expired
      purchasePriceCents: 139_900,
      currency: 'USD',
      retailer: 'Amazon',
      warranty: { months: 12, provider: 'Sony' },
    },
  ];
}

export async function seedDemoItems(propertyId: string): Promise<number> {
  const ts = nowISO();
  const rows: Item[] = fixtures().map((f) => ({
    ...f,
    id: newId(),
    schemaVersion: SCHEMA_VERSION,
    propertyId,
    createdAt: ts,
    updatedAt: ts,
  }));
  await db.items.bulkAdd(rows);
  return rows.length;
}

/** Hard-removes only the demo rows, matched by model number. */
export async function clearDemoItems(): Promise<number> {
  const models = fixtures().map((f) => f.model);
  const doomed = await db.items.filter((i) => !!i.model && models.includes(i.model)).toArray();
  await db.items.bulkDelete(doomed.map((i) => i.id));
  return doomed.length;
}
