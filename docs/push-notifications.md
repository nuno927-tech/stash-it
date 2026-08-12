# Push notifications for expiring warranties

What it takes, in three tiers of increasing cost. Written August 2026.

## The problem in one line

A warranty warning you only see when you happen to open the app is worth
almost nothing — the whole point is to hear about it *before* you'd have
thought to look.

## The dead end, first

The obvious solution doesn't exist. The **Notification Triggers API**
(`showTrigger` with a `TimestampTrigger`) would have let the app schedule a
notification for a future date with no server at all. It ran as a Chrome origin
trial and **Google discontinued it**. There is no replacement. Anything that
fires at a specific future time now needs either a background wake-up or a
server.

---

## Tier 0 — Periodic Background Sync

**No server. No data leaves the device. Works on your phone today.**

Chromium wakes an installed PWA's service worker on a schedule. The worker
opens IndexedDB, checks what's expiring, and shows a notification locally. The
app is both the scheduler and the sender.

### What you'd build

1. **`periodicsync` registration** — after install, request the permission and
   `registration.periodicSync.register('warranty-check', { minInterval: 24h })`.
2. **A `periodicsync` handler in the service worker.** The current worker is
   Workbox's generated one; this goes in `share-handler.js` alongside the share
   listener, or a second imported script.
3. **A shared expiry check the worker can run.** `warrantyState` and
   `effectiveExpiry` are already pure and already tested — but they currently
   ship inside the app bundle. The worker needs its own copy, so this logic
   moves to a module both can import.
4. **Dexie in the worker.** It works in a service worker context, but the
   worker holds its own connection — worth confirming against the version
   upgrade path.
5. **A `lastNotifiedAt` per item**, so the same warranty doesn't announce
   itself every single day for a month.
6. **`notificationclick`** → focus or open the app at that item.

### What it costs you

Nothing, and about **two days**.

### What's wrong with it

- **Chromium only.** No Firefox, no Safari, so nothing on iPhone.
- **Installed PWAs only.** A browser tab gets nothing.
- **Engagement-gated and not guaranteed.** Chrome decides how often it fires
  from a site-engagement score, and if that score is zero it never fires at
  all. Minimum interval is around 12 hours in practice, but "around" is doing
  real work in that sentence — this is best-effort, and a user who stops
  opening the app is exactly the user who stops getting reminders.

That last point is the killer in principle: reminders degrade precisely for the
people who need them most. In practice, for one person on Android who opens the
app regularly, it works.

---

## Tier 1 — Web Push, with a server that knows nothing

**A real backend, but a deliberately ignorant one.**

The insight that makes this compatible with the app's privacy claim: a push
server needs to know **when** to ping and **where** to send it. It never needs
to know **what** the notification says.

So the payload is empty. The push arrives, the service worker wakes, reads the
*local* IndexedDB, works out that it's the Bosch dishwasher with 30 days left,
and composes the notification on the device. The server never learns a single
thing anyone owns.

### What the server stores, per user

```
endpoint     https://fcm.googleapis.com/...   (an opaque URL, no identity)
keys         p256dh, auth                     (for encryption)
dates        [2026-09-14, 2026-11-02, ...]    (timestamps only, no names)
```

No account, no email, no item data. If the whole database leaked, the finding
would be "these anonymous browsers have something expiring in November".

### What you'd build

**On the client**

1. **VAPID key pair.** Public key ships in the app; private key lives with the
   scheduler.
2. **A permission request at the right moment** — after someone adds an item
   with a warranty, not on first load. A cold permission prompt gets denied,
   and denial in a browser is close to permanent.
3. **`pushManager.subscribe()`**, then POST the subscription plus the sorted
   list of upcoming expiry dates.
4. **Re-post the dates whenever items change**, debounced. This is the fiddly
   part — it's a sync problem wearing a small hat.
5. **A `push` handler in the service worker**: read IndexedDB, find what's due,
   `showNotification`.
6. **`notificationclick`** → deep-link to the item.

**On the server**

7. **A store.** Cloudflare KV, D1, or Firestore. It holds one small record per
   subscription.
8. **Two endpoints**: subscribe, and unsubscribe.
9. **A daily cron** that finds today's dates and sends. `web-push` on Node, or
   the raw VAPID signing if you'd rather not take the dependency.
10. **Prune dead subscriptions.** A `410 Gone` from the push service means the
    user uninstalled; delete the row or you'll be sending into the void
    forever.

### Where to run it

| | Cost | Notes |
| --- | --- | --- |
| **Cloudflare Workers + D1** | Free tier covers this comfortably | Cron triggers built in. My pick. |
| **GitHub Actions cron** | Free | You already deploy from here. Scheduled runs are unreliable by minutes-to-hours under load, which is fine for a daily warranty check. Needs somewhere to keep the subscriptions. |
| **Firebase Functions + Firestore** | Free at this size | Heaviest option; only worth it if you're going to Firebase anyway. |

### The one constraint to design around

Browsers require that a push **results in a visible notification**. Chrome
allows a small budget of silent pushes and then starts showing its own generic
"This site has been updated in the background" message — which looks broken.

This is exactly why the server stores dates rather than pinging everyone
weekly and letting each device decide. Ping only when there is definitely
something to say.

### What it costs you

**Roughly a week**, and effectively $0/month at any scale this app will see.
Plus: a server you now maintain, a privacy policy that has to mention it, and
subscription records that are personal data under GDPR even though they contain
no name.

### iPhone

Web Push works in Safari 16.4+ **only for PWAs added to the home screen**, and
the permission must be requested from a user gesture. So iOS gets notifications
under Tier 1 — but only after an install step that iOS makes deliberately
obscure.

---

## Tier 2 — Full backend

Only worth describing to rule it out: if there were already accounts and
server-side data (see `accounts-and-firebase.md`), the scheduler would just
query the items table directly and put the item name in the payload. Simpler
code, and it throws away the property that makes Tier 1 attractive. Don't build
a backend *for* notifications; add notifications to a backend you built for
other reasons.

---

## What I'd do

**Tier 0 first**, as a spike. It's two days, it's reversible, and it will tell
you something no amount of planning will: whether Chrome actually fires the
sync often enough to be useful on a real phone with real usage. If it does,
that may be the whole feature for an Android user.

Then **Tier 1 when there's a second user**, because Tier 0's failure mode —
silently not firing for the disengaged — is acceptable when you're the only
person relying on it and not otherwise.

Either way, the first commit is the same and neither tier wastes it: **move the
expiry logic into a module the service worker can import, and give items a
`lastNotifiedAt`.** That's the shared foundation, it's testable on its own, and
it's useful even if notifications never ship.

### Before any of it

Get the copy right, because a notification people dismiss without reading is
worse than none. "Bosch dishwasher — 30 days of cover left" is a reminder.
"You have 1 expiring warranty" is spam, and it teaches people to swipe.

---

## Sources

- [Notification Triggers API — discontinued](https://developer.chrome.com/docs/web-platform/notification-triggers)
- [Periodic Background Sync API](https://developer.chrome.com/docs/capabilities/periodic-background-sync)
- [Background sync in Edge/Chromium](https://learn.microsoft.com/en-us/microsoft-edge/progressive-web-apps/how-to/background-syncs)
- [Background sync browser support](https://www.testmuai.com/learning-hub/background-sync-browser-support/)
