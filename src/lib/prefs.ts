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
}

export const DEFAULT_PREFS: Prefs = {
  theme: 'system',
  // Off by default. An app that chirps the first time you open it, without
  // being asked, is an app people silence at the OS level and never re-enable.
  sounds: false,
  haptics: true,
  // Collapsed: with a dozen rooms the expanded list is a long scroll, and the
  // question people arrive with is usually "what's in the garage".
  roomsView: 'collapsed',
};

export function prefsFrom(settings: Settings | undefined): Prefs {
  return {
    theme: settings?.theme ?? DEFAULT_PREFS.theme,
    sounds: settings?.sounds ?? DEFAULT_PREFS.sounds,
    haptics: settings?.haptics ?? DEFAULT_PREFS.haptics,
    roomsView: settings?.roomsView ?? DEFAULT_PREFS.roomsView,
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
