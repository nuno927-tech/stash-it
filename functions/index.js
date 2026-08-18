/**
 * The sender. Everything the Stash it backend is.
 *
 * Three things: take a delivery address and a list of times, forget one on
 * request, and once an hour send an empty push to whatever is due.
 *
 * ── Read this before changing it ──────────────────────────────────────────
 * The app tells its users, on the settings card, that the only thing leaving
 * their phone is a delivery address and a list of moments — and that the push
 * itself is empty, so nobody in the middle can read a reminder. That claim is
 * true because of this file and nothing else.
 *
 * Three rules keep it true:
 *
 *   1. STORE NOTHING ELSE. No names, no labels, no counts of what kind of
 *      thing is due. If a field arrives that isn't in `clean()`, it is dropped.
 *   2. SEND NOTHING. `webpush.sendNotification` is called with no payload. The
 *      words live on the device; see src/lib/push.ts.
 *   3. STAY SMALL. A privacy claim nobody can check is marketing. If this file
 *      stops being readable in five minutes, the claim has degraded whether or
 *      not the code is still correct.
 *
 * Raw Web Push with our own VAPID pair, NOT the Firebase Cloud Messaging SDK.
 * The app subscribed through `pushManager.subscribe`, so the endpoints are
 * ordinary Web Push URLs — Google's for Chrome, Apple's for Safari, Mozilla's
 * for Firefox. Using FCM's SDK would mean a Google-specific token, would not
 * reach an iPhone the same way, and would tie the app to this host.
 */

import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { defineSecret } from 'firebase-functions/params';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import webpush from 'web-push';
import { createHash } from 'node:crypto';

initializeApp();
const db = getFirestore();

const VAPID_PUBLIC = defineSecret('VAPID_PUBLIC_KEY');
const VAPID_PRIVATE = defineSecret('VAPID_PRIVATE_KEY');

/** Where the app is served from. Anything else is refused at the CORS check. */
const ORIGINS = (process.env.ALLOWED_ORIGINS ?? '').split(',').filter(Boolean);

/**
 * The only hosts a subscription may point at.
 *
 * Without this the endpoint is an arbitrary URL and the function is a free,
 * anonymous HTTP relay that will POST to anywhere on request — which is the
 * kind of thing that gets a project shut down rather than merely abused.
 */
const PUSH_HOSTS = [
  /\.googleapis\.com$/, // Chrome, Edge, Android
  /\.push\.apple\.com$/, // Safari, iOS
  /\.push\.services\.mozilla\.com$/, // Firefox
  /\.notify\.windows\.com$/, // Windows
];

const MAX_WAKES = 40;
const COLLECTION = 'wakes';

/* --------------------------------------------------------------- helpers */

/** Firestore document ids can't be arbitrary URLs, and needn't be readable. */
const idFor = (endpoint) => createHash('sha256').update(endpoint).digest('hex').slice(0, 32);

function allowed(endpoint) {
  try {
    const { protocol, hostname } = new URL(endpoint);
    return protocol === 'https:' && PUSH_HOSTS.some((h) => h.test(hostname));
  } catch {
    return false;
  }
}

/**
 * The whitelist, and it is a whitelist rather than a blacklist on purpose.
 *
 * Anything the client sends that isn't one of these four things never reaches
 * the database. A future version of the app that starts attaching titles to
 * its sync — by accident or otherwise — silently stores nothing extra, and the
 * promise on the settings card survives the mistake.
 */
function clean(body) {
  const endpoint = typeof body?.endpoint === 'string' ? body.endpoint : '';
  const p256dh = typeof body?.keys?.p256dh === 'string' ? body.keys.p256dh : '';
  const auth = typeof body?.keys?.auth === 'string' ? body.keys.auth : '';
  const wakes = Array.isArray(body?.wakes)
    ? body.wakes
        .filter((n) => Number.isInteger(n) && n > 0 && n < 4_102_444_800) // through 2100
        .slice(0, MAX_WAKES)
        .sort((a, b) => a - b)
    : [];

  if (!endpoint || !p256dh || !auth || !allowed(endpoint)) return null;
  return { endpoint, p256dh, auth, wakes };
}

