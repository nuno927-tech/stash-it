/**
 * Writing to whoever makes this.
 *
 * A `mailto:` link, not a form. A form would need somewhere to post to, and
 * this app has no server — the whole point of it. The mail app the user
 * already has is the one piece of infrastructure that's guaranteed to exist,
 * and it has the useful property that they can see exactly what's being sent
 * and delete any of it before it goes.
 *
 * The prefilled body is two blank lines, then one line of context. Version
 * first, because "which build are you on" is the first question every support
 * conversation opens with, and the answer is usually wrong when it comes from
 * memory. Nothing else: no item counts, no room names, no identifiers. The
 * user's own words are the only thing about them in the message.
 */

export const DEVELOPER_EMAIL = 'nuno927@gmail.com';

export type ContactKind = 'question' | 'idea' | 'bug';

const SUBJECT: Record<ContactKind, string> = {
  question: 'Stash it — a question',
  idea: 'Stash it — an idea',
  bug: 'Stash it — something is wrong',
};

/** The line under the cursor, telling the user what the email will open with. */
const OPENER: Record<ContactKind, string> = {
  question: 'Ask away.',
  idea: 'What should it do?',
  bug: 'What happened, and what did you expect instead?',
};

export interface ContactContext {
  version: string;
  /** Running as an installed app rather than a browser tab. */
  standalone: boolean;
  /** Only the platform word, never the full user-agent string. */
  platform?: string;
}

/**
 * The footer. Short enough that nobody minds it, specific enough to save a
 * round trip.
 *
 * Deliberately plain text at the end of the body rather than a hidden header:
 * anything a user can't see before they press send is a thing they didn't
 * agree to send.
 */
export function contextLine(c: ContactContext): string {
  const bits = [`Stash it v${c.version}`, c.standalone ? 'installed' : 'in a browser'];
  if (c.platform) bits.push(c.platform);
  return `— ${bits.join(' · ')}`;
}

export function contactBody(kind: ContactKind, c: ContactContext): string {
  // Two newlines first so the cursor lands above the context, not below it.
  return `\n\n${OPENER[kind]}\n\n${contextLine(c)}`;
}

/**
 * A mailto URL for the given kind.
 *
 * Every part is percent-encoded. A subject with an ampersand in it would
 * otherwise truncate the body at that point, which is the sort of bug that
 * only shows up once someone's email client is stricter than yours.
 */
export function contactUrl(kind: ContactKind, c: ContactContext): string {
  const subject = encodeURIComponent(SUBJECT[kind]);
  const body = encodeURIComponent(contactBody(kind, c));
  return `mailto:${DEVELOPER_EMAIL}?subject=${subject}&body=${body}`;
}

/** The platform word, from the coarse hint browsers are willing to give. */
export function platformWord(ua = navigator.userAgent): string | undefined {
  if (/android/i.test(ua)) return 'Android';
  if (/iphone|ipad|ipod/i.test(ua)) return 'iOS';
  if (/mac os x/i.test(ua)) return 'macOS';
  if (/windows/i.test(ua)) return 'Windows';
  if (/linux/i.test(ua)) return 'Linux';
  return undefined;
}
