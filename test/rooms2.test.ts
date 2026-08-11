/**
 * Room icons and the Family Room migration.
 *
 *   npm run test:rooms2
 *
 * The migration rule that matters: adding a seed later must never disturb a
 * room the user has renamed, reordered or created.
 */

import 'fake-indexeddb/auto';
import Dexie from 'dexie';
import { db, ensureFirstRun } from '@/db/db';
import { activeRooms } from '@/db/repo';
import { LATER_SEED_ROOMS, SEED_ROOMS } from '@/db/types';
import { roomIconKey } from '@/components/RoomIcon';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const ts = '2026-01-01T00:00:00.000Z';

/* ------------------------------------------------------------- icons */

const icons: [string, string][] = [
  ['Kitchen', 'kitchen'],
  ['Living Room', 'living'],
  ['Family Room', 'family'],
  ['Dining Room', 'dining'],
  ['Primary Bedroom', 'bedroom'],
  ['Bathroom', 'bathroom'],
  ['Laundry', 'laundry'],
  ['Garage', 'garage'],
  ['Basement', 'basement'],
  ['Attic', 'attic'],
  ['Office', 'office'],
  ['Workshop', 'workshop'],
  ['Outdoor', 'outdoor'],
  ['Storage', 'storage'],
  // Rooms people invent.
  ['Den', 'family'],
  ['Nursery', 'nursery'],
  ['Home Gym', 'gym'],
  ['Pantry', 'pantry'],
  ['Hallway', 'hall'],
  ['The Shed', 'workshop'],
  ['Guest Room', 'bedroom'],
  ['En suite', 'bathroom'],
  ['Back Garden', 'outdoor'],
  ['Cellar', 'basement'],
  ['Loft', 'attic'],
  // No idea — the generic house.
  ['Zone 4', 'room'],
  ['Bob', 'room'],
];

for (const [name, want] of icons) {
  const got = roomIconKey(name);
  check(`${name} → ${want}`, got === want, got === want ? '' : `got ${got}`);
}

// "Living Room" must not be caught by the bare word "room".
check('a multi-word room name wins over the generic', roomIconKey('Living Room') === 'living');
check('case does not matter', roomIconKey('GARAGE') === 'garage');

/* ------------------------------------------------- an existing install */

async function seedPreFamilyRoom(withEdits: boolean) {
  const old = new Dexie('stash-it');
  old.version(2).stores({
    items: 'id, propertyId, roomId, deletedAt, updatedAt, [propertyId+deletedAt]',
    docs: 'id, itemId, kind, storageMode, linkStatus, deletedAt',
    blobs: 'id, sha256',
    properties: 'id, isDefault, deletedAt',
    rooms: 'id, propertyId, sortOrder, deletedAt, [propertyId+deletedAt]',
    maintenance: 'id, itemId, date, deletedAt',
    settings: 'id',
  });
  await old.open();

  await old.table('properties').add({
    id: 'p1',
    name: 'Home',
    isDefault: true,
    createdAt: ts,
    updatedAt: ts,
  });

  // The original fourteen, before Family Room existed.
  const original = SEED_ROOMS.filter((n) => n !== 'Family Room');
  await old.table('rooms').bulkAdd(
    original.map((name, i) => ({
      id: `r${i}`,
      propertyId: 'p1',
      name: withEdits && name === 'Living Room' ? 'Lounge' : name,
      sortOrder: (i + 1) * 100,
      isSeed: !(withEdits && name === 'Living Room'),
      createdAt: ts,
      updatedAt: ts,
    })),
  );

  old.close();
}

async function main() {
  await seedPreFamilyRoom(false);
  await ensureFirstRun();

  const rooms = await activeRooms('p1');
  const names = rooms.map((r) => r.name);

  check('Family Room is added to an existing install', names.includes('Family Room'));
  check('nothing else is lost', rooms.length === SEED_ROOMS.length, `${rooms.length}`);
  check(
    'it lands right after Living Room',
    names[names.indexOf('Living Room') + 1] === 'Family Room',
    names.slice(0, 4).join(', '),
  );
  check('it is marked as a seed', rooms.find((r) => r.name === 'Family Room')?.isSeed === true);

  // Running the upgrade again must not add a second one.
  const before = rooms.length;
  db.close();
  await db.open();
  check('reopening adds no duplicate', (await activeRooms('p1')).length === before);

  check('the seed list itself is deduplicated', new Set(SEED_ROOMS).size === SEED_ROOMS.length);
  check('the later-seed list names a real anchor', LATER_SEED_ROOMS.every((s) => SEED_ROOMS.includes(s.after)));

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
