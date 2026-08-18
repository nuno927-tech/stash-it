import type { Item, Paper, Subscription } from '@/db/types';
import { addDays, daysUntilRenewal, nextRenewal, startOfDay } from '@/lib/subscriptions';
import { expiryOf, renewBy } from '@/lib/papers';
import { effectiveExpiry, getEndingSoonDays } from '@/lib/warranty';

/**
 * Reminders that arrive while the app is closed.
 *
 * ── The whole privacy argument, in one sentence ───────────────────────────
 * A server has to know WHEN to wake the phone and WHERE to send the ping. It
 * does not have to know what the reminder says.
 *
 * So the split is: this file works out the dates and the words, on the device,
 * from the same code the dashboard uses. The words are left in Cache Storage
 * for the service worker to read. Only the dates would ever be uploaded, and
 * the push that arrives on the day carries no payload at all — the worker
 * opens the cache and reads what this file wrote.
 *
 * Breach the server and you have a set of push endpoints and a set of dates.
 * Not one item name, price, passport or photograph. The text of a notification
 * never crosses a network in either direction.
 *
 * ── Why the words are precomputed rather than worked out on the day ───────
 * The worker is plain JavaScript imported into the generated Workbox bundle —
 * it cannot import `buildTimeline`, and writing a second copy of the ranking
 * in the worker is how two versions of the truth start. So the page composes
 * the text whenever it runs and parks it in the cache, exactly as the share
 * target parks a payload.
 *
 * The cost is staleness, and it is smaller than it sounds: the note is rewritten
 * on every launch, so it is only ever as old as your last visit to the app. A
 * reminder about something you already dealt with means you dealt with it
 * somewhere other than here, which is a reminder worth getting.
 */

/** One day the phone should be woken, and what to say when it is. */
export interface Wake {
  /** ISO yyyy-mm-dd, local. Day granularity on purpose — see the note above. */
  on: string;
  title: string;
  body: string;
}

/** How far ahead a schedule is worked out. A sync covers this much at a time. */
export const HORIZON_DAYS = 60;

/**
 * Every date in the next `horizon` days on which something starts needing you,
 * with the sentence to show.
 *
 * ── What earns a wake, and what does not ──────────────────────────────────
 * A DOCUMENT wakes you on its renew-by date: the day it stops being "fine" and
 * starts being "start now". Not its expiry — by then the point has gone.
 *
 * A WARRANTY wakes you the day it enters its ending-soon window, which is the
 * same threshold the ring and the list already use. One notification per
 * warranty, at the moment there is still time to act on it.
 *
 * A SUBSCRIPTION wakes you ONLY IF YOU ASKED. A renewal is not an event you
 * need waking for — the money leaves whether you know or not, and nine monthly
 * services would mean nine notifications a month for nothing. `remindDays` is
 * the user saying this one is different.
 */
export function pushSchedule(
  items: Item[],
  subs: Subscription[],
  papers: Paper[],
  now = new Date(),
  horizon = HORIZON_DAYS,
): Wake[] {
  const today = startOfDay(now);
  const last = addDays(today, horizon);
  const byDay = new Map<string, string[]>();

  const add = (when: Date | null, label: string) => {
    if (!when) return;
    const day = startOfDay(when);
    // Today counts — something crossing its threshold this morning is exactly
    // what a reminder is for. Yesterday does not: the moment has gone and the
    // dashboard is already carrying it.
    if (day < today || day > last) return;
    const key = iso(day);
    byDay.set(key, [...(byDay.get(key) ?? []), label]);
  };

  for (const paper of papers) {
    if (!expiryOf(paper)) continue;
    add(renewBy(paper), paper.holder?.trim() ? `${paper.label} — ${paper.holder.trim()}` : paper.label);
  }

  for (const item of items) {
    const end = effectiveExpiry(item, now);
    if (!end) continue;
    // The day the countdown turns amber, not the day the cover ends.
    add(addDays(end, -getEndingSoonDays()), item.name);
  }

  for (const sub of subs) {
    if (!sub.remindDays) continue;
    const at = nextRenewal(sub, now);
    if (!at || daysUntilRenewal(sub, now) === null) continue;
    add(addDays(at, -sub.remindDays), sub.name);
  }

  return [...byDay.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([on, labels]) => ({ on, ...compose(labels) }));
}

