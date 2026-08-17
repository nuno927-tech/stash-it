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

/**
 * True for the names cameras and scanners produce: IMG_20260810_143022,
 * PXL_..., DSC0042, a bare UUID, a run of digits. These tell the user nothing,
 * so they must never become a document's title.
 */
export function isMachineFilename(name: string): boolean {
  const base = name.replace(/\.[^./\\]+$/, '').trim();
  if (!base) return true;
  return (
    /^(img|image|photo|pxl|dsc|dscn|dji|gopr|scan|scanned|screenshot|doc|document|file)[-_ ]?\d*$/i.test(base) ||
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(base) ||
    /^[\d._-]+$/.test(base) ||
    /^[a-z]{2,4}[-_]?\d{4,}/i.test(base)
  );
}

/**
 * A human title from a filename, or empty when the filename is machine noise.
 * "bosch_extended_cover.pdf" is worth keeping; "IMG_20260810_143022.jpg" is
 * not, and the caller falls back to the document's kind.
 */
export function titleFromFilename(filename: string): string {
  if (isMachineFilename(filename)) return '';
  const base = filename.replace(/\.[^./\\]+$/, '').replace(/[_-]+/g, ' ').trim();
  if (!base) return '';
  return base.charAt(0).toUpperCase() + base.slice(1);
}

/**
 * What the row actually shows. The kind leads — "Receipt" answers the question
 * the user is asking — and a real title becomes the second line.
 */
export function docHeadline(doc: Doc): string {
  return DOC_KIND_LABEL[doc.kind];
}

export function docSubtitle(doc: Doc): string | null {
  const title = doc.title?.trim();
  if (!title) return null;
  // Suppress a title that just repeats the kind, and any machine filename
  // that got saved as a title before this rule existed.
  if (title.toLowerCase() === DOC_KIND_LABEL[doc.kind].toLowerCase()) return null;
  if (isMachineFilename(title)) return null;
  return title;
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
    // Falls back to the kind, never to IMG_20260810_143022.
    title: title?.trim() || titleFromFilename(file.name) || DOC_KIND_LABEL[kind],
    storageMode: 'local',
    blobId,
  });
}

/**
 * A document chosen before the item exists.
 *
 * The add form can't call `attachFile` — there's no item id to attach to yet —
 * so files are held here and written once the item is saved. Nothing touches
 * the database until then, which means abandoning the form leaves no orphaned
 * blobs behind.
 */
/**
 * An attachment chosen before the item exists.
 *
 * Either a file or a link, never both. Links used to be the one attachment you
 * couldn't make while adding an item — the dialog wrote straight to the
 * database and there was no row to write against yet — so the control was
 * simply absent from the add form and present on the item page, which read as
 * a bug because it is one.
 */
export interface StagedDoc {
  /** Local id for list keys and removal, not persisted. */
  key: string;
  kind: DocKind;
  file?: File;
  /** Already normalised and validated — see stageLink. */
  url?: string;
  /** Set when one selection produced several files, or by a link's hostname. */
  title?: string;
}

/**
 * What people paste, turned into something storable — or refused.
 *
 * Shared by the two callers so a link staged on the add form is held to
 * exactly the same standard as one attached to an item that already exists.
 * A bare domain is a URL to everyone except `URL()`.
 */
export function parseDocUrl(url: string): URL {
  const trimmed = url.trim();
  if (!trimmed) throw new DocError('Paste a link first.');
  const withScheme = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
  let parsed: URL;
  try {
    parsed = new URL(withScheme);
  } catch {
    throw new DocError("That doesn't look like a web address.");
  }
  if (!parsed.hostname.includes('.')) throw new DocError("That doesn't look like a web address.");
  return parsed;
}

/** The title a link gets when nobody writes one. */
export function linkTitle(parsed: URL): string {
  return parsed.hostname.replace(/^www\./, '');
}

/** A link held until the item it belongs to has been saved. */
export function stageLink(kind: DocKind, url: string, title?: string): StagedDoc {
  const parsed = parseDocUrl(url);
  return { key: newId(), kind, url: parsed.toString(), title: title?.trim() || linkTitle(parsed) };
}

