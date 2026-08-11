/**
 * Document attachment: receipts, manuals, warranty paperwork.
 *
 * Two storage modes, per the data model. A `local` doc owns a blob on the
 * device; a `linked` doc is only a URL. Linking costs nothing and stays
 * current, but dies when the manufacturer reorganises their site — which is
 * exactly why a warranty PDF belongs on the device, not on a link.
 */

import { db, newId, nowISO } from '@/db/db';
import { createDoc, docsForItem, putBlob } from '@/db/repo';
import type { Doc, DocKind } from '@/db/types';

export const DOC_KINDS: { kind: DocKind; label: string; hint: string }[] = [
  { kind: 'warranty', label: 'Warranty', hint: 'The policy, terms, or extended cover paperwork' },
  { kind: 'receipt', label: 'Receipt', hint: 'Proof of purchase — the thing a claim will ask for' },
  { kind: 'manual', label: 'Manual', hint: 'Instructions, spec sheets, parts diagrams' },
  { kind: 'photo', label: 'Photo', hint: 'Serial plate, damage, installation' },
  { kind: 'other', label: 'Other', hint: 'Anything else worth keeping' },
];

export const DOC_KIND_LABEL: Record<DocKind, string> = {
  warranty: 'Warranty',
  receipt: 'Receipt',
  manual: 'Manual',
  photo: 'Photo',
  other: 'Document',
};

/** What a phone will happily hand over from Files, Photos or a scan. */
export const DOC_ACCEPT = 'image/*,application/pdf,.pdf,.heic,.heif';

export const MAX_DOC_BYTES = 50 * 1024 * 1024;

export class DocError extends Error {}

export function formatBytes(n: number): string {
  if (n < 1024) return `${n} B`;
  const units = ['KB', 'MB', 'GB'];
  let v = n / 1024;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v < 10 ? v.toFixed(1) : Math.round(v)} ${units[i]}`;
}

/** Strips the extension — a title of "receipt.pdf" reads worse than "receipt". */
export function titleFromFilename(filename: string): string {
  const base = filename.replace(/\.[^./\\]+$/, '').replace(/[_-]+/g, ' ').trim();
  if (!base) return '';
  return base.charAt(0).toUpperCase() + base.slice(1);
}

export async function attachFile(
  itemId: string,
  kind: DocKind,
  file: File,
  title?: string,
): Promise<string> {
  if (file.size === 0) throw new DocError('That file is empty.');
  if (file.size > MAX_DOC_BYTES) {
    throw new DocError(`That file is ${formatBytes(file.size)}. The limit is 50 MB.`);
  }

  const blobId = await putBlob(file);
  return createDoc({
    itemId,
    kind,
    title: title?.trim() || titleFromFilename(file.name) || DOC_KIND_LABEL[kind],
    storageMode: 'local',
    blobId,
  });
}

export async function attachLink(
  itemId: string,
  kind: DocKind,
  url: string,
  title?: string,
): Promise<string> {
  const trimmed = url.trim();
  if (!trimmed) throw new DocError('Paste a link first.');

  // Accept what people paste. A bare domain is a URL to everyone except URL().
  const withScheme = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  let parsed: URL;
  try {
    parsed = new URL(withScheme);
  } catch {
    throw new DocError("That doesn't look like a web address.");
  }
  if (!parsed.hostname.includes('.')) throw new DocError("That doesn't look like a web address.");

  return createDoc({
    itemId,
    kind,
    title: title?.trim() || parsed.hostname.replace(/^www\./, ''),
    storageMode: 'linked',
    url: parsed.toString(),
    linkStatus: 'unchecked',
  });
}

/**
 * Soft delete, then drop the blob if nothing else points at it. Blobs are
 * deduped by hash, so the same receipt attached to two items shares one
 * record — deleting one attachment must not take the other's file with it.
 */
export async function deleteDoc(docId: string): Promise<void> {
  const doc = await db.docs.get(docId);
  if (!doc) return;

  await db.docs.update(docId, { deletedAt: nowISO(), updatedAt: nowISO() });
  if (!doc.blobId) return;

  const stillUsed = await isBlobReferenced(doc.blobId);
  if (!stillUsed) await db.blobs.delete(doc.blobId);
}

/**
 * Counts live references from both docs and item thumbnails.
 *
 * Neither `blobId` nor `thumbBlobId` is indexed in schema v1, so this scans.
 * At the scale of one household's paperwork that costs nothing, and it's a far
 * smaller commitment than a schema migration to add two indexes.
 */
export async function isBlobReferenced(blobId: string): Promise<boolean> {
  const docs = await db.docs.filter((d) => !d.deletedAt && d.blobId === blobId).count();
  if (docs > 0) return true;

  const items = await db.items.filter((i) => !i.deletedAt && i.thumbBlobId === blobId).count();
  return items > 0;
}

export interface DocWithFile extends Doc {
  bytes?: number;
  mime?: string;
}

/** Joins each doc to its blob metadata so the list can show size and type. */
export async function docsWithFiles(itemId: string): Promise<DocWithFile[]> {
  const docs = await docsForItem(itemId);
  return Promise.all(
    docs.map(async (d) => {
      if (!d.blobId) return d;
      const blob = await db.blobs.get(d.blobId);
      return { ...d, bytes: blob?.bytes, mime: blob?.mime };
    }),
  );
}

/**
 * Opens a stored document. Images and PDFs both render natively in a tab, so
 * an object URL is enough — no viewer to build, and no way for a malformed
 * file to break the app.
 */
export async function openDoc(doc: Doc): Promise<void> {
  if (doc.storageMode === 'linked' && doc.url) {
    window.open(doc.url, '_blank', 'noopener,noreferrer');
    return;
  }
  if (!doc.blobId) throw new DocError('That document has no file attached.');

  const rec = await db.blobs.get(doc.blobId);
  if (!rec) throw new DocError('That file is missing from this device.');

  const url = URL.createObjectURL(rec.data);
  window.open(url, '_blank', 'noopener,noreferrer');
  // Long enough for the new tab to take ownership of the URL.
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

/** Copies a stored document out to the user's filesystem. */
export async function downloadDoc(doc: Doc): Promise<void> {
  if (!doc.blobId) return;
  const rec = await db.blobs.get(doc.blobId);
  if (!rec) throw new DocError('That file is missing from this device.');

  const ext = rec.mime === 'application/pdf' ? 'pdf' : (rec.mime.split('/')[1] ?? 'bin');
  const url = URL.createObjectURL(rec.data);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${doc.title ?? 'document'}.${ext}`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

/** Used by the tests to build a doc without going through the UI. */
export function draftDoc(itemId: string, kind: DocKind, blobId: string): Doc {
  const ts = nowISO();
  return {
    id: newId(),
    schemaVersion: 1,
    itemId,
    kind,
    storageMode: 'local',
    blobId,
    createdAt: ts,
    updatedAt: ts,
  };
}
