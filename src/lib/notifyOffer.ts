import type { PushVerdict } from '@/lib/push';

/**
 * Asking, once, whether reminders should arrive as notifications.
 *
 * ── Why it is offered here and not on the settings screen ─────────────────
 * The switch has always existed in Settings, where nobody goes. The moment the
 * feature means anything is the moment someone saves the first thing with a
 * date on it: until then a reminder has nothing to remind them about, and the
 * offer is noise. One second later they have a warranty that runs out in
 * fourteen months and no plan for remembering it.
 *
 * ── Why exactly once ──────────────────────────────────────────────────────
 * A prompt that returns is a prompt that gets dismissed reflexively, and after
 * the second time the dismissal is muscle memory rather than an answer. So the
 * date is written whether they say yes or no, and this never opens again. The
 * switch in Settings is the way back in, for anyone who changes their mind.
 *
 * ── Why "no" is not a failure state ───────────────────────────────────────
 * Everything still works. The dashboard carries the same information the
 * notification would have, and someone who opens the app has no need of a
 * reminder to open the app. Declining costs them nothing, and the copy should
 * not imply otherwise.
 */

export interface OfferInput {
  /** Whether the question has already been put, either way. */
  asked: boolean;
  /** The switch, as the database has it. */
  enabled: boolean;
  /** Whether this browser could actually do it. */
  verdict: PushVerdict;
  /** Whether the thing just saved has a date worth waking someone for. */
  dated: boolean;
}

/**
 * Every reason not to ask, and there are more of them than reasons to.
 *
 * `no-key` and `unsupported` matter most. Asking someone to turn on a feature
 * this build cannot provide gets a yes, then a failure, and teaches them the
 * app is broken — for a switch that was never going to work. `needs-install`
 * is deliberately allowed through: on an iPhone that is a real, followable
 * instruction, and the dialog says so.
 */
export function shouldOffer({ asked, enabled, verdict, dated }: OfferInput): boolean {
  if (asked || enabled || !dated) return false;
  return verdict === 'ready' || verdict === 'needs-install';
}

/**
 * Whether a saved thing is worth waking someone for.
 *
 * A warranty with no purchase date, or a document with no expiry, generates no
 * reminder — so offering notifications on the strength of one would be
 * offering an empty schedule. The check is deliberately the crude one: does it
 * have a date at all. Working out whether that date falls inside the horizon
 * would mean an item bought last week and covered for three years doesn't
 * count, which is exactly backwards — that is the one most worth a reminder,
 * because it is the one nobody will still be thinking about.
 */
export function datedSave(input: { expiresOn?: string; purchaseDate?: string; hasCover: boolean }): boolean {
  if (input.expiresOn?.trim()) return true;
  return !!input.purchaseDate?.trim() && input.hasCover;
}

/* ------------------------------------------------------------- the flag */

/**
 * Armed by the form that just saved, read by the app shell.
 *
 * Module state rather than the database, exactly as the nudge preview works.
 * The offer belongs to this run of the app: an intent that survived a restart
 * would surface days later, attached to nothing the person remembers doing.
 */
let armed = false;

export function armNotifyOffer(): void {
  armed = true;
}

export function notifyOfferArmed(): boolean {
  return armed;
}

export function clearNotifyOffer(): void {
  armed = false;
}
