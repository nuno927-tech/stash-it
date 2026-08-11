import { db, newId, nowISO, seedRoomsForProperty } from './db';
import {
  SCHEMA_VERSION, FREE_ITEM_LIMIT,
  type Item, type Doc, type Room, type Entitlements, type BlobRecord,
} from './types';

/* ------------------------------------------------------------------ items */

export async function activeItems(propertyId: string): Promise<Item[]> {
  const rows = await db.items.where('propertyId').equals(propertyId).toArray();
  return rows.filter((i) => !i.deletedAt);
}

export async function activeItemCount(propertyId: string): Promise<number> {
  return (await activeItems(propertyId)).length;
}

/** The cap blocks new additions only. Existing items stay fully usable. */
export function canAddItem(count: number, e: Entitlements): boolean {
  return e.proUnlock || count < FREE_ITEM_LIMIT;
}

export async function createItem(
  input: Omit<Item, 'id' | 'schemaVersion' | 'createdAt' | 'updatedAt'>,
): Promise<string> {
  const ts = nowISO();
  const item: Item = { ...input, id: newId(), schemaVersion: SCHEMA_VERSION, createdAt: ts, updatedAt: ts };
  await db.items.add(item);
  return item.id;
}

export async function updateItem(id: string, patch: Partial<Item>): Promise<void> {
  await db.items.update(id, { ...patch, updatedAt: nowISO() });
}

/** Soft delete. Frees a free-tier slot immediately; purged after 30 days. */
export async function softDeleteItem(id: string): Promise<void> {
  await db.items.update(id, { deletedAt: nowISO(), updatedAt: nowISO() });
}

export async function restoreItem(id: string): Promise<void> {
  await db.items.update(id, { deletedAt: undefined, updatedAt: nowISO() });
}

export const PURGE_AFTER_DAYS = 30;

export async function purgeExpiredDeletes(now = Date.now()): Promise<number> {
  const cutoff = now - PURGE_AFTER_DAYS * 86_400_000;
  const stale = (await db.items.toArray()).filter(
    (i) => i.deletedAt && new Date(i.deletedAt).getTime() < cutoff,
  );
  for (const item of stale) {
    const docs = await db.docs.where('itemId').equals(item.id).toArray();
    const blobIds = docs.map((d) => d.blobId).filter(Boolean) as string[];
    if (item.thumbBlobId) blobIds.push(item.thumbBlobId);
    await db.blobs.bulkDelete(blobIds);
    await db.docs.bulkDelete(docs.map((d) => d.id));
    await db.items.delete(item.id);
  }
  return stale.length;
}

/* ------------------------------------------------------------------- docs */

export class DocValidationError extends Error {}

/** Single source of truth for the linked/local invariant. Both paths call this. */
export function assertDocValid(d: Pick<Doc, 'storageMode' | 'url' | 'blobId'>): void {
  if (d.storageMode === 'linked' && !d.url) {
    throw new DocValidationError('A linked document needs a URL.');
  }
  if (d.storageMode === 'local' && !d.blobId) {
    throw new DocValidationError('A stored document needs a file.');
  }
}

export async function createDoc(
  input: Omit<Doc, 'id' | 'schemaVersion' | 'createdAt' | 'updatedAt'>,
): Promise<string> {
  assertDocValid(input);
  const ts = nowISO();
  const doc: Doc = { ...input, id: newId(), schemaVersion: SCHEMA_VERSION, createdAt: ts, updatedAt: ts };
  await db.docs.add(doc);
  return doc.id;
}

export async function docsForItem(itemId: string): Promise<Doc[]> {
  const rows = await db.docs.where('itemId').equals(itemId).toArray();
  return rows.filter((d) => !d.deletedAt);
}

/* ------------------------------------------------------------------ blobs */

async function sha256(blob: Blob): Promise<string | undefined> {
  if (!crypto?.subtle) return undefined;
  const buf = await blob.arrayBuffer();
  const hash = await crypto.subtle.digest('SHA-256', buf);
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Dedupes on content hash — the same receipt attached twice stores once. */
export async function putBlob(blob: Blob): Promise<string> {
  const digest = await sha256(blob);
  if (digest) {
    const existing = await db.blobs.where('sha256').equals(digest).first();
    if (existing) return existing.id;
  }
  const rec: BlobRecord = {
    id: newId(),
    data: blob,
    mime: blob.type || 'application/octet-stream',
    bytes: blob.size,
    sha256: digest,
    createdAt: nowISO(),
  };
  await db.blobs.add(rec);
  return rec.id;
}

export const THUMB_SIZE = 200;

/** Generated on add: a square WebP a few KB in size, so the list renders instantly. */
export async function makeThumbnail(file: Blob, size = THUMB_SIZE): Promise<Blob> {
  const bitmap = await createImageBitmap(file);
  const side = Math.min(bitmap.width, bitmap.height);
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(
    bitmap,
    (bitmap.width - side) / 2, (bitmap.height - side) / 2, side, side,
    0, 0, size, size,
  );
  bitmap.close();
  return new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('Thumbnail failed'))), 'image/webp', 0.82),
  );
}

/* ------------------------------------------------------------------ rooms */

const norm = (s: string) => s.trim().replace(/\s+/g, ' ');

export class RoomNameTakenError extends Error {}

