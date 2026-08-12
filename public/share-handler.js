/* eslint-disable */
/**
 * The receiving end of the Android share sheet.
 *
 * A share target that accepts files has to be POST/multipart, and a POST needs
 * something to answer it. There is no server here — the app is static files on
 * GitHub Pages — so the service worker answers instead: it intercepts the POST
 * to ./share, parks the payload in Cache Storage, and sends the browser on to
 * the app with a redirect. The page then picks the payload up.
 *
 * Cache Storage rather than IndexedDB deliberately: the worker has to write a
 * Blob and the page has to read it back, and `cache.put` takes a Response with
 * a body without any serialising in between. Opening the app's Dexie database
 * from the worker would mean a second connection and a version-change dance
 * for nothing.
 *
 * This file is imported at the top of the generated Workbox worker, so its
 * fetch listener is registered before Workbox's routing. First listener to
 * call respondWith wins, which is what keeps this working.
 */

const SHARE_CACHE = 'stash-it-share-v1';
const META_KEY = './__share/meta';

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'POST') return;

  const url = new URL(request.url);
  if (!url.pathname.endsWith('/share')) return;

  event.respondWith(receiveShare(request));
});

async function receiveShare(request) {
  const home = new URL('./?shared=1', self.registration.scope).href;

  try {
    const form = await request.formData();
    const cache = await caches.open(SHARE_CACHE);

    // Anything left from a share the user abandoned. Two receipts merged into
    // one item would be worse than losing the first.
    await clearShare(cache);

    const files = form.getAll('files').filter((f) => f && typeof f === 'object' && f.size > 0);
    const meta = {
      at: new Date().toISOString(),
      title: str(form.get('title')),
      text: str(form.get('text')),
      url: str(form.get('url')),
      files: [],
    };

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const key = `./__share/file-${i}`;
      await cache.put(
        key,
        new Response(file, {
          headers: { 'content-type': file.type || 'application/octet-stream' },
        }),
      );
      meta.files.push({
        key,
        name: file.name || `shared-${i}`,
        type: file.type || 'application/octet-stream',
        size: file.size,
      });
    }

    await cache.put(
      META_KEY,
      new Response(JSON.stringify(meta), { headers: { 'content-type': 'application/json' } }),
    );
  } catch (e) {
    // Losing the share is bad; leaving the user staring at a browser error
    // page they can't get out of is worse. Send them into the app either way.
    console.error('[stash-it] share failed', e);
  }

  // 303, so the browser follows with GET and a reload doesn't re-POST.
  return Response.redirect(home, 303);
}

async function clearShare(cache) {
  for (const key of await cache.keys()) await cache.delete(key);
}

function str(v) {
  return typeof v === 'string' && v.trim() ? v : undefined;
}
