/**
 * Backup bundle — export and restore.
 *
 * Format per stash-it-data-model.md: a zip named
 * `stash-it-backup-YYYY-MM-DD.stashit` containing one JSON file per table plus
 * the raw blobs. JSON rather than a database dump on purpose — a user with a
 * broken install and a stuck restore can open the file and read their data.
 *
 * Two rules that are easy to get wrong and expensive to get wrong:
 *  - Entitlements never leave and never come back. A backup file must not be a
 *    way to hand someone a paid unlock.
 *  - Soft-deleted rows are included, so a restore can undo an accidental delete.
 */

import { unzip, zip, type Unzipped, type Zippable } from 'fflate';
import { db, nowISO } from '@/db/db';
import {
  SCHEMA_VERSION,
  type BlobRecord,
  type Doc,
  type Item,
  type MaintenanceEntry,
  type Property,
  type Room,
  type Settings,
} from '@/db/types';

export const BACKUP_FORMAT = 'stash-it-backup';
export const BACKUP_FORMAT_VERSION = 1;

export interface BackupManifest {
  format: typeof BACKUP_FORMAT;
  formatVersion: number;
  schemaVersion: number;
  appVersion: string;
  exportedAt: string;
  counts: { items: number; docs: number; blobs: number };
  /** Over the concatenated JSON payloads, in TABLE_ORDER. */
  sha256: string;
  encrypted: boolean;
}

/** Settings minus the things that must not travel. */
export type PortableSettings = Omit<Settings, 'entitlements'>;

export interface BundleData {
  items: Item[];
  docs: Doc[];
  properties: Property[];
  rooms: Room[];
  maintenance: MaintenanceEntry[];
  settings: PortableSettings | null;
}

export interface ParsedBundle {
  manifest: BackupManifest;
  data: BundleData;
  blobs: Map<string, { bytes: Uint8Array; mime: string }>;
}

/** Fixed order — the checksum depends on it. */
const TABLE_ORDER = ['items', 'docs', 'properties', 'rooms', 'maintenance', 'settings'] as const;

const MIME_EXT: Record<string, string> = {
  'image/webp': 'webp',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/heic': 'heic',
  'image/gif': 'gif',
  'application/pdf': 'pdf',
};

const EXT_MIME: Record<string, string> = Object.fromEntries(
  Object.entries(MIME_EXT).map(([mime, ext]) => [ext, mime]),
);

function extFor(mime: string): string {
  return MIME_EXT[mime] ?? 'bin';
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const buf = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
  const digest = await crypto.subtle.digest('SHA-256', buf as ArrayBuffer);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function zipAsync(files: Zippable): Promise<Uint8Array> {
  return new Promise((resolve, reject) => {
    zip(files, { level: 6 }, (err, out) => (err ? reject(err) : resolve(out)));
  });
}

function unzipAsync(bytes: Uint8Array): Promise<Unzipped> {
  return new Promise((resolve, reject) => {
    unzip(bytes, (err, out) => (err ? reject(err) : resolve(out)));
  });
}

function concat(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}

export function backupFilename(date = new Date()): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `stash-it-backup-${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())}.stashit`;
}

/* ------------------------------------------------------------------ export */

export async function exportBundle(): Promise<{ blob: Blob; filename: string }> {
  const [items, docs, properties, rooms, maintenance, settings, blobs] = await Promise.all([
    db.items.toArray(),
    db.docs.toArray(),
    db.properties.toArray(),
    db.rooms.toArray(),
    db.maintenance.toArray(),
    db.settings.get('singleton'),
    db.blobs.toArray(),
  ]);

  let portableSettings: PortableSettings | null = null;
  if (settings) {
    const { entitlements: _dropped, ...rest } = settings;
    portableSettings = rest;
  }

  const payloads: Record<(typeof TABLE_ORDER)[number], unknown> = {
    items,
    docs,
    properties,
    rooms,
    maintenance,
    settings: portableSettings,
  };

  const enc = new TextEncoder();
  const jsonBytes = TABLE_ORDER.map((t) => enc.encode(JSON.stringify(payloads[t], null, 2)));
  const checksum = await sha256Hex(concat(jsonBytes));

  const manifest: BackupManifest = {
    format: BACKUP_FORMAT,
    formatVersion: BACKUP_FORMAT_VERSION,
    schemaVersion: SCHEMA_VERSION,
    appVersion: __APP_VERSION__,
    exportedAt: nowISO(),
    counts: { items: items.length, docs: docs.length, blobs: blobs.length },
    sha256: checksum,
    encrypted: false,
  };

  const files: Zippable = {
    'manifest.json': enc.encode(JSON.stringify(manifest, null, 2)),
  };
  TABLE_ORDER.forEach((t, i) => {
    files[`${t}.json`] = jsonBytes[i]!;
  });

  for (const rec of blobs) {
    const buf = new Uint8Array(await rec.data.arrayBuffer());
    files[`blobs/${rec.id}.${extFor(rec.mime)}`] = buf;
  }

  const zipped = await zipAsync(files);
  await db.settings.update('singleton', { lastBackupAt: nowISO() });

  return {
    blob: new Blob([zipped as BlobPart], { type: 'application/zip' }),
    filename: backupFilename(),
  };
}

