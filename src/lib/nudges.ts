/**
 * The app's reminders, and the honest shape of them.
 *
 * There are no push notifications. This app has no server, no account and no
 * background process — nothing exists to wake the phone up and say a warranty
 * is ending. A reminder here is a line that appears on the dashboard the next
 * time you open the app, and calling it anything else would be a promise the
 * architecture can't keep.
 *
 * That's a real limitation, not a temporary one: web push needs a push service
 * subscription and a server holding the keys to send to it. See
 * docs/push-notifications.md.
 *
 * ── Why this file exists ──────────────────────────────────────────────────
 * Two settings were writing to the database and changing nothing anybody could
 * see. "Warn me before a warranty ends" set `reminderOffsetsDays`, which no
 * code read — the ending-soon threshold was a hard-coded constant. "Remind me"
 * set `backupReminderDays`, read in exactly one place: a hint inside the Drive
 * card, which now lives behind the developer tools. So a user could set both
 * and get nothing, forever.
 *
 * The decisions live here as pure functions so they can be tested, and so the
 * developer card can preview each one without waiting a month for it to come
 * true.
 */

import type { Settings } from '@/db/types';

export type NudgeKind = 'backup' | 'warranty' | 'tip';

export interface Nudge {
  kind: NudgeKind;
  title: string;
  body: string;
  /** What the button says. Every nudge has exactly one thing to do about it. */
  action: string;
}

export const DEFAULT_ENDING_SOON_DAYS = 30;

/**
 * The card's class list, namespaced.
 *
 * It used to be `nudge ${kind}`, which for the warranty reminder produced
 * `class="nudge warranty"` — and `.warranty` is the item page's ring block:
 * `display: flex; align-items: center`. So that one card, and only that one,
 * laid its text and its buttons out side by side and pushed them off the edge.
 * The other two were fine, because nothing in the stylesheet is called
 * `.backup` or `.tip`.
 *
 * Bare kind names as CSS classes are a collision waiting for whichever word
 * gets used twice. Prefixed, they can't be.
 */
export function nudgeClass(kind: NudgeKind): string {
  return `nudge nudge-${kind}`;
}

/**
 * How much notice the user asked for before a warranty ends.
 *
 * Clamped rather than trusted: a restored backup written by a future version,
 * or a hand-edited record, must not be able to set the threshold to a million
 * days and paint the whole collection amber.
 */
export function endingSoonDays(settings: Pick<Settings, 'reminderOffsetsDays'> | undefined): number {
  const asked = settings?.reminderOffsetsDays?.[0];
  if (typeof asked !== 'number' || !Number.isFinite(asked)) return DEFAULT_ENDING_SOON_DAYS;
  return Math.max(1, Math.min(365, Math.round(asked)));
}

const DAY = 86_400_000;

function daysSince(iso: string | undefined, now: Date): number | null {
  if (!iso) return null;
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return null;
  return Math.floor((now.getTime() - then) / DAY);
}

/**
 * Time to export again.
 *
 * Suppressed on an empty collection: nagging someone to back up nothing is how
 * a reminder teaches people to ignore reminders. `everyDays === 0` is the user
 * saying never, and must not be read as "every zero days".
 */
export function backupNudge(
  o: { lastBackupAt?: string; everyDays: number; itemCount: number },
  now = new Date(),
): Nudge | null {
  if (o.everyDays <= 0 || o.itemCount === 0) return null;

  const since = daysSince(o.lastBackupAt, now);
  if (since !== null && since < o.everyDays) return null;

  return {
    kind: 'backup',
    title: since === null ? 'No backup yet' : `Last backup was ${since} days ago`,
    body:
      since === null
        ? `Your ${o.itemCount} ${o.itemCount === 1 ? 'item lives' : 'items live'} on this phone and nowhere else. A backup is the only copy that survives losing it.`
        : 'Nothing syncs anywhere, so the file you export is the only copy that survives losing the phone.',
    action: 'Back up now',
  };
}

/**
 * The backup, said on the dashboard whether or not it is overdue.
 *
 * ── Why this is separate from the nudge above ─────────────────────────────
 * `backupNudge` is a warning: it appears when the interval has lapsed and is
 * dismissible, which is correct for a warning and wrong for a fact. Between
 * nudges the dashboard said nothing at all about backups, so the honest
 * reading of a quiet screen was "fine" — and the state it was quietest about
 * was a phone whose only copy of everything was itself.
 *
 * So this never goes away and cannot be dismissed. It is one line, and most of
 * the time it is a reassuring one; the point is that the day it stops being
 * reassuring, nothing has to appear for you to notice.
 *
 * Returns null only when there is nothing to protect. Nagging someone about
 * an empty database is how a reminder teaches people to ignore reminders —
 * the same rule the nudge follows.
 */
