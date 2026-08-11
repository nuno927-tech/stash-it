/**
 * Room rules.
 *
 *   npm run test:rooms
 *
 * The one that matters most: deleting a room must never take an item with it.
 * Everything else is bookkeeping.
 */

import 'fake-indexeddb/auto';
import { db, ensureFirstRun } from '@/db/db';
import {
  activeRooms,
  createRoom,
  deleteRoom,
  itemCountForRoom,
  itemCountsByRoom,
  moveRoom,
  renameRoom,
  reorderRooms,
  RoomNameTakenError,
} from '@/db/repo';
import { SEED_ROOMS } from '@/db/types';
import { emptyForm, saveNewItem } from '@/lib/addItem';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const names = async (p: string) => (await activeRooms(p)).map((r) => r.name);

async function main() {
  await ensureFirstRun();
  const property = (await db.properties.toArray())[0]!;
  const pid = property.id;

  /* -------------------------------------------------------------- seeds */

  const seeded = await activeRooms(pid);
  check('every seed room lands', seeded.length === SEED_ROOMS.length, `${seeded.length}`);
  check('seeds keep the spec order', (await names(pid))[0] === 'Kitchen', (await names(pid))[0]);
  check('seeds are flagged as seeds', seeded.every((r) => r.isSeed));
  check(
    'sortOrder is spaced for insertion',
    seeded[1]!.sortOrder - seeded[0]!.sortOrder === 100,
    `${seeded[0]!.sortOrder} → ${seeded[1]!.sortOrder}`,
  );

  /* ------------------------------------------------------------- create */

  const denId = await createRoom(pid, '  Den  ');
  const den = (await db.rooms.get(denId))!;
  check('a new room trims its name', den.name === 'Den', `"${den.name}"`);
  check('a user-made room is not a seed', den.isSeed === false);
  check('it goes to the end', (await names(pid)).at(-1) === 'Den');

  let threw = '';
  try {
    await createRoom(pid, 'kitchen');
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('duplicate names are refused, case-insensitively', threw === 'RoomNameTakenError', threw);
  check(
    'the error names the clash',
    /Kitchen/i.test(new RoomNameTakenError('There\'s already a room called "Kitchen".').message),
  );

  threw = '';
  try {
    await createRoom(pid, '  KITCHEN  ');
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('whitespace does not sneak a duplicate through', threw === 'RoomNameTakenError', threw);

  /* ------------------------------------------------------------- rename */

  const kitchen = (await activeRooms(pid)).find((r) => r.name === 'Kitchen')!;
  await renameRoom(kitchen.id, 'Scullery');
  const renamed = (await db.rooms.get(kitchen.id))!;
  check('rename sticks', renamed.name === 'Scullery');
  check('editing a seed clears the seed flag', renamed.isSeed === false);

  threw = '';
  try {
    await renameRoom(kitchen.id, 'Garage');
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('renaming onto another room is refused', threw === 'RoomNameTakenError', threw);

  // Renaming a room to its own name must not trip the uniqueness check.
  threw = '';
  try {
    await renameRoom(kitchen.id, 'Scullery');
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('a room can keep its own name', threw === '', threw);

  /* ---------------------------------------------------------- reorder */

  const before = await names(pid);
  const second = (await activeRooms(pid))[1]!;
  await moveRoom(second.id, -1);
  const after = await names(pid);
  check(
    'moving up swaps with the row above',
    after[0] === before[1] && after[1] === before[0],
    `${before.slice(0, 2).join(',')} → ${after.slice(0, 2).join(',')}`,
  );

  const first = (await activeRooms(pid))[0]!;
  await moveRoom(first.id, -1);
  check('moving the top row up does nothing', (await names(pid))[0] === first.name);

  const last = (await activeRooms(pid)).at(-1)!;
  await moveRoom(last.id, 1);
  check('moving the bottom row down does nothing', (await names(pid)).at(-1) === last.name);

  /* --------------------------------------------------- drag reordering */

  const wasOrder = await names(pid);
  const ids = (await activeRooms(pid)).map((r) => r.id);

  // Move the last room to the front, the way a drag would.
  await reorderRooms(pid, [ids.at(-1)!, ...ids.slice(0, -1)]);
  const nowOrder = await names(pid);
  check('a dragged room lands where it was dropped', nowOrder[0] === wasOrder.at(-1), nowOrder[0]);
  check('nothing else is lost', nowOrder.length === wasOrder.length);
  check(
    'the rest keep their relative order',
    nowOrder.slice(1).join('|') === wasOrder.slice(0, -1).join('|'),
  );

  // Re-sending the same order writes nothing: a drag that ends where it began
  // must not bump updatedAt on every room and make backup merges noisy.
  const current = (await activeRooms(pid)).map((r) => r.id);
  check('an unchanged order writes nothing', (await reorderRooms(pid, current)) === 0);

  // A stale list must never make a room disappear.
  check('a partial list is tolerated', (await reorderRooms(pid, current.slice(0, 3))) >= 0);
  check('and keeps every room', (await activeRooms(pid)).length === wasOrder.length);

  check('unknown ids are ignored', (await reorderRooms(pid, ['nope', ...current])) >= 0);
  check('still every room', (await activeRooms(pid)).length === wasOrder.length);

  /* ------------------------------------------------------------ counts */

  const garage = (await activeRooms(pid)).find((r) => r.name === 'Garage')!;
  const saw = await saveNewItem(
    { ...emptyForm('USD'), name: 'Table Saw', roomId: garage.id },
    pid,
  );
  await saveNewItem({ ...emptyForm('USD'), name: 'Drill', roomId: garage.id }, pid);
  await saveNewItem({ ...emptyForm('USD'), name: 'Homeless Lamp' }, pid);

  check('per-room count is right', (await itemCountForRoom(garage.id)) === 2);
  const counts = await itemCountsByRoom(pid);
  check('the bulk count agrees', counts.byRoom.get(garage.id) === 2);
  check('unassigned items are tallied', counts.unassigned === 1, `${counts.unassigned}`);

  /* ------------------------------------------- delete never cascades */

  const workshop = (await activeRooms(pid)).find((r) => r.name === 'Workshop')!;
  await deleteRoom(garage.id, { kind: 'reassign', toRoomId: workshop.id });

  check('the room is gone from the list', !(await names(pid)).includes('Garage'));
  check('the room is soft-deleted, not erased', (await db.rooms.get(garage.id))?.deletedAt != null);
  check('its items survive', (await db.items.get(saw))!.deletedAt === undefined);
  check('its items moved', (await db.items.get(saw))!.roomId === workshop.id);
  check('the destination count is right', (await itemCountForRoom(workshop.id)) === 2);

  // The other strategy: leave them homeless.
  await deleteRoom(workshop.id, { kind: 'unassign' });
  check('unassign leaves the items alive', (await db.items.get(saw))!.deletedAt === undefined);
  check('unassign clears the room', (await db.items.get(saw))!.roomId === undefined);
  check(
    'those items now count as unassigned',
    (await itemCountsByRoom(pid)).unassigned === 3,
    `${(await itemCountsByRoom(pid)).unassigned}`,
  );

  /* -------------------------------------- a deleted name frees up again */

  threw = '';
  try {
    await createRoom(pid, 'Garage');
  } catch (e) {
    threw = (e as Error).constructor.name;
  }
  check('a deleted room releases its name', threw === '', threw);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