/* ------------------------------------------------------------------- parse */

export class BundleError extends Error {}

export async function parseBundle(file: Blob): Promise<ParsedBundle> {
  let entries: Unzipped;
  try {
    entries = await unzipAsync(new Uint8Array(await file.arrayBuffer()));
  } catch {
    throw new BundleError('That file is not a readable backup — the zip could not be opened.');
  }

  const dec = new TextDecoder();
  const read = (name: string): unknown => {
    const raw = entries[name];
    if (!raw) return null;
    return JSON.parse(dec.decode(raw));
  };

  const manifest = read('manifest.json') as BackupManifest | null;
  if (!manifest || manifest.format !== BACKUP_FORMAT) {
    throw new BundleError('That file is not a Stash it backup.');
  }
  if (manifest.encrypted) {
    throw new BundleError('This backup is encrypted. Passphrase restore is not built yet.');
  }
  if (manifest.formatVersion > BACKUP_FORMAT_VERSION) {
    throw new BundleError(
      `This backup uses format v${manifest.formatVersion}, newer than this app understands. Update Stash it and try again.`,
    );
  }
  if (manifest.schemaVersion > SCHEMA_VERSION) {
    throw new BundleError(
      `This backup was written by a newer version of Stash it (schema v${manifest.schemaVersion}). Update the app first — reading it now would lose data.`,
    );
  }

  // Checksum over the same bytes, in the same order, as the export wrote them.
  const jsonBytes = TABLE_ORDER.map((t) => entries[`${t}.json`] ?? new Uint8Array());
  const actual = await sha256Hex(concat(jsonBytes));
  if (actual !== manifest.sha256) {
    throw new BundleError('This backup is damaged — its contents do not match its checksum.');
  }

  const blobs = new Map<string, { bytes: Uint8Array; mime: string }>();
  for (const [path, bytes] of Object.entries(entries)) {
    if (!path.startsWith('blobs/')) continue;
    const base = path.slice('blobs/'.length);
    const dot = base.lastIndexOf('.');
    const id = dot === -1 ? base : base.slice(0, dot);
    const ext = dot === -1 ? 'bin' : base.slice(dot + 1);
    blobs.set(id, { bytes, mime: EXT_MIME[ext] ?? 'application/octet-stream' });
  }

  const data: BundleData = {
    items: (read('items.json') as Item[]) ?? [],
    docs: (read('docs.json') as Doc[]) ?? [],
    properties: (read('properties.json') as Property[]) ?? [],
    rooms: (read('rooms.json') as Room[]) ?? [],
    maintenance: (read('maintenance.json') as MaintenanceEntry[]) ?? [],
    settings: read('settings.json') as PortableSettings | null,
  };

  return { manifest, data: migrateBundle(data, manifest.schemaVersion), blobs };
}

/**
 * Brings an older bundle up to the current schema. There is only v1 today, so
 * this is a pass-through — but the hook exists so a v2 restore has one obvious
 * place to live, and never grows into a parallel implementation of the Dexie
 * migration chain.
 */
function migrateBundle(data: BundleData, fromVersion: number): BundleData {
  if (fromVersion === SCHEMA_VERSION) return data;
  // for (let v = fromVersion; v < SCHEMA_VERSION; v++) data = STEPS[v](data);
  return data;
}

/* ----------------------------------------------------------------- restore */

export type RestoreMode = 'replace' | 'merge';

export interface RestoreResult {
  mode: RestoreMode;
  added: number;
  updated: number;
  skipped: number;
  blobsAdded: number;
}

/** Newer `updatedAt` wins. Ties keep what's already on the device. */
function isNewer(incoming: { updatedAt: string }, local: { updatedAt: string }): boolean {
  return incoming.updatedAt > local.updatedAt;
}

