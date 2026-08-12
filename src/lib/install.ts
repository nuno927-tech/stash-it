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

const DISMISSED_KEY = 'stash-it:install-dismissed';

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

export function wasDismissed(): boolean {
  try {
    return localStorage.getItem(DISMISSED_KEY) !== null;
  } catch {
    return false;
  }
}

export function rememberDismissal(): void {
  try {
    localStorage.setItem(DISMISSED_KEY, new Date().toISOString());
  } catch {
    // Private mode. Worst case the prompt appears again next launch.
  }
}

export function forgetDismissal(): void {
  try {
    localStorage.removeItem(DISMISSED_KEY);
  } catch {
    /* nothing to do */
  }
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

export type InstallOffer = 'none' | 'native' | 'ios';

export interface InstallState {
  standalone: boolean;
  dismissed: boolean;
  nativePrompt: boolean;
  iosSafari: boolean;
}

/**
 * Whether to offer, and in which form. Pure so the rules can be tested — the
 * combinations matter more than they look, and getting one wrong means either
 * nagging someone who already installed or hiding it from someone who can't
 * discover it any other way.
 */
export function installOffer(state: InstallState): InstallOffer {
  if (state.standalone) return 'none'; // already installed
  if (state.dismissed) return 'none';
  if (state.nativePrompt) return 'native';
  if (state.iosSafari) return 'ios';
  return 'none';
}

/** Settings shows the option even after a dismissal — just not on its own. */
export function installOfferIgnoringDismissal(state: InstallState): InstallOffer {
  return installOffer({ ...state, dismissed: false });
}
