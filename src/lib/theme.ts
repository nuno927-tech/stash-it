import { resolveTheme, type ThemeChoice } from './prefs';

/**
 * Applies the theme to <html> and keeps the browser chrome in step.
 *
 * The theme-color meta tag is updated alongside the attribute, because on
 * Android the status bar takes its colour from it — leave it dark and a light
 * theme gets a black notch bar sitting above a white app.
 */

const DARK_QUERY = '(prefers-color-scheme: dark)';

export function prefersDark(): boolean {
  if (typeof window === 'undefined' || !window.matchMedia) return true;
  return window.matchMedia(DARK_QUERY).matches;
}

const CHROME_COLOR = { dark: '#0D0F12', light: '#F4F2ED' };

export function applyTheme(choice: ThemeChoice): 'light' | 'dark' {
  const resolved = resolveTheme(choice, prefersDark());
  document.documentElement.dataset.theme = resolved;

  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute('content', CHROME_COLOR[resolved]);

  return resolved;
}

/**
 * Watches the device setting so "match my device" follows it live — someone
 * whose phone flips to dark at sunset shouldn't have to reopen the app.
 * Returns an unsubscribe.
 */
export function watchSystemTheme(onChange: () => void): () => void {
  if (typeof window === 'undefined' || !window.matchMedia) return () => {};
  const mq = window.matchMedia(DARK_QUERY);
  mq.addEventListener('change', onChange);
  return () => mq.removeEventListener('change', onChange);
}