export async function restoreBundle(
  bundle: ParsedBundle,
  mode: RestoreMode,
): Promise<RestoreResult> {
  const result: RestoreResult = { mode, added: 0, updated: 0, skipped: 0, blobsAdded: 0 };
  const { data, blobs } = bundle;

  // Hash everything up front. A Dexie transaction dies the moment you await a
  // promise it doesn't own — and crypto.subtle is very much not Dexie's.
  const incomingBlobs = await Promise.all(
    [...blobs].map(async ([id, { bytes, mime }]) => ({
      id,
      mime,
      size: bytes.length,
      sha256: await sha256Hex(bytes),
      data: new Blob([new Uint8Array(bytes) as BlobPart], { type: mime }),
    })),
  );

  await db.transaction(
    'rw',
    [db.items, db.docs, db.blobs, db.properties, db.rooms, db.maintenance, db.settings],
    async () => {
      const localSettings = await db.settings.get('singleton');

      if (mode === 'replace') {
        await Promise.all([
          db.items.clear(),
          db.docs.clear(),
          db.blobs.clear(),
          db.properties.clear(),
          db.rooms.clear(),
          db.maintenance.clear(),
        ]);
      }

      // --- blobs first: docs and thumbnails point at them.
      const existingBlobIds = new Set(await db.blobs.toCollection().primaryKeys());
      const existingHashes = new Set(
        (await db.blobs.toArray()).map((b) => b.sha256).filter(Boolean) as string[],
      );

      for (const incoming of incomingBlobs) {
        if (existingBlobIds.has(incoming.id) || existingHashes.has(incoming.sha256)) {
          result.skipped++;
          continue;
        }
        const rec: BlobRecord = {
          id: incoming.id,
          data: incoming.data,
          mime: incoming.mime,
          bytes: incoming.size,
          sha256: incoming.sha256,
          createdAt: nowISO(),
        };
        await db.blobs.add(rec);
        existingBlobIds.add(incoming.id);
        existingHashes.add(incoming.sha256);
        result.blobsAdded++;
      }

      // --- properties, then rooms, then everything that references them.
      await mergeTable(db.properties, data.properties, result, mode);

      // Rooms carry a name-uniqueness rule per property. On merge, an incoming
      // room whose name is already taken by a *different* local row is dropped:
      // the user's own room wins, and their items stay where they are.
      const localRooms = await db.rooms.toArray();
      const takenName = new Map(localRooms.map((r) => [`${r.propertyId} ${r.name}`, r.id]));
      const roomsToApply = data.rooms.filter((r) => {
        const holder = takenName.get(`${r.propertyId} ${r.name}`);
        if (mode === 'merge' && holder && holder !== r.id) {
          result.skipped++;
          return false;
        }
        return true;
      });
      await mergeTable(db.rooms, roomsToApply, result, mode);

      await mergeTable(db.items, data.items, result, mode);
      await mergeTable(db.docs, data.docs, result, mode);
      await mergeTable(db.maintenance, data.maintenance, result, mode);

      // --- settings: take the bundle's preferences, keep this device's
      // entitlements. A restored file can never grant a paid unlock.
      if (data.settings && localSettings) {
        await db.settings.put({
          ...data.settings,
          id: 'singleton',
          entitlements: localSettings.entitlements,
          devModeEnabled: localSettings.devModeEnabled,
        });
      }
    },
  );

  return result;
}

type HasIdAndUpdatedAt = { id: string; updatedAt: string };

async function mergeTable<T extends HasIdAndUpdatedAt>(
  table: { get(id: string): Promise<T | undefined>; put(row: T): Promise<unknown> },
  rows: T[],
  result: RestoreResult,
  mode: RestoreMode,
): Promise<void> {
  for (const row of rows) {
    if (mode === 'replace') {
      await table.put(row);
      result.added++;
      continue;
    }
    const local = await table.get(row.id);
    if (!local) {
      await table.put(row);
      result.added++;
    } else if (isNewer(row, local)) {
      await table.put(row);
      result.updated++;
    } else {
      result.skipped++;
    }
  }
}

/* ------------------------------------------------------------ file plumbing */

/**
 * Hands the file to the OS. On phones the share sheet is the only route to
 * somewhere the user can actually find the file again, so prefer it; fall back
 * to a download on desktop and anywhere sharing files is unsupported.
 */
export async function saveBundle(blob: Blob, filename: string): Promise<'shared' | 'downloaded'> {
  const file = new File([blob], filename, { type: 'application/zip' });

  if (typeof navigator.canShare === 'function' && navigator.canShare({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: 'Stash it backup' });
      return 'shared';
    } catch (e) {
      // A user who taps Cancel is not an error worth reporting; fall through
      // to the download only if sharing actually failed.
      if ((e as DOMException)?.name === 'AbortError') return 'shared';
    }
  }

  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
  return 'downloaded';
}
