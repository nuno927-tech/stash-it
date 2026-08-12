/**
 * Installing to the home screen.
 *
 * Two very different platforms:
 *
 *  - Chromium fires `beforeinstallprompt`, which can be captured and replayed
 *    later from a button of our own. The event arrives once, early, and only
 *    if the install criteria are met, so it has to be caught at startup rather
 *    than when the prompt is shown.
 *  - iOS Safari has no such event and no API at all. The only route is Share →
 *    Add to Home Screen, so there the honest thing is to show that instruction
 *    rather than a button that can't do anything.
 *
 * Why bother: installing is what earns persistent storage, and persistent
 * storage is what stops the browser evicting a database that only exists here.
 * The prompt is a data-durability feature wearing a marketing hat.
 */

export interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

let deferred: BeforeInstallPromptEvent | null = null;
let onChange: (() => void) | null = null;

/** Called once at startup, before React has had a chance to miss the event. */
export function watchInstallability(notify: () => void): () => void {
  onChange = notify;

  const capture = (e: Event) => {
    // Without this the browser shows its own mini-infobar instead, which is
    // easy to miss and impossible to style.
    e.preventDefault();
    deferred = e as BeforeInstallPromptEvent;
    onChange?.();
  };
  const installed = () => {
    deferred = null;
    onChange?.();
  };

  window.addEventListener('beforeinstallprompt', capture);
  window.addEventListener('appinstalled', installed);

  return () => {
    window.removeEventListener('beforeinstallprompt', capture);
    window.removeEventListener('appinstalled', installed);
    onChange = null;
  };
}

export function isStandalone(): boolean {
  if (typeof window === 'undefined') return false;
  return (
    window.matchMedia?.('(display-mode: standalone)').matches ||
    // iOS predates the media query and still reports it this way.
    (navigator as { standalone?: boolean }).standalone === true
  );
}

export function isIOS(): boolean {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent;
  // iPadOS reports itself as a Mac; the touch points give it away.
  return /iPad|iPhone|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
}

/** Safari is the only iOS browser that can add to the home screen. */
export function isIOSSafari(): boolean {
  if (!isIOS()) return false;
  const ua = navigator.userAgent;
  return !/CriOS|FxiOS|EdgiOS|OPiOS/.test(ua);
}

/**
 * Only Android implements share targets, so it's the only place worth telling
 * someone the app is in their share sheet.
 */
export function isAndroid(): boolean {
  if (typeof navigator === 'undefined') return false;
  return /Android/i.test(navigator.userAgent);
}

export function hasNativePrompt(): boolean {
  return deferred !== null;
}

export async function promptInstall(): Promise<'accepted' | 'dismissed' | 'unavailable'> {
  if (!deferred) return 'unavailable';
  await deferred.prompt();
  const { outcome } = await deferred.userChoice;
  // The event is single-use; a second prompt() throws.
  deferred = null;
  onChange?.();
  return outcome;
}

/* ---------------------------------------------------------------- policy */

export type InstallOffer = 'none' | 'native' | 'ios' | 'manual';

export interface InstallState {
  standalone: boolean;
  nativePrompt: boolean;
  iosSafari: boolean;
  android: boolean;
  /** The browser has had its chance to fire beforeinstallprompt and hasn't. */
  settled: boolean;
}

/**
 * Whether to offer, and in which form.
 *
 * There is no "dismissed" any more, and its absence is the point. The prompt
 * used to write a flag to localStorage on "Not now" and never ask again — but
 * uninstalling a PWA doesn't clear the origin's localStorage, so a single
 * dismissal months ago silenced the prompt permanently, including through a
 * reinstall. The one person who most needs the invitation is the one who
 * hasn't installed yet, and they were the only ones not getting it.
 *
 * So it asks on every launch until the app is actually installed, at which
 * point `standalone` ends it for good. "Not now" closes the sheet for the
 * session, which is all it should ever have meant.
 *
 * Pure, because the combinations matter more than they look.
 */
export function installOffer(state: InstallState): InstallOffer {
  if (state.standalone) return 'none'; // already installed; nothing to offer
  if (state.nativePrompt) return 'native';
  if (state.iosSafari) return 'ios';
  // Chromium fires beforeinstallprompt when it feels like it, and sometimes
  // not at all — a reinstall, a fresh profile, an engagement heuristic. Once
  // it's had its chance, fall back to telling people where the menu item is
  // rather than leaving them with nothing.
  if (state.android && state.settled) return 'manual';
  return 'none';
}
