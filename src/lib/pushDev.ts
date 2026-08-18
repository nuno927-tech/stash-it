import { db } from '@/db/db';
import {
  DEFAULT_SEND_HOUR,
  NOTES_KEY,
  PUSH_CACHE,
  noteFor,
  verdict,
  wakeTimes,
  writeNotes,
  type PushVerdict,
  type Wake,
} from '@/lib/push';
import { isIOSSafari, isStandalone } from '@/lib/install';
import { previewSchedule, refreshNotes, senderConfigured } from '@/lib/pushClient';

/**
 * The reminder test bench, behind the developer card.
 *
 * ── Why a notification needs one at all ───────────────────────────────────
 * Every other feature in this app can be checked by looking at it. A reminder
 * cannot: it is supposed to appear on a day you are not thinking about it, on a
 * phone with the app shut, and the honest way to test that is to wait two
 * months and see. Nobody does that, so it ships untested and the first real
 * verdict comes from a passport that expired quietly.
 *
 * So this file takes the chain apart and lets each link be pulled on its own:
 *
 *   1. Can this device show a notification at all?      → notifyNow
 *   2. Does the WORDING read right for a real day?      → stageToday
 *   3. Does the worker find the note and use it?        → stageToday, then ping
 *   4. Does a ping actually cross the internet to here? → pingNow
 *
 * Pulled in that order, a failure tells you which link broke. Testing only the
 * whole chain tells you it doesn't work, which you already suspected.
 *
 * ── The rule these tools live under ───────────────────────────────────────
 * Nothing here may make the app do something in testing that it cannot do in
 * production. There is no debug push that carries text, no way to skip the
 * permission prompt, no bypass of the empty-payload rule. A test bench that
 * exercises a path the real feature doesn't have is a test bench that passes
 * while the feature is broken.
 */

/* ------------------------------------------------------------- diagnosis */

export interface PushDiagnosis {
  /** Why the switch would refuse, if it would. */
  verdict: PushVerdict;
  /** What the settings record thinks. */
  enabled: boolean;
  permission: NotificationPermission | 'unavailable';
  /** A registered, activated service worker — the thing that shows the note. */
  workerReady: boolean;
  /** A live push subscription in this browser, whatever the database says. */
  subscribed: boolean;
  endpoint: string | null;
  senderConfigured: boolean;
  syncedAt: string | null;
  /** How many instants the sender was last told about. */
  uploadedWakes: number;
  /** How many days are in the cache the worker reads. */
  cachedNotes: number;
  /** What a push arriving right now would say, or null for "Nothing needs you". */
  today: Wake | null;
}

/**
 * The whole chain, read rather than assumed.
 *
 * Deliberately checks the browser and the database separately. The interesting
 * failure is exactly when they disagree — the settings record says reminders
 * are on and the browser has no subscription, which happens when a worker is
 * replaced, an installed PWA is reinstalled, or permission is revoked in the OS
 * rather than in the app. That device is registered with the sender, will be
 * pinged on schedule, and cannot show a thing. One row each, so the mismatch is
 * visible instead of averaged into "on".
 */
export async function diagnose(): Promise<PushDiagnosis> {
  const settings = await db.settings.get('singleton');

  const supported =
    typeof navigator !== 'undefined' &&
    'serviceWorker' in navigator &&
    typeof Notification !== 'undefined' &&
    'PushManager' in window;

  const permission = typeof Notification === 'undefined' ? 'unavailable' : Notification.permission;

  let workerReady = false;
  let subscribed = false;
  let endpoint: string | null = null;

  if (supported) {
    try {
      const reg = await navigator.serviceWorker.ready;
      workerReady = !!reg.active;
      const sub = await reg.pushManager.getSubscription();
      subscribed = !!sub;
      endpoint = sub?.endpoint ?? null;
    } catch {
      /* Leave the falses. An unreachable worker is the answer, not an error. */
    }
  }

  return {
    verdict: verdict({
      supported,
      iosBrowser: isIOSSafari(),
      standalone: isStandalone(),
      permission: permission === 'unavailable' ? 'default' : permission,
      hasKey: __VAPID_PUBLIC_KEY__.length > 0,
    }),
    enabled: !!settings?.pushEnabled,
    permission,
    workerReady,
    subscribed,
    endpoint: endpoint ?? settings?.pushEndpoint ?? null,
    senderConfigured: senderConfigured(),
    syncedAt: settings?.pushSyncedAt ?? null,
    uploadedWakes: settings?.pushWakes?.length ?? 0,
    cachedNotes: await countCached(),
    today: noteFor(await readCached()),
  };
}

/* ------------------------------------------------- 1. can it show anything */

export type NotifyOutcome = 'shown' | 'no-permission' | 'no-worker' | 'failed';

/**
 * Show what a push arriving this second would show, without a push.
 *
 * Goes through `registration.showNotification` rather than `new Notification()`
 * on purpose: the constructor is a different code path that iOS does not have
 * at all and that ignores the worker entirely. Testing with it would prove the
 * app can do something it never does.
 *
 * The text is whatever is genuinely in the cache for today, including the
 * "Nothing needs you" fallback — the same branch the worker takes. To see a
 * real-looking reminder, stage one first.
 */
