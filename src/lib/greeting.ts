/**
 * The line at the top of the dashboard.
 *
 * Three windows, not four. "Good night" is a farewell in English, not a
 * greeting, and anything cleverer for the small hours ("Up late?") is a joke
 * that stops being funny the second time someone reads it — and they will read
 * it every day. Evening simply runs long.
 *
 * Pure, and takes its clock as an argument, because the boundaries are the
 * only thing here worth being sure about.
 */

export type DayPart = 'morning' | 'afternoon' | 'evening';

/** 05:00–11:59 · 12:00–17:59 · 18:00–04:59 */
export function dayPart(now: Date = new Date()): DayPart {
  const h = now.getHours();
  if (h >= 5 && h < 12) return 'morning';
  if (h >= 12 && h < 18) return 'afternoon';
  return 'evening';
}

export function greeting(name: string | undefined, now: Date = new Date()): string {
  const hello = `Good ${dayPart(now)}`;
  const who = cleanName(name);
  return who ? `${hello}, ${who}` : hello;
}

/**
 * A name is a display string, not data anything depends on, so this only has
 * to stop it wrecking the layout: collapse whitespace, take the first word,
 * cap the length. Someone who types their full legal name gets called by their
 * first name, which is what the greeting wanted anyway.
 */
export function cleanName(raw: string | undefined): string {
  const trimmed = (raw ?? '').replace(/\s+/g, ' ').trim();
  if (!trimmed) return '';
  const first = trimmed.split(' ')[0]!;
  return first.length > 24 ? first.slice(0, 24) : first;
}

export const MAX_NAME_LENGTH = 32;
