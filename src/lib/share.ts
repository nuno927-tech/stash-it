/**
 * Sharing the app itself.
 *
 * Three tiers, because the platforms genuinely differ: the native share sheet
 * where it exists, the clipboard where it doesn't, and telling the user the
 * address as a last resort. A share button that silently does nothing on
 * desktop Firefox is worse than no button.
 */

export const SHARE_TITLE = 'Stash it';
export const SHARE_TEXT =
  'Stash it keeps track of warranties, receipts and manuals for everything you own. Everything stays on your own device.';

export type ShareOutcome = 'shared' | 'copied' | 'cancelled' | 'unavailable';

/**
 * Where the app lives, derived rather than hardcoded so it's right in dev, on
 * a project-path deploy, and anywhere it gets moved later.
 */
export function appUrl(): string {
  if (typeof window === 'undefined') return '';
  return new URL(import.meta.env.BASE_URL, window.location.origin).href;
}

export interface ShareDeps {
  share?: (data: { title: string; text: string; url: string }) => Promise<void>;
  copy?: (text: string) => Promise<void>;
}

/** Reads the browser's capabilities, injectable so the fallbacks are testable. */
export function browserShareDeps(): ShareDeps {
  const deps: ShareDeps = {};
  if (typeof navigator !== 'undefined') {
    if (typeof navigator.share === 'function') deps.share = (d) => navigator.share(d);
    if (navigator.clipboard?.writeText) deps.copy = (t) => navigator.clipboard.writeText(t);
  }
  return deps;
}

export async function shareApp(url: string, deps: ShareDeps = browserShareDeps()): Promise<ShareOutcome> {
  if (deps.share) {
    try {
      await deps.share({ title: SHARE_TITLE, text: SHARE_TEXT, url });
      return 'shared';
    } catch (e) {
      // Tapping outside the sheet rejects with AbortError. That's a decision,
      // not a failure, and must not fall through to copying a link the user
      // just declined to send.
      if ((e as DOMException)?.name === 'AbortError') return 'cancelled';
    }
  }

  if (deps.copy) {
    try {
      await deps.copy(url);
      return 'copied';
    } catch {
      return 'unavailable';
    }
  }

  return 'unavailable';
}

export function shareMessage(outcome: ShareOutcome, url: string): string | null {
  switch (outcome) {
    case 'shared':
      return 'Thanks for passing it on.';
    case 'copied':
      return 'Link copied to your clipboard.';
    case 'cancelled':
      return null; // they changed their mind; saying anything is noise
    case 'unavailable':
      return `Share this address: ${url}`;
  }
}