export async function notifyNow(): Promise<NotifyOutcome> {
  if (typeof Notification === 'undefined' || !('serviceWorker' in navigator)) return 'no-worker';
  if (Notification.permission !== 'granted') return 'no-permission';

  try {
    const reg = await navigator.serviceWorker.ready;
    const note = noteFor(await readCached()) ?? {
      on: '',
      title: 'Nothing needs you',
      body: 'Whatever this was about has been dealt with.',
    };

    await reg.showNotification(note.title, {
      body: note.body,
      icon: './icon-192.png',
      badge: './icon-192.png',
      tag: 'stash-it-reminder',
      data: { url: './' },
    });
    return 'shown';
  } catch {
    return 'failed';
  }
}

/* --------------------------------------------------- 2 & 3. the wording */

/**
 * A believable reminder, dated today.
 *
 * Two things named rather than one, because two is where the wording gets
 * interesting — the title becomes a count and the body becomes a list, and that
 * is the version most likely to read badly or truncate on a lock screen.
 */
export function sampleWake(now = new Date()): Wake {
  const on = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  return {
    on,
    title: '2 things need you',
    body: 'MOT — Golf and Passport — Nuno',
  };
}

/**
 * Put a sample on today, leaving the real schedule alone around it.
 *
 * Not a replacement of the cache: the genuine future days stay, and only today
 * is overwritten. That way the thing being tested is one day's wording, and the
 * next launch quietly restores the truth — `refreshNotes` runs on every start,
 * so a staged note cannot outlive the session and be mistaken for a real one.
 */
export async function stageToday(propertyId: string, now = new Date()): Promise<Wake> {
  const sample = sampleWake(now);
  const real = (await previewSchedule(propertyId)).filter((w) => w.on !== sample.on);
  await write([sample, ...real].sort((a, b) => a.on.localeCompare(b.on)));
  return sample;
}

/** Throw the sample away and put the real schedule back. */
export async function restoreSchedule(propertyId: string): Promise<number> {
  return (await refreshNotes(propertyId)).length;
}

/* ------------------------------------------------------ 4. the real thing */

export type PingOutcome =
  | 'sent'
  | 'no-sender'
  | 'not-subscribed'
  | 'not-registered'
  | 'expired'
  | 'too-soon'
  | 'failed';

export const PING_COPY: Record<PingOutcome, string> = {
  sent: 'Ping sent. Close the app — it should arrive within a few seconds.',
  'no-sender': 'No sender in this build, so there is nothing to ping from.',
  'not-subscribed': 'This browser has no push subscription. Turn Reminders on first.',
  'not-registered':
    'The sender has never heard of this device. Turn Reminders off and on again to re-register.',
  expired: 'This subscription is dead and has been dropped. Turn Reminders off and on again.',
  'too-soon': 'Wait ten seconds between pings.',
  failed: "Couldn't reach the sender. Check the endpoint and your connection.",
};

/**
 * Ask the sender to push this device, right now.
 *
 * The only test that exercises the full path — sender, then Google or Apple,
 * then the worker on a phone that may be asleep. Everything above it is a
 * rehearsal of one link.
 *
 * Worth closing the app before pressing it. A notification while the page is in
 * the foreground is shown by a slightly different route on some platforms, so a
 * foreground test can pass on a device where the real thing never appears.
 */
export async function pingNow(): Promise<PingOutcome> {
  if (!senderConfigured()) return 'no-sender';

  let endpoint: string | undefined;
  try {
    const reg = await navigator.serviceWorker.ready;
    endpoint = (await reg.pushManager.getSubscription())?.endpoint;
  } catch {
    return 'not-subscribed';
  }
  if (!endpoint) return 'not-subscribed';

  try {
    const res = await fetch(`${__PUSH_ENDPOINT__}/ping`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ endpoint }),
      credentials: 'omit',
    });
    return pingVerdict(res.status);
  } catch {
    return 'failed';
  }
}

/** What the sender's status code means, kept out of the fetch so it can be tested. */
export function pingVerdict(status: number): PingOutcome {
  if (status === 204) return 'sent';
  if (status === 404) return 'not-registered';
  if (status === 410) return 'expired';
  if (status === 429) return 'too-soon';
  return 'failed';
}

/* ----------------------------------------------------------------- cache */

async function readCached(): Promise<Wake[]> {
  if (typeof caches === 'undefined') return [];
  try {
    const res = await (await caches.open(PUSH_CACHE)).match(NOTES_KEY);
    const parsed = res ? await res.json() : null;
    return Array.isArray(parsed) ? (parsed as Wake[]) : [];
  } catch {
    return [];
  }
}

async function countCached(): Promise<number> {
  return (await readCached()).length;
}

async function write(schedule: Wake[]): Promise<void> {
  if (typeof caches === 'undefined') return;
  await writeNotes(await caches.open(PUSH_CACHE), schedule);
}

function pad(n: number): string {
  return String(n).padStart(2, '0');
}

/** The instants a staged or real schedule would upload, for showing alongside. */
export function instantsFor(schedule: Wake[]): number[] {
  return wakeTimes(schedule, DEFAULT_SEND_HOUR);
}
