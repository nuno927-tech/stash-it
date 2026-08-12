/**
 * The app's end of the share target.
 *
 * The service worker (public/share-handler.js) parks whatever Android handed
 * us in Cache Storage and redirects here. This reads it back once, turns it
 * into files the item form already understands, and deletes it — a share is
 * consumed, not kept, and leaving it around means the next launch tries to
 * import the same receipt again.
 */

const SHARE_CACHE = 'stash-it-share-v1';
const META_KEY = './__share/meta';

export interface SharedFileMeta {
  key: string;
  name: string;
  type: string;
  size: number;
}

export interface SharedPayload {
  at: string;
  title?: string;
  text?: string;
  url?: string;
  files: File[];
}

interface StoredMeta {
  at: string;
  title?: string;
  text?: string;
  url?: string;
  files: SharedFileMeta[];
}

/** Set by the worker's redirect. Cheap enough to check before touching caches. */
export function looksLikeShare(search: string): boolean {
  return new URLSearchParams(search).get('shared') === '1';
}

/**
 * Reads and clears the pending share. Returns null when there isn't one —
 * including on a browser with no Cache Storage, where the whole feature is
 * simply absent rather than broken.
 */
export async function takeShare(): Promise<SharedPayload | null> {
  if (typeof caches === 'undefined') return null;

  try {
    const cache = await caches.open(SHARE_CACHE);
    const metaRes = await cache.match(META_KEY);
    if (!metaRes) return null;

    const meta = (await metaRes.json()) as StoredMeta;
    const files: File[] = [];

    for (const f of meta.files ?? []) {
      const res = await cache.match(f.key);
      if (!res) continue;
      files.push(new File([await res.blob()], f.name, { type: f.type }));
    }

    // Read first, delete second. A failure above leaves the payload in place
    // for the next launch rather than throwing it away half-consumed.
    await clear(cache);

    return { at: meta.at, title: meta.title, text: meta.text, url: meta.url, files };
  } catch {
    return null;
  }
}

async function clear(cache: Cache): Promise<void> {
  for (const key of await cache.keys()) await cache.delete(key);
}

/**
 * Strips the marker from the address bar. Without this a reload — or the app
 * being resumed from history — looks like a fresh share and reopens an empty
 * import form.
 */
export function forgetShareMarker(): void {
  if (typeof history === 'undefined' || !looksLikeShare(location.search)) return;
  const url = new URL(location.href);
  url.searchParams.delete('shared');
  history.replaceState(null, '', url.pathname + url.search + url.hash);
}
