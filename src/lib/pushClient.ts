import { db } from '@/db/db';
import { activeItems, activePapers, activeSubscriptions } from '@/db/repo';
import { isIOSSafari, isStandalone } from '@/lib/install';
import {
  DEFAULT_SEND_HOUR,
  PUSH_CACHE,
  pushSchedule,
  wakeTimes,
  verdict,
  vapidBytes,
  writeNotes,
  type PushVerdict,
  type Wake,
} from '@/lib/push';
import { syncDue, syncPayload, wakesChanged } from '@/lib/pushSync';

/**
 * The browser side of reminders: permission, subscription, and keeping the
 * cached note fresh.
 *
 * Split from lib/push.ts so that file stays pure and testable in Node. Nothing
 * here has logic worth asserting; everything here touches an API that only
 * exists in a browser.
 */

export function pushSupported(): boolean {
  return (
    typeof window !== 'undefined' &&
    'serviceWorker' in navigator &&
    'PushManager' in window &&
    'Notification' in window
  );
}

export function pushVerdict(): PushVerdict {
  return verdict({
    supported: pushSupported(),
    iosBrowser: isIOSSafari(),
    standalone: isStandalone(),
    permission: pushSupported() ? Notification.permission : 'denied',
    hasKey: __VAPID_PUBLIC_KEY__.length > 0,
  });
}

/**
 * Ask, then subscribe.
 *
 * `Notification.requestPermission()` IS CALLED FIRST AND WITH NOTHING AWAITED
 * IN FRONT OF IT. iOS requires the prompt to come straight out of a tap, and
 * an `await` before it spends the gesture — the same class of bug as the share
 * sheet refusing after a long export. Everything that can be prepared later is
 * prepared later.
 */
export async function enablePush(): Promise<PushVerdict | 'on'> {
  const before = pushVerdict();
  if (before !== 'ready') return before;

  const granted = await Notification.requestPermission();
  if (granted !== 'granted') return 'denied';

  const reg = await navigator.serviceWorker.ready;
  const sub =
    (await reg.pushManager.getSubscription()) ??
    (await reg.pushManager.subscribe({
      // Chrome requires it, and it is honest anyway: every push this app sends
      // is meant to be seen. Nothing here wants to run silently in the
      // background — see public/push-handler.js.
      userVisibleOnly: true,
      applicationServerKey: vapidBytes(__VAPID_PUBLIC_KEY__),
    }));

  await db.settings.update('singleton', {
    pushEnabled: true,
    pushEndpoint: sub.endpoint,
  });
  return 'on';
}

/**
 * Off, and gone.
 *
 * The sender is told first and the local subscription dropped second. The
 * other order leaves a row on a server addressed to something the browser has
 * already discarded — reachable by nobody, deletable by nobody, and quietly
 * pinged every time one of its dates comes round until the push service
 * returns a 410 of its own accord.
 */
export async function disablePush(): Promise<void> {
  const settings = await db.settings.get('singleton');
  if (settings?.pushEndpoint) await tellSender('forget', { endpoint: settings.pushEndpoint });

  try {
    const reg = await navigator.serviceWorker.ready;
    const sub = await reg.pushManager.getSubscription();
    await sub?.unsubscribe();
  } catch {
    // A subscription that cannot be reached is one the browser has already
    // discarded. Recording the intent still matters.
  }
  await db.settings.update('singleton', {
    pushEnabled: false,
    pushEndpoint: undefined,
    pushSyncedAt: undefined,
    pushWakes: undefined,
  });
  await clearNotes();
}

/* ------------------------------------------------------------ the sender */

/**
 * Whether there is one at all.
 *
 * With no `__PUSH_ENDPOINT__` the app is exactly what it was before phase 2:
 * the schedule is computed, shown, and never leaves. That is a supported way
 * to run this — a fork with no backend gets a working app, not a broken
 * switch.
 */
export function senderConfigured(): boolean {
  return __PUSH_ENDPOINT__.length > 0;
}

async function tellSender(path: 'register' | 'forget', body: unknown): Promise<boolean> {
  if (!senderConfigured()) return false;
  try {
    const res = await fetch(`${__PUSH_ENDPOINT__}/${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
      // No cookies, no credentials. There is no account here and nothing to
      // carry — sending them would create an identity the design does without.
      credentials: 'omit',
      keepalive: true,
    });
    return res.ok;
  } catch {
    // Offline, or no sender. The schedule is resent on the next attempt; a
    // failed sync must never break the app or lose the local reminder.
    return false;
  }
}

/**
 * Upload the dates, if it is time to and they have changed.
 *
 * TWO GUARDS, and the first is the one that matters. A sender told the moment
 * anything changes can watch you use the app: the times of day, the pattern of
 * an evening spent entering receipts. None of that is in the payload and all
 * of it is in the timing. Weekly flattens it to "this device checked in".
 *
 * The second guard is ordinary politeness — an unchanged list is not worth a
 * request.
 */
export async function syncSchedule(propertyId: string, force = false): Promise<boolean> {
  const settings = await db.settings.get('singleton');
  if (!settings?.pushEnabled || !senderConfigured()) return false;
  if (!force && !syncDue(settings.pushSyncedAt)) return false;

  const reg = await navigator.serviceWorker.ready;
  const sub = await reg.pushManager.getSubscription();
  if (!sub) return false;

  const schedule = await refreshNotes(propertyId);
  const payload = syncPayload(sub.toJSON(), schedule);
  if (!payload) return false;

  if (!force && !wakesChanged(payload.wakes, settings.pushWakes ?? [])) {
    // Nothing new to say. Still count it as a check-in, so an unchanged
    // schedule doesn't retry every launch for a week.
    await db.settings.update('singleton', { pushSyncedAt: new Date().toISOString() });
    return false;
  }

  if (!(await tellSender('register', payload))) return false;

  await db.settings.update('singleton', {
    pushSyncedAt: new Date().toISOString(),
    pushWakes: payload.wakes,
  });
  return true;
}

/** What is on the phone now, for the settings card to show. */
export function plannedWakes(schedule: Wake[]): number[] {
  return wakeTimes(schedule, DEFAULT_SEND_HOUR);
}

/**
 * Rewrite the note the worker will read.
 *
 * Called on every launch, which is what keeps precomputed text honest: the
 * note is only ever as old as your last visit. Cheap — it is the same
 * arithmetic the dashboard does on render.
 */
export async function refreshNotes(propertyId: string): Promise<Wake[]> {
  const settings = await db.settings.get('singleton');
  if (!settings?.pushEnabled) return [];

  const [items, subs, papers] = await Promise.all([
    activeItems(propertyId),
    activeSubscriptions(propertyId),
    activePapers(propertyId),
  ]);

  const schedule = pushSchedule(items, subs, papers);
  if (typeof caches !== 'undefined') {
    await writeNotes(await caches.open(PUSH_CACHE), schedule);
  }
  return schedule;
}

/**
 * The schedule as it stands, whether or not reminders are on.
 *
 * The settings card shows this before you flip the switch — you should be able
 * to read exactly what would be uploaded while deciding whether to upload it,
 * not after.
 */
export async function previewSchedule(propertyId: string): Promise<Wake[]> {
  const [items, subs, papers] = await Promise.all([
    activeItems(propertyId),
    activeSubscriptions(propertyId),
    activePapers(propertyId),
  ]);
  return pushSchedule(items, subs, papers);
}

async function clearNotes(): Promise<void> {
  if (typeof caches === 'undefined') return;
  try {
    await caches.delete(PUSH_CACHE);
  } catch {
    /* nothing to clear */
  }
}