/** IndexedDB can't express a partial unique index, so uniqueness lives here. */
async function assertRoomNameFree(propertyId: string, name: string, ignoreId?: string) {
  const rooms = await activeRooms(propertyId);
  const clash = rooms.some(
    (r) => r.id !== ignoreId && r.name.toLowerCase() === norm(name).toLowerCase(),
  );
  if (clash) throw new RoomNameTakenError(`There's already a room called "${norm(name)}".`);
}

export async function activeRooms(propertyId: string): Promise<Room[]> {
  const rows = await db.rooms.where('propertyId').equals(propertyId).toArray();
  return rows.filter((r) => !r.deletedAt).sort((a, b) => a.sortOrder - b.sortOrder);
}

export async function createRoom(propertyId: string, name: string): Promise<string> {
  await assertRoomNameFree(propertyId, name);
  const rooms = await activeRooms(propertyId);
  const ts = nowISO();
  const room: Room = {
    id: newId(),
    propertyId,
    name: norm(name),
    sortOrder: (rooms.at(-1)?.sortOrder ?? 0) + 100,
    isSeed: false,
    createdAt: ts,
    updatedAt: ts,
  };
  await db.rooms.add(room);
  return room.id;
}

/** Editing a seed clears the flag, so future versions never touch it again. */
export async function renameRoom(id: string, name: string): Promise<void> {
  const room = await db.rooms.get(id);
  if (!room) return;
  await assertRoomNameFree(room.propertyId, name, id);
  await db.rooms.update(id, { name: norm(name), isSeed: false, updatedAt: nowISO() });
}

export type RoomDeleteStrategy =
  | { kind: 'reassign'; toRoomId: string }
  | { kind: 'unassign' };

/**
 * Never cascades. Items are moved or unassigned first, so nothing is left
 * pointing at a dangling roomId.
 */
export async function deleteRoom(id: string, strategy: RoomDeleteStrategy): Promise<void> {
  await db.transaction('rw', db.rooms, db.items, async () => {
    const affected = (await db.items.where('roomId').equals(id).toArray()).filter((i) => !i.deletedAt);
    const ts = nowISO();
    for (const item of affected) {
      await db.items.update(item.id, {
        roomId: strategy.kind === 'reassign' ? strategy.toRoomId : undefined,
        updatedAt: ts,
      });
    }
    await db.rooms.update(id, { deletedAt: ts, updatedAt: ts });
  });
}

/**
 * Swaps a room with its neighbour. Swapping sortOrder rather than renumbering
 * the whole list keeps the write to two rows, which matters because every
 * touched row's updatedAt feeds backup merge conflicts.
 */
export async function moveRoom(id: string, direction: -1 | 1): Promise<void> {
  const room = await db.rooms.get(id);
  if (!room) return;

  const ordered = await activeRooms(room.propertyId);
  const at = ordered.findIndex((r) => r.id === id);
  const neighbour = ordered[at + direction];
  if (at === -1 || !neighbour) return; // already at the end

  const ts = nowISO();
  await db.transaction('rw', db.rooms, async () => {
    await db.rooms.update(room.id, { sortOrder: neighbour.sortOrder, updatedAt: ts });
    await db.rooms.update(neighbour.id, { sortOrder: room.sortOrder, updatedAt: ts });
  });
}

/**
 * Writes a whole new order at once, for drag and drop.
 *
 * Renumbers from scratch rather than trying to compute gaps: a drag can move a
 * row anywhere, and evenly spaced values keep later single-step moves cheap.
 * Rows whose position didn't change aren't written, so a small drag doesn't
 * bump `updatedAt` on fourteen records and turn every backup merge noisy.
 */
export async function reorderRooms(propertyId: string, orderedIds: string[]): Promise<number> {
  const current = await activeRooms(propertyId);
  const known = new Set(current.map((r) => r.id));

  // Ignore anything unknown, then append any room the caller forgot, so a
  // stale list can never make a room vanish from the ordering.
  const ids = orderedIds.filter((id) => known.has(id));
  for (const room of current) if (!ids.includes(room.id)) ids.push(room.id);

  const ts = nowISO();
  let written = 0;

  await db.transaction('rw', db.rooms, async () => {
    for (const [i, id] of ids.entries()) {
      const sortOrder = (i + 1) * 100;
      const room = current.find((r) => r.id === id);
      if (!room || room.sortOrder === sortOrder) continue;
      await db.rooms.update(id, { sortOrder, updatedAt: ts });
      written++;
    }
  });

  return written;
}

/** Item counts for every room in one pass, plus the unassigned tally. */
export async function itemCountsByRoom(
  propertyId: string,
): Promise<{ byRoom: Map<string, number>; unassigned: number }> {
  const items = await activeItems(propertyId);
  const byRoom = new Map<string, number>();
  let unassigned = 0;

  for (const item of items) {
    if (!item.roomId) {
      unassigned++;
      continue;
    }
    byRoom.set(item.roomId, (byRoom.get(item.roomId) ?? 0) + 1);
  }

  return { byRoom, unassigned };
}

export async function itemCountForRoom(roomId: string): Promise<number> {
  const rows = await db.items.where('roomId').equals(roomId).toArray();
  return rows.filter((i) => !i.deletedAt).length;
}

/* -------------------------------------------------------------- properties */

export async function createProperty(name: string): Promise<string> {
  const ts = nowISO();
  const id = newId();
  await db.properties.add({ id, name: norm(name), isDefault: false, createdAt: ts, updatedAt: ts });
  await seedRoomsForProperty(id);   // each property gets its own room list
  return id;
}