export function stageDoc(kind: DocKind, file: File, title?: string): StagedDoc {
  if (file.size === 0) throw new DocError('That file is empty.');
  if (file.size > MAX_DOC_BYTES) {
    throw new DocError(`That file is ${formatBytes(file.size)}. The limit is 50 MB.`);
  }
  return { key: newId(), kind, file, title };
}

/**
 * Stages a whole selection. Receipts and warranties are routinely several
 * pages, and photographing them one at a time — closing the sheet, reopening
 * it, choosing the kind again — is the kind of friction that stops people
 * bothering. Multi-page picks are numbered so the order survives.
 */
export function stageDocs(kind: DocKind, files: File[], alreadyStaged = 0): StagedDoc[] {
  const multi = files.length + alreadyStaged > 1;
  return files.map((file, i) =>
    stageDoc(kind, file, multi ? `Page ${alreadyStaged + i + 1}` : undefined),
  );
}

/** Writes staged documents against a now-existing item. */
export async function attachStaged(itemId: string, staged: StagedDoc[]): Promise<number> {
  let written = 0;
  for (const s of staged) {
    if (s.url) await attachLink(itemId, s.kind, s.url, s.title);
    else if (s.file) await attachFile(itemId, s.kind, s.file, s.title);
    else continue;
    written++;
  }
  return written;
}

export async function attachLink(
  itemId: string,
  kind: DocKind,
  url: string,
  title?: string,
): Promise<string> {
  const parsed = parseDocUrl(url);

  return createDoc({
    itemId,
    kind,
    title: title?.trim() || linkTitle(parsed),
    storageMode: 'linked',
    url: parsed.toString(),
    linkStatus: 'unchecked',
  });
}

/**
 * Reclassifies a document — a receipt filed as a warranty, usually because the
 * kind chip was still set from the last attachment.
 *
 * The title moves with it when it was only ever the old kind's name. A title
 * the user actually wrote is left alone: renaming "Extended cover certificate"
 * to "Receipt" because the type changed would be destroying their work to
 * satisfy a rule about labels.
 */
export async function changeDocKind(docId: string, kind: DocKind): Promise<void> {
  const doc = await db.docs.get(docId);
  if (!doc || doc.kind === kind) return;

  const wasAutoTitled =
    !doc.title || doc.title.trim().toLowerCase() === DOC_KIND_LABEL[doc.kind].toLowerCase();

  await db.docs.update(docId, {
    kind,
    title: wasAutoTitled ? DOC_KIND_LABEL[kind] : doc.title,
    updatedAt: nowISO(),
  });
}

/**
 * Renames a document.
 *
 * Attaching asks for nothing but the file, so this is where a title gets
 * written when the automatic one isn't good enough. An empty title is stored
 * as the kind rather than as nothing, which is what every other path does and
 * what `docHeadline` expects to find.
 */
export async function renameDoc(docId: string, title: string): Promise<void> {
  const doc = await db.docs.get(docId);
  if (!doc) return;

  const next = title.trim() || DOC_KIND_LABEL[doc.kind];
  if (next === doc.title) return;
  await db.docs.update(docId, { title: next, updatedAt: nowISO() });
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
 * Counts live references from docs and from either size of an item's photo.
 *
 * None of these fields is indexed, so this scans. At the scale of one
 * household's paperwork that costs nothing, and it's a far smaller commitment
 * than a schema migration to add three indexes.
 *
 * Missing a reference here deletes a file someone can still see on screen, so
 * every field that can hold a blob id has to be listed.
 */
export async function isBlobReferenced(blobId: string): Promise<boolean> {
  const docs = await db.docs.filter((d) => !d.deletedAt && d.blobId === blobId).count();
  if (docs > 0) return true;

  const items = await db.items
    .filter((i) => !i.deletedAt && (i.thumbBlobId === blobId || i.photoBlobId === blobId))
    .count();
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
