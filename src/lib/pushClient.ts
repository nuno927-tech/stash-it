import { db } from '@/db/db';
import { activeItems, activePapers, activeSubscriptions } from '@/db/repo';
import { isIOSSafari, isStandalone } from '@/lib/install';
import {
  PUSH_CACHE,
  pushSchedule,
  verdict,
  vapidBytes,
  writeNotes,
  type PushVerdict,
  type Wake,
} from '@/lib/push';

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

/** Off, and gone: the subscription is dropped, not just ignored. */
export async function disablePush(): Promise<void> {
  try {
    const reg = await navigator.serviceWorker.ready;
    const sub = await reg.pushManager.getSubscription();
    await sub?.unsubscribe();
  } catch {
    // A subscription that cannot be reached is one the browser has already
    // discarded. Recording the intent still matters.
  }
  await db.settings.update('singleton', { pushEnabled: false, pushEndpoint: undefined });
  await clearNotes();
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
