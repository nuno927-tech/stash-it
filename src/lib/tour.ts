/**
 * The tour: what it says, and when it's due.
 *
 * A handful of screens, each answering a question someone would otherwise have
 * to discover by poking. The content lives here rather than in the component so
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
 * how to put something in, what to do with the paper it came with, the two
 * other things it tracks, what it tells you back, how it can reach you, and —
 * last, because it's the one that matters when things go wrong — how to make
 * sure you don't lose any of it.
 *
 * The paper step sits third, immediately after adding, because that is the
 * minute the receipt is still in your hand. Told at the end it's advice; told
 * there it's an instruction you can act on.
 *
 * ── Eight, and it was nearly eleven ───────────────────────────────────────
 * Documents, subscriptions and reminders all arrived after this was written,
 * and the obvious move — a screen each, appended — would have made a
 * fourteen-tap introduction to an app whose whole pitch is that it is quick.
 * So two of the originals were folded into their neighbours rather than kept:
 * sharing a receipt from email belongs in the step about adding things, and
 * "what's missing" belongs with the rest of what the dashboard tells you.
 *
 * A tour is a budget. Every screen added has to displace one, or it isn't
 * worth the tap it costs.
 */
export const TOUR_STEPS: TourStep[] = [
  {
    key: 'what',
    pose: 'waving',
    title: 'Everything you own, with its paperwork',
    body: "Warranties, documents and subscriptions in one place — so the receipt is somewhere better than a drawer when a claim needs it, and nothing lapses because you forgot it existed.",
  },
  {
    key: 'add',
    pose: 'receipt',
    title: 'Adding something takes a photo and a date',
    body: 'Name it, photograph it, say when you bought it and how long the warranty runs. Or share a receipt straight from your mail app and the shop, date and price arrive already filled in.',
  },
  {
    key: 'paper',
    pose: 'folder',
    title: 'Then stash the paper too',
    body: "A photo settles most claims. Some still want the original, so keep it in a folder somewhere dry — the app holds the copy, you hold the proof. Paper doesn't need charging.",
  },
  {
    /*
      The privacy sentence is not a footnote here. Anyone being asked to put a
      passport into an app is entitled to know what it will actually hold
      before they start, and the honest answer — dates, no scans, no numbers —
      is also the reason to trust the rest of it.
    */
    key: 'papers',
    pose: 'clipboard',
    title: 'Passports, licenses, insurance',
    body: "The Documents tab watches the things that expire on you. Dates and general details only — no scans, no document numbers — and I'll tell you when to start renewing, not when it's too late.",
  },
  {
    key: 'subs',
    pose: 'calendar',
    title: 'And what leaves your account each month',
    body: 'Add the subscriptions you pay for and the Subscriptions tab shows what a month really costs, which months are the heavy ones, and what renews next.',
  },
  {
    key: 'watch',
    pose: 'report',
    title: 'The dashboard is the short version',
    body: "The ring is how much is still in date, green to red. Under it, one list of everything coming up — ordered by what it costs to ignore, not by date — and a note of anything I'm missing.",
  },
  {
    key: 'notify',
    pose: 'alert',
    title: 'I can nudge you with the app closed',
    body: "Reminders are off until you turn them on. When you do, the only thing that leaves this phone is a delivery address and the days something is due — never what it's about.",
  },
  {
    key: 'safe',
    pose: 'acorn',
    title: 'It all lives on this phone',
    body: 'Nothing is uploaded and there is no account. That keeps it private and puts the backup on you: Back up now in Settings makes one file you can send to Drive, Files, or yourself.',
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
