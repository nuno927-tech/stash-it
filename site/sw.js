/* eslint-disable */
/**
 * A service worker whose only job is to remove itself.
 *
 * The app used to live at /stash-it/ and registered a worker with that scope.
 * The app has moved to /stash-it/app/, and /stash-it/ is now the marketing
 * site — but a registered worker outlives the thing that registered it. Left
 * alone, the old one would keep answering navigations at the root with a
 * cached copy of the app shell, and anyone with the old version installed
 * would see yesterday's app where the website should be.
 *
 * A worker can't be deleted from the server side. It has to be replaced by one
 * that unregisters itself, which is what this is. Chrome checks for a new
 * worker on navigation, finds this, installs it, and it takes itself out.
 *
 * It deletes only the caches it recognises as the old app's. Cache Storage is
 * shared across the whole origin, so wiping everything would take the new
 * app's precache and — worse — the pending share payload with it.
 */

self.addEventListener('install', () => self.skipWaiting());

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      for (const name of await caches.keys()) {
        // Workbox names its precache after the scope it was built for. The old
        // one ends at /stash-it/; the new one carries /stash-it/app/. Anything
        // else — the share cache in particular — is left alone.
        const oldPrecache = name.includes('/stash-it/') && !name.includes('/stash-it/app/');
        if (oldPrecache) await caches.delete(name);
      }

      await self.registration.unregister();

      // Reload whatever is open so it stops being served by a worker that no
      // longer exists. Without this the current tab keeps the old shell until
      // it's closed.
      for (const client of await self.clients.matchAll({ type: 'window' })) {
        client.navigate(client.url).catch(() => {});
      }
    })(),
  );
});

// A fetch handler that does nothing but go to the network. Its presence is
// what makes this a valid worker to install over the old one.
self.addEventListener('fetch', () => {});