/**
 * What the notification says.
 *
 * NAMES, NOT DETAIL. "Passport — Nuno" is enough to know what it's about and
 * costs nothing on a lock screen a stranger can read; "Passport expires 11 Feb,
 * renew now" is the same information broadcast to anyone glancing at the phone
 * on a table. Everything else is one tap away in an app that can ask for a
 * fingerprint first.
 *
 * Two named and the rest counted, because a lock screen truncates and a list of
 * five names truncates to three names and an ellipsis — which is a worse
 * version of saying "and 3 more" on purpose.
 */
export function compose(labels: string[]): { title: string; body: string } {
  const names = [...labels].sort((a, b) => a.localeCompare(b));

  if (names.length === 1) {
    return { title: names[0]!, body: 'Needs a look in Stash it.' };
  }

  const rest = names.length - 2;
  const listed =
    names.length === 2
      ? `${names[0]} and ${names[1]}`
      : `${names[0]}, ${names[1]} and ${rest} more`;

  return { title: `${names.length} things need you`, body: listed };
}

/** The dates alone — the only part of a schedule that would ever be uploaded. */
export function wakeDates(schedule: Wake[]): string[] {
  return schedule.map((w) => w.on);
}

/* ------------------------------------------------------------ the cache */

/**
 * Where the page leaves the notes and the worker picks them up.
 *
 * Cache Storage rather than IndexedDB, for the same reason the share target
 * uses it: the worker gets a `Response` with a body and no serialising dance,
 * and the app's Dexie database is left with exactly one connection. See
 * public/share-handler.js.
 */
export const PUSH_CACHE = 'stash-it-push-v1';
export const NOTES_KEY = './__push/notes';

export interface CacheLike {
  put(key: string, res: Response): Promise<void>;
  match(key: string): Promise<Response | undefined>;
  delete(key: string): Promise<boolean>;
}

export async function writeNotes(cache: CacheLike, schedule: Wake[]): Promise<void> {
  await cache.put(
    NOTES_KEY,
    new Response(JSON.stringify(schedule), { headers: { 'content-type': 'application/json' } }),
  );
}

/** Whatever should be said today, or null on a day with nothing on it. */
export function noteFor(schedule: Wake[], now = new Date()): Wake | null {
  const today = iso(startOfDay(now));
  return schedule.find((w) => w.on === today) ?? null;
}

function iso(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/* --------------------------------------------------------- turning it on */

/**
 * Why the switch can't be flipped, when it can't.
 *
 * `needs-install` is the one worth building UI around. On iOS, web push only
 * exists for a PWA that has been added to the Home Screen — Safari will not
 * offer it from a browser tab, and the permission call has to come straight
 * from a tap with no await in front of it. A toggle that just fails there
 * reads as a broken app rather than as a missing step.
 */
export type PushVerdict = 'ready' | 'unsupported' | 'needs-install' | 'no-key' | 'denied';

export interface PushEnv {
  supported: boolean;
  /** iOS Safari, where installing is a precondition rather than a nicety. */
  iosBrowser: boolean;
  standalone: boolean;
  permission: NotificationPermission;
  hasKey: boolean;
}

export function verdict(env: PushEnv): PushVerdict {
  if (!env.supported) return 'unsupported';
  // Checked before the key: telling an iPhone user to install is useful, and
  // telling them the app is misconfigured is not their problem to solve.
  if (env.iosBrowser && !env.standalone) return 'needs-install';
  if (!env.hasKey) return 'no-key';
  if (env.permission === 'denied') return 'denied';
  return 'ready';
}

/** What the screen says about each of those. */
export const VERDICT_COPY: Record<PushVerdict, string> = {
  ready: '',
  unsupported: "This browser can't do reminders while the app is closed.",
  'needs-install':
    'Add Stash it to your Home Screen first — on iPhone that is the only way a reminder can reach you.',
  'no-key': 'Reminders are not configured in this build.',
  denied:
    'Notifications are blocked for Stash it. Turn them back on in your browser or phone settings, then come back.',
};

/**
 * The VAPID public key, base64url, turned into the bytes `subscribe` wants.
 *
 * Public by definition — it is handed to the browser and forwarded to Google
 * or Apple. The private half never leaves the sender and is not in this repo.
 */
export function vapidBytes(base64Url: string): Uint8Array<ArrayBuffer> {
  const padded = (base64Url + '='.repeat((4 - (base64Url.length % 4)) % 4))
    .replace(/-/g, '+')
    .replace(/_/g, '/');
  const raw = atob(padded);
  // Explicitly over an ArrayBuffer, not the ArrayBufferLike a bare Uint8Array
  // implies — `applicationServerKey` will not take something that might be
  // backed by a SharedArrayBuffer.
  const out = new Uint8Array(new ArrayBuffer(raw.length));
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}
