/**
 * The developer card is reached by tapping the version pill ten times.
 *
 * It isn't a secret worth keeping — it's that a switch which lifts the item cap
 * has no business being one stray thumb away on someone's settings screen. Ten
 * deliberate taps can't happen by accident, and the convention is old enough
 * that anyone who needs it will guess it.
 *
 * The run resets if you pause: a tap now and a tap tomorrow are two different
 * intentions, and without a gap the counter would quietly accumulate across a
 * week of ordinary use until the card appeared unbidden.
 */
export const TAPS_TO_UNLOCK = 10;
export const TAP_GAP_MS = 1500;

export type TapState = { count: number; last: number };

export const NO_TAPS: TapState = { count: 0, last: 0 };

export function tap(state: TapState, now: number): TapState {
  const stale = now - state.last > TAP_GAP_MS;
  return { count: stale ? 1 : state.count + 1, last: now };
}

export function unlocked(state: TapState): boolean {
  return state.count >= TAPS_TO_UNLOCK;
}

export function tapsLeft(state: TapState): number {
  return Math.max(0, TAPS_TO_UNLOCK - state.count);
}

/**
 * Silence until the tapping is obviously deliberate, then count down. Starting
 * the countdown at ten would announce the thing we just decided to hide.
 */
export function tapHint(state: TapState): string | null {
  const left = tapsLeft(state);
  if (left === 0 || left > 3) return null;
  return left === 1 ? '1 more tap' : `${left} more taps`;
}

/* -------------------------------------------------------- staying unlocked */

/**
 * Once open, it stays open until Hide.
 *
 * The unlock used to live in the Settings component's state, which meant it
 * died the moment you left the screen. That is the wrong shape for what these
 * tools are: testing a notification means leaving Settings, closing the app,
 * waiting for it to arrive, tapping it — and coming back to ten more taps
 * every time turns a five-second check into a chore, which is how a test bench
 * stops being used.
 *
 * `sessionStorage`, not `localStorage`: it survives navigation and reload,
 * which is what was actually being asked for, and clears itself when the tab
 * closes. A developer flag that outlives the browser is one that gets left on.
 * The installed PWA counts as one long-lived tab, so on a phone this behaves
 * like "until you hide it or force-quit".
 *
 * Failure is silent and means locked. Private modes and locked-down browsers
 * throw on storage access, and a hidden developer card is the safe end of that
 * — nothing a person needs is behind here.
 */
const UNLOCK_KEY = 'stash-it-dev-unlocked';

export function readUnlocked(): boolean {
  try {
    return sessionStorage.getItem(UNLOCK_KEY) === '1';
  } catch {
    return false;
  }
}

export function rememberUnlocked(on: boolean): void {
  try {
    if (on) sessionStorage.setItem(UNLOCK_KEY, '1');
    else sessionStorage.removeItem(UNLOCK_KEY);
  } catch {
    /* Nothing to remember it with. The card still works for this screen. */
  }
}
