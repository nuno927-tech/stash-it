/**
 * User preferences.
 *
 * These live on the existing settings singleton as optional fields, read
 * through `prefsFrom` so a record written before they existed still answers
 * every question. That's deliberately cheaper than a schema migration: no
 * index changes, and an older build reading a newer record simply ignores what
 * it doesn't recognise.
 */

import { db } from '@/db/db';
import type { Settings } from '@/db/types';

export type ThemeChoice = 'system' | 'light' | 'dark';
export type RoomsView = 'collapsed' | 'expanded';

export interface Prefs {
  theme: ThemeChoice;
  sounds: boolean;
  haptics: boolean;
  /** How the Items list opens: rooms shut, or everything on show. */
  roomsView: RoomsView;
  /** Ask for a fingerprint or face check before the app opens. */
  biometricLock: boolean;
  /** What the greeting calls you. Empty is a valid answer. */
  displayName: string;
}

export const DEFAULT_PREFS: Prefs = {
  theme: 'system',
  /*
    On by default.

    The original reasoning — an app that chirps unasked gets silenced at the OS
    level — is sound for an app that pings at you. It doesn't describe this
    one: the cues are a tick on tap, a short tone on save, and a chime at
    launch, all of them responses to something the user just did. And they're
    already governed by the phone's own switch, since a device on silent plays
    nothing regardless of what's set here.

    Off by default also meant almost nobody heard them. A feature that has to
    be discovered in Settings before it can be experienced is a feature most
    people never know exists.
  */
  sounds: true,
  haptics: true,
  // Collapsed: with a dozen rooms the expanded list is a long scroll, and the
  // question people arrive with is usually "what's in the garage".
  roomsView: 'collapsed',
  // Off until asked for. Switching it on costs an enrolment prompt, and a lock
  // nobody chose is a lock they'll be surprised by at the worst moment.
  biometricLock: false,
  displayName: '',
};

export function prefsFrom(settings: Settings | undefined): Prefs {
  return {
    theme: settings?.theme ?? DEFAULT_PREFS.theme,
    sounds: settings?.sounds ?? DEFAULT_PREFS.sounds,
    haptics: settings?.haptics ?? DEFAULT_PREFS.haptics,
    roomsView: settings?.roomsView ?? DEFAULT_PREFS.roomsView,
    biometricLock: settings?.biometricLock ?? DEFAULT_PREFS.biometricLock,
    displayName: settings?.displayName ?? DEFAULT_PREFS.displayName,
  };
}

export async function setPref<K extends keyof Prefs>(key: K, value: Prefs[K]): Promise<void> {
  // Dexie's UpdateSpec can't see through the generic key, so the patch is
  // built as a partial Settings and narrowed here rather than at the call site.
  const patch: Partial<Settings> = { [key]: value };
  await db.settings.update('singleton', patch);
}

/** Resolves 'system' against the device, for the attribute we actually set. */
export function resolveTheme(choice: ThemeChoice, prefersDark: boolean): 'light' | 'dark' {
  if (choice === 'system') return prefersDark ? 'dark' : 'light';
  return choice;
}

export const REMINDER_CHOICES = [
  { days: 7, label: '1 week' },
  { days: 14, label: '2 weeks' },
  { days: 30, label: '1 month' },
  { days: 60, label: '2 months' },
  { days: 90, label: '3 months' },
];

export const BACKUP_REMINDER_CHOICES = [
  { days: 7, label: 'Weekly' },
  { days: 30, label: 'Monthly' },
  { days: 90, label: 'Quarterly' },
  { days: 0, label: 'Never' },
];

/** The currencies worth putting in a picker; everything else can be typed. */
export const CURRENCIES = [
  'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'NZD', 'JPY', 'INR', 'BRL', 'MXN', 'ZAR', 'CHF', 'SEK',
];