function cors(req, res) {
  const origin = req.headers.origin;
  if (origin && ORIGINS.includes(origin)) res.set('Access-Control-Allow-Origin', origin);
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'content-type');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return true;
  }
  return false;
}

/* ------------------------------------------------------------- endpoints */

export const register = onRequest({ cors: false, maxInstances: 3 }, async (req, res) => {
  if (cors(req, res)) return;
  if (req.method !== 'POST') return void res.status(405).send('');

  const row = clean(req.body);
  if (!row) return void res.status(400).json({ error: 'bad subscription' });

  await db
    .collection(COLLECTION)
    .doc(idFor(row.endpoint))
    .set({
      ...row,
      // The soonest, indexed, so the sweep is one range query — see there.
      nextWake: row.wakes[0] ?? Number.MAX_SAFE_INTEGER,
      updatedAt: FieldValue.serverTimestamp(),
    });

  // No body worth returning, and nothing worth logging.
  res.status(204).send('');
});

export const forget = onRequest({ cors: false, maxInstances: 3 }, async (req, res) => {
  if (cors(req, res)) return;
  if (req.method !== 'POST') return void res.status(405).send('');

  const endpoint = typeof req.body?.endpoint === 'string' ? req.body.endpoint : '';
  if (!endpoint) return void res.status(400).json({ error: 'no endpoint' });

  await db.collection(COLLECTION).doc(idFor(endpoint)).delete();
  res.status(204).send('');
});

/* ----------------------------------------------------------------- sweep */

/**
 * Hourly, because a wake is an instant and the app lets people pick their own
 * morning. Daily would mean everyone hears from us at the same moment UTC,
 * which is the middle of the night for most of them.
 */
export const sweep = onSchedule(
  { schedule: 'every 1 hours', secrets: [VAPID_PUBLIC, VAPID_PRIVATE], maxInstances: 1 },
  async () => {
    webpush.setVapidDetails(
      'mailto:hello@stash-it.app',
      VAPID_PUBLIC.value(),
      VAPID_PRIVATE.value(),
    );

    const now = Math.floor(Date.now() / 1000);

    /*
      A range query on one number, not a match against the array.

      The first version asked `array-contains-any` for every hour boundary in
      the window, which only works if a wake lands exactly on one. A wake is
      9am wherever the user is, and India is +5:30, Nepal +5:45, South
      Australia +9:30 — around a billion and a half people whose 9am is not on
      a UTC hour, and who would therefore never have been sent anything at all.

      `nextWake` is the soonest of the list, kept alongside it, so this is one
      indexed range and nothing is rounded. Anything overdue is picked up on
      the following run, so there is no window to miss.
    */
    const due = await db.collection(COLLECTION).where('nextWake', '<=', now).limit(500).get();

    let sent = 0;
    let dropped = 0;

    for (const doc of due.docs) {
      const { endpoint, p256dh, auth, wakes } = doc.data();
      try {
        // NO PAYLOAD. This is the line the privacy claim rests on.
        await webpush.sendNotification({ endpoint, keys: { p256dh, auth } }, undefined, {
          TTL: 6 * 3600,
        });
        sent++;
      } catch (e) {
        /*
          404 and 410 mean the browser threw the subscription away — uninstalled,
          permission revoked, or simply expired. Keeping it means retrying
          forever against an address that will never answer.
        */
        if (e?.statusCode === 404 || e?.statusCode === 410) {
          await doc.ref.delete();
          dropped++;
          continue;
        }
        // Anything else is transient. Leave it for the next hour.
      }

      // Spent wakes go, so the same date can't fire twice and the list stays
      // short without the device having to prune it.
      const left = wakes.filter((t) => t > now);
      if (left.length === 0) await doc.ref.delete();
      else await doc.ref.update({ wakes: left, nextWake: left[0] });
    }

    // Counts, and only counts. No endpoints, no times, nothing that identifies
    // a device — the logs are part of the surface this promise covers.
    console.log(JSON.stringify({ due: due.size, sent, dropped }));
  },
);

