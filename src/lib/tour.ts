/**
 * The tour: what it says, and when it's due.
 *
 * Six screens, each answering a question someone would otherwise have to
 * discover by poking. The content lives here rather than in the component so
 * it can be read as a script — a tour is writing, and writing that's scattered
 * through JSX stops being editable as prose.
 *
 * The scheduling is the part with a rule in it. "Remind me later" has to mean
 * something specific or it means "never", and "never" is what most apps
 * quietly implement.
 */

import type { ScoutPose } from '@/components/Scout';

export interface TourStep {
  key: string;
  pose: ScoutPose;
  title: string;
  body: string;
}

/**
 * Ordered as a first week with the app, not as a feature list: what it is,
 * how to put something in, what to do with the paper it came with, what it
 * tells you back, what it wants from you, and — last, because it's the one
 * that matters when things go wrong — how to make sure you don't lose it.
 *
 * The paper step sits third, immediately after adding, because that is the
 * minute the receipt is still in your hand. Told at the end it's advice; told
 * there it's an instruction you can act on.
 */
export const TOUR_STEPS: TourStep[] = [
  {
    key: 'what',
    pose: 'waving',
    title: 'Everything you own, with its paperwork',
    body: "Stash it remembers what you bought, when, and how long it's covered — so the receipt is somewhere better than a drawer when a claim needs it.",
  },
  {
    key: 'add',
    pose: 'receipt',
    title: 'Adding something takes a photo and a date',
    body: 'Name it, photograph it, say when you bought it and how long the warranty runs. Everything else is optional and can wait.',
  },
  {
    key: 'paper',
    pose: 'folder',
    title: 'Then stash the paper too',
    body: "A photo settles most claims. Some still want the original, so keep it in a folder somewhere dry — the app holds the copy, you hold the proof. Paper doesn't need charging.",
  },
  {
    key: 'watch',
    pose: 'report',
    title: 'The ring is how much is still covered',
    body: 'Green is covered, amber is ending soon, red has lapsed. Under six months, the countdown switches to days — because that’s when it starts mattering.',
  },
  {
    key: 'gaps',
    pose: 'alert',
    title: "I'll tell you what's missing",
    body: 'A receipt you never attached, a warranty with no length, an item with no photo. The home screen lists them in the order that would cost you most.',
  },
  {
    key: 'share',
    pose: 'receipt',
    title: 'Receipts can come straight from email',
    body: 'Open one in your mail app, share it to Stash it, and the shop, date and price arrive already filled in. Check them — some of it is guessed.',
  },
  {
    key: 'safe',
    pose: 'acorn',
    title: 'It all lives on this phone',
    body: 'Nothing is uploaded anywhere. That keeps it private and puts the backup on you: export a copy, or connect Google Drive, and do it more than once.',
  },
];

/* -------------------------------------------------------------- when */

export const REMIND_DAYS = 3;

export interface TourState {
  /** Set when the tour was finished, or explicitly declined for good. */
  doneAt?: string;
  /** Set by "remind me later". */
  remindAt?: string;
}

/**
 * Whether to offer the tour again.
 *
 * Only ever offered when a reminder was actually asked for and has come due.
 * Someone who took the tour, or who has no reminder pending, is never
 * interrupted — the alternative is an app that periodically decides you'd like
 * to be taught how to use it.
 */
export function tourDue(state: TourState, now = new Date()): boolean {
  if (state.doneAt) return false;
  if (!state.remindAt) return false;
  const at = new Date(state.remindAt).getTime();
  // An unparseable date is treated as due rather than as never: the reminder
  // was requested, and losing it silently is the worse failure.
  if (Number.isNaN(at)) return true;
  return now.getTime() >= at;
}

export function remindLater(now = new Date(), days = REMIND_DAYS): string {
  return new Date(now.getTime() + days * 86_400_000).toISOString();
}

/** Where a step sits in the sequence, for the dots and the button label. */
export function isLastStep(index: number): boolean {
  return index >= TOUR_STEPS.length - 1;
}

export function stepAt(index: number): TourStep {
  const clamped = Math.min(Math.max(index, 0), TOUR_STEPS.length - 1);
  return TOUR_STEPS[clamped]!;
}
