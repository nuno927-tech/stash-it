/**
 * Dismissing the launch splash.
 *
 * The splash itself is static markup in index.html — see the comment there for
 * why. This is only the other half: fade it out once the app is actually ready,
 * then take it out of the document so nothing is left overlaying the UI.
 */

/** Long enough to register as a welcome rather than a flicker. */
export const MIN_VISIBLE_MS = 900;
/** Must match the transition in index.html. */
const FADE_MS = 420;

const startedAt = Date.now();

/**
 * @param onReveal Fired at the moment the fade starts — the instant the app
 * becomes the thing on screen. Taking a callback rather than importing the
 * feedback module keeps the splash unaware of sound, and means the caller
 * decides whether an unlock and an ordinary launch sound the same.
 */
export function dismissSplash(onReveal?: () => void): void {
  const el = document.getElementById('splash');
  // Already dismissed. The guard is what makes this safe to call from more
  // than one path, and it's why the callback can't fire twice.
  if (!el) return;

  // The splash may already have been up for a while — a slow first paint, or a
  // database that took its time — so wait only for whatever is left of the
  // minimum, not the full duration again.
  const remaining = Math.max(0, MIN_VISIBLE_MS - (Date.now() - startedAt));

  window.setTimeout(() => {
    el.classList.add('leaving');
    onReveal?.();
    // Removed rather than hidden: an invisible full-screen element that still
    // exists is a bug waiting to happen the first time something forgets
    // pointer-events.
    window.setTimeout(() => el.remove(), FADE_MS);
  }, remaining);
}

/** How long the splash still has to run, for anything that needs to wait. */
export function splashRemainingMs(now = Date.now()): number {
  return Math.max(0, MIN_VISIBLE_MS - (now - startedAt));
}

/**
 * Slides the mark up into the top third and keeps the splash on screen.
 *
 * This is the whole of the lock screen now. There used to be a card that said
 * "Stash it is locked — use your fingerprint or face", which was a screen
 * whose only content was a description of the dialog about to cover it. The
 * splash is already up, already says which app this is, and Android's prompt
 * takes the bottom two thirds — so the honest version is to move our half out
 * of the way and let the platform ask.
 */
export function raiseSplash(): void {
  document.getElementById('splash')?.classList.add('waiting');
}