export type BackupTone = 'ok' | 'due' | 'never';

export interface BackupStatus {
  /** Days since the last one, or null if there has never been one. */
  days: number | null;
  tone: BackupTone;
  label: string;
}

export function backupStatus(
  o: { lastBackupAt?: string; everyDays: number; itemCount: number },
  now = new Date(),
): BackupStatus | null {
  if (o.itemCount === 0) return null;

  const days = daysSince(o.lastBackupAt, now);
  if (days === null) {
    return { days: null, tone: 'never', label: 'Never backed up' };
  }

  /*
    "Due" follows the interval the user chose, and falls back to a month when
    they chose never. Turning the reminder off is a decision about being
    interrupted, not a claim that a six-month-old backup is current — so the
    line still goes amber, it just never grows into a nudge.
  */
  const every = o.everyDays > 0 ? o.everyDays : 30;
  const tone: BackupTone = days >= every ? 'due' : 'ok';

  const when =
    days === 0 ? 'today' : days === 1 ? 'yesterday' : `${days} days ago`;
  return { days, tone, label: `Backed up ${when}` };
}

/** Warranties inside the window the user asked to be warned about. */
export function warrantyNudge(o: { endingSoon: number; days: number }): Nudge | null {
  if (o.endingSoon === 0) return null;

  const n = o.endingSoon;
  return {
    kind: 'warranty',
    title: `${n} ${n === 1 ? 'warranty ends' : 'warranties end'} within ${o.days} days`,
    body:
      'While cover is still running you can claim, extend, or decide not to bother. After it ends, none of those are on the table.',
    action: n === 1 ? 'See it' : 'See them',
  };
}

/**
 * The tip jar, if it was set to monthly.
 *
 * Venmo can't schedule a payment from a link, so "monthly" was only ever a
 * reminder the app gives itself. This is that reminder.
 */
export function tipNudge(
  o: { monthly: boolean; lastAt?: string },
  now = new Date(),
): Nudge | null {
  if (!o.monthly) return null;

  const since = daysSince(o.lastAt, now);
  if (since !== null && since < 30) return null;

  return {
    kind: 'tip',
    title: 'Your monthly tip is due',
    body: "You asked to be reminded. Ignoring it is a perfectly good answer — nothing changes either way.",
    action: 'Open Venmo',
  };
}

/**
 * Everything worth saying today, in the order it matters.
 *
 * Backup first: it's the only one where waiting can cost you data. The tip is
 * last, because it's the one asking rather than offering.
 */
export function dueNudges(
  o: {
    settings: Settings | undefined;
    itemCount: number;
    endingSoon: number;
  },
  now = new Date(),
): Nudge[] {
  const s = o.settings;
  if (!s) return [];

  return [
    backupNudge(
      { lastBackupAt: s.lastBackupAt, everyDays: s.backupReminderDays, itemCount: o.itemCount },
      now,
    ),
    warrantyNudge({ endingSoon: o.endingSoon, days: endingSoonDays(s) }),
    tipNudge({ monthly: s.donateMonthly ?? false, lastAt: s.donateLastAt }, now),
  ].filter((n): n is Nudge => n !== null);
}

/**
 * Whether the dashboard should draw the samples instead of the real thing.
 *
 * A module-level flag, not a setting and not a database field, because it must
 * not survive anything: not a reload, not a restore, and not walking away from
 * the screen. Armed from the developer card, read once when the dashboard
 * mounts, and cleared when the dashboard is left — see Home.
 *
 * The preview belongs on the dashboard rather than under the button that
 * triggers it. A reminder is a card in a particular place, competing with the
 * greeting and the ring for the same attention; rendered inside a settings
 * card it looks fine and tells you nothing about whether it works there.
 */
let previewArmed = false;

export function armNudgePreview(): void {
  previewArmed = true;
}

export function nudgePreviewArmed(): boolean {
  return previewArmed;
}

export function clearNudgePreview(): void {
  previewArmed = false;
}

/**
 * One of each, forced, for the developer card. Real copy from the real
 * functions — a preview that renders its own sample text is a preview of
 * nothing.
 */
export function sampleNudges(now = new Date()): Nudge[] {
  const longAgo = new Date(now.getTime() - 120 * DAY).toISOString();
  return [
    backupNudge({ lastBackupAt: longAgo, everyDays: 30, itemCount: 12 }, now)!,
    warrantyNudge({ endingSoon: 3, days: 30 })!,
    tipNudge({ monthly: true, lastAt: longAgo }, now)!,
  ];
}
