/* eslint-disable */
/**
 * Reminders, arriving while the app is closed.
 *
 * ── The push that gets here carries nothing ───────────────────────────────
 * No title, no body, no data. A sender only ever says "wake up" — which means
 * whoever sends it, and whoever relays it, never learns what the reminder is
 * about. The words were written by the page, on this device, and left in Cache
 * Storage; this file's whole job is to read them and show them.
 *
 * That is the privacy design in one file. If a payload ever starts arriving in
 * `event.data`, something has gone wrong upstream and it should not be trusted
 * or displayed — see the note in `show()`.
 *
 * ── Why Cache Storage ─────────────────────────────────────────────────────
 * Same reason the share target uses it: the worker gets a Response with a body
 * and no serialising, and the app's Dexie database keeps exactly one
 * connection. Reaching into IndexedDB from here would mean a second connection
 * and a version-change dance, and reimplementing the timeline ranking in plain
 * JavaScript would mean two versions of the truth. See src/lib/push.ts.
 *
 * Imported at the top of the generated Workbox worker, like share-handler.js.
 */

const PUSH_CACHE = 'stash-it-push-v1';
const NOTES_KEY = './__push/notes';

self.addEventListener('push', (event) => {
  event.waitUntil(show());
});

/**
 * Something must always be shown, and that is not a style choice.
 *
 * Chrome subscribes with `userVisibleOnly` and expects a notification for
 * essentially every push. Stay silent and it eventually posts "this site was
 * updated in the background" on your behalf — and can withdraw the permission
 * for repeat offences. So every branch below ends in a notification, including
 * the one where there turns out to be nothing to say.
 */
async function show() {
  const note = (await readNote()) ?? {
    /*
      Nothing on the schedule for today. The likeliest cause is a good one: the
      thing was dealt with after the schedule was last written, so this is the
      all-clear rather than an error. Saying so is better than the browser's
      own "updated in the background", which tells you nothing at all.
    */
    title: 'Nothing needs you',
    body: 'Whatever this was about has been dealt with.',
  };

  await self.registration.showNotification(note.title, {
    body: note.body,
    icon: './icon-192.png',
    badge: './icon-192.png',
    tag: 'stash-it-reminder',
    // Replaces rather than stacks. Two reminders a day apart are one thing to
    // deal with, not two, and a column of them trains people to swipe.
    renotify: true,
    data: { url: './' },
  });
}

/** Today's note, or null. Never throws — a broken cache must not lose the ping. */
async function readNote() {
  try {
    const cache = await caches.open(PUSH_CACHE);
    const res = await cache.match(NOTES_KEY);
    if (!res) return null;

    const schedule = await res.json();
    if (!Array.isArray(schedule)) return null;

    const now = new Date();
    const today = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
    const hit = schedule.find((w) => w && w.on === today);
    return hit && hit.title ? { title: hit.title, body: hit.body || '' } : null;
  } catch {
    return null;
  }
}

function pad(n) {
  return String(n).padStart(2, '0');
}

/**
 * Tapping it opens the app rather than a new copy of it.
 *
 * An installed PWA that spawns a second window every time a notification is
 * tapped is a PWA with four of itself open by Friday.
 */
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL((event.notification.data && event.notification.data.url) || './', self.registration.scope)
    .href;

  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of windows) {
        // Anything already inside our scope counts — the app may be on any
        // screen, and dragging it back to the dashboard would throw away
        // whatever the person was in the middle of.
        if (client.url.startsWith(self.registration.scope) && 'focus' in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(target);
    })(),
  );
});
