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
  type Subscription,
  type Paper,
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

/**
 * Settings minus the things that must not travel: a paid unlock, and a lock
 * credential that only exists in one device's keychain. Carrying the latter
 * into a restore would raise a lock screen no authenticator on the new device
 * could ever satisfy.
 */
/*
  What travels, and what is a fact about one handset.

  Entitlements, the biometric credential and the push endpoint are all the
  second kind. A push endpoint identifies one browser on one phone; restoring
  it onto a new one would leave that device believing it is subscribed to a
  channel nothing ever registered for it, and quietly waiting for reminders
  that go to a handset in a drawer.
*/
export type PortableSettings = Omit<
  Settings,
  | 'entitlements'
  | 'biometricLock'
  | 'lockCredentialId'
  | 'pushEnabled'
  | 'pushEndpoint'
  | 'pushSyncedAt'
  | 'pushWakes'
>;

export interface BundleData {
  items: Item[];
  docs: Doc[];
  properties: Property[];
  rooms: Room[];
  maintenance: MaintenanceEntry[];
  subscriptions: Subscription[];
  papers: Paper[];
  settings: PortableSettings | null;
}

export interface ParsedBundle {
  manifest: BackupManifest;
  data: BundleData;
  blobs: Map<string, { bytes: Uint8Array; mime: string }>;
}

/**
 * Fixed order — the checksum depends on it.
 *
 * New tables go on the end, never in the middle. A bundle written before a
 * table existed simply has no file for it, and a missing entry contributes
 * zero bytes to the concatenation — so appending leaves every older backup's
 * checksum exactly as it was. Inserting one anywhere else would invalidate
 * every backup ever written.
 */
const TABLE_ORDER = [
  'items',
  'docs',
  'properties',
  'rooms',
  'maintenance',
  'settings',
  'subscriptions',
  'papers',
] as const;

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
  const [items, docs, properties, rooms, maintenance, subscriptions, papers, settings, blobs] =
    await Promise.all([
      db.items.toArray(),
      db.docs.toArray(),
      db.properties.toArray(),
      db.rooms.toArray(),
      db.maintenance.toArray(),
      db.subscriptions.toArray(),
      db.papers.toArray(),
      db.settings.get('singleton'),
      db.blobs.toArray(),
    ]);

  let portableSettings: PortableSettings | null = null;
  if (settings) {
    const {
      entitlements: _dropped,
      biometricLock: _lock,
      lockCredentialId: _cred,
      pushEnabled: _push,
      pushEndpoint: _endpoint,
      pushSyncedAt: _synced,
      pushWakes: _wakes,
      ...rest
    } = settings;
    portableSettings = rest;
  }

  const payloads: Record<(typeof TABLE_ORDER)[number], unknown> = {
    items,
    docs,
    properties,
    rooms,
    maintenance,
    subscriptions,
    papers,
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

  /*
    NO `lastBackupAt` HERE, and it used to be on the line below this one.

    Building the zip is not backing up. Stamping the date at this point meant
    the app recorded a successful backup the moment the bytes existed in
    memory — before the share sheet had opened, let alone before anyone had
    chosen where to put it. Cancel the sheet and the app still believed it was
    backed up, still showed today's date on the card, and still suppressed the
    reminder for the next thirty days. For a file that was never written
    anywhere.

    That is the worst shape a bug can take in this feature: silent, and in the
    one place whose entire job is preventing loss. The stamp belongs to
    `markBackedUp`, which the caller runs only once the file has actually gone
    somewhere.
  */
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
    subscriptions: (read('subscriptions.json') as Subscription[]) ?? [],
    papers: (read('papers.json') as Paper[]) ?? [],
    settings: read('settings.json') as PortableSettings | null,
  };

  return { manifest, data: migrateBundle(data, manifest.schemaVersion), blobs };
}

/**
 * Brings an older bundle up to the current schema, one version at a time, by
 * the same rules the Dexie upgrade applies to a local database.
 *
 * Keyed by the version being migrated *from*, so adding v3 later means adding
 * one entry and nothing else.
 */
const BUNDLE_MIGRATIONS: Record<number, (data: BundleData) => BundleData> = {
  // v1 → v2: category was dropped from Item.
  1: (data) => ({
    ...data,
    items: data.items.map((item) => {
      const { category: _dropped, ...rest } = item as Item & { category?: string };
      return { ...rest, schemaVersion: 2 };
    }),
    docs: data.docs.map((d) => ({ ...d, schemaVersion: 2 })),
    maintenance: data.maintenance.map((m) => ({ ...m, schemaVersion: 2 })),
    settings: data.settings ? { ...data.settings, schemaVersion: 2 } : null,
  }),

  /*
    v2 → v3: subscriptions arrived.

    No existing record changes shape — v3 added a table, not a field — but
    every record is still restamped, because `schemaVersion` answers "does this
    match the current shape", not "which migration last touched it". An item
    left at 2 is indistinguishable from one that genuinely needs upgrading, and
    `record.schemaVersion === SCHEMA_VERSION` stops being a usable question the
    moment some current records answer no.
  */
  2: (data) => ({
    ...data,
    items: data.items.map((i) => ({ ...i, schemaVersion: 3 })),
    docs: data.docs.map((d) => ({ ...d, schemaVersion: 3 })),
    maintenance: data.maintenance.map((m) => ({ ...m, schemaVersion: 3 })),
    subscriptions: data.subscriptions ?? [],
    settings: data.settings ? { ...data.settings, schemaVersion: 3 } : null,
  }),

  /* v3 → v4: papers arrived. Same shape of step as v2 → v3, and the `?? []`
     matters — a bundle written before the table existed has no papers.json,
     and every consumer downstream indexes into the array unconditionally. */
  3: (data) => ({
    ...data,
    items: data.items.map((i) => ({ ...i, schemaVersion: 4 })),
    docs: data.docs.map((d) => ({ ...d, schemaVersion: 4 })),
    maintenance: data.maintenance.map((m) => ({ ...m, schemaVersion: 4 })),
    subscriptions: (data.subscriptions ?? []).map((s) => ({ ...s, schemaVersion: 4 })),
    papers: data.papers ?? [],
    settings: data.settings ? { ...data.settings, schemaVersion: 4 } : null,
  }),
};

function migrateBundle(data: BundleData, fromVersion: number): BundleData {
  let out = data;
  for (let v = fromVersion; v < SCHEMA_VERSION; v++) {
    const step = BUNDLE_MIGRATIONS[v];
    if (!step) throw new BundleError(`This backup can't be upgraded from schema v${v}.`);
    out = step(out);
  }
  return out;
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
    [
      db.items,
      db.docs,
      db.blobs,
      db.properties,
      db.rooms,
      db.maintenance,
      db.subscriptions,
      db.papers,
      db.settings,
    ],
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
          db.subscriptions.clear(),
          db.papers.clear(),
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
      await mergeTable(db.subscriptions, data.subscriptions, result, mode);
      await mergeTable(db.papers, data.papers, result, mode);

      // --- settings: take the bundle's preferences, keep this device's
      // entitlements. A restored file can never grant a paid unlock, and it
      // can never turn this phone's lock on or off either — the credential
      // that satisfies it is local.
      if (data.settings && localSettings) {
        await db.settings.put({
          ...data.settings,
          id: 'singleton',
          entitlements: localSettings.entitlements,
          devModeEnabled: localSettings.devModeEnabled,
          biometricLock: localSettings.biometricLock,
          lockCredentialId: localSettings.lockCredentialId,
          pushEnabled: localSettings.pushEnabled,
          pushEndpoint: localSettings.pushEndpoint,
          pushSyncedAt: localSettings.pushSyncedAt,
          pushWakes: localSettings.pushWakes,
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

export type SaveOutcome = 'shared' | 'downloaded' | 'cancelled' | 'needs-gesture';

/**
 * Whether this browser will put the bundle on the share sheet at all.
 *
 * ── Chromium will not, and that is not a bug we can fix ───────────────────
 * Web Share is gated on an ALLOWLIST OF FILE EXTENSIONS, not on the MIME
 * type — images, audio, video, text, and exactly one thing under
 * "Application": pdf. A `.stashit` file is not on it, and neither is `.zip`,
 * so `canShare` returns false on Chrome and Android and there is nothing the
 * page can do about it. Renaming the bundle to a permitted extension would be
 * lying to the OS about what the file is.
 *
 * Safari's implementation is not the Chromium one and does take arbitrary
 * files, which is why this is a probe and not a constant.
 *
 * The probe uses an EMPTY file, because `canShare` inspects the name and the
 * type and never the contents — so the answer is available before spending a
 * second zipping somebody's photo library to find out.
 */
export function canShareBundle(filename = backupFilename()): boolean {
  if (typeof navigator === 'undefined' || typeof navigator.canShare !== 'function') return false;
  try {
    return navigator.canShare({ files: [new File([], filename, { type: 'application/zip' })] });
  } catch {
    return false;
  }
}

/**
 * Hands the file to the OS.
 *
 * The share sheet first, because on a phone it is the only route to somewhere
 * the user can find the file again — Drive, Files, Dropbox, email, whatever
 * they have. It needs no account, no OAuth and no API access to anything: the
 * app hands over one file and the OS does the rest, which is a stronger
 * version of the promise this app already makes than any integration could be.
 *
 * Falls back to a download on desktop and anywhere file sharing is
 * unsupported — that path is not optional, since it is most of the desktop web.
 *
 * ── Cancel is not success ─────────────────────────────────────────────────
 * This returned 'shared' when the user dismissed the sheet, on the reasoning
 * that a cancel is not an error worth reporting. True, and the wrong
 * conclusion: the caller stamped the backup date and told the user the file
 * had been shared. Nothing had been written anywhere. A third outcome costs
 * one line and is the difference between a reminder that works and one that
 * quietly switches itself off.
 *
 * Cancelling does NOT fall through to a download either. Somebody who dismissed
 * the sheet has said no; answering that by silently writing the file to their
 * downloads folder is not what they asked for.
 */
export async function saveBundle(blob: Blob, filename: string): Promise<SaveOutcome> {
  const file = new File([blob], filename, { type: 'application/zip' });

  if (canShareBundle(filename)) {
    try {
      await navigator.share({ files: [file], title: 'Stash it backup' });
      return 'shared';
    } catch (e) {
      const name = (e as DOMException)?.name;
      if (name === 'AbortError') return 'cancelled';

      /*
        `share()` needs TRANSIENT USER ACTIVATION, and zipping a photo library
        takes longer than the window lasts. So the tap that started the backup
        has expired by the time the file exists, and the browser refuses —
        with the same symptom as not supporting sharing at all.

        Not a failure, and not something to answer with a silent download. The
        caller holds the finished bundle and offers a second button; that tap
        arrives with fresh activation and the sheet opens. See the note in the
        Settings backup card.
      */
      if (name === 'NotAllowedError') return 'needs-gesture';

      // Anything else is the share mechanism failing rather than the person
      // declining, so there is still a job to finish. Fall through.
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

/**
 * Records that a backup actually happened.
 *
 * Separate from `exportBundle` on purpose — see the note there. The date on
 * this record silences the reminder, so writing it is a claim that a file
 * exists somewhere, and only the caller who watched it leave can make that
 * claim honestly.
 */
export async function markBackedUp(): Promise<void> {
  await db.settings.update('singleton', { lastBackupAt: nowISO() });
}
