/**
 * Tipping the person who made this.
 *
 * Venmo's deep link is the whole integration: there is no API, no SDK and
 * nothing to embed. A URL with a recipient, an amount and a note opens the app
 * with the payment already filled in, and the person confirms it there — which
 * is the right place for it. Nothing about the payment passes through Stash it.
 *
 * ── About "recurring" ─────────────────────────────────────────────────────
 * Venmo cannot schedule a payment from a link. There is no parameter for it
 * and no public way to set one up on someone's behalf, so an app that claims
 * to "make it monthly" is either lying or quietly doing nothing.
 *
 * What can honestly be built is a reminder: the choice is remembered here, and
 * once a month has passed the card says so and offers the button again. The
 * copy says exactly that, because "monthly" implying an automatic charge that
 * never happens is worse than not offering it.
 */

export const VENMO_HANDLE = 'Nuno-Bernardino';

export interface Tier {
  amount: number;
  label: string;
  note: string;
}

/**
 * Four, and the smallest is a real option rather than a decoy. A £1 tier that
 * exists to make £5 look reasonable is a pricing trick; this one is there
 * because "thanks" is a complete thing to want to say.
 */
export const TIERS: Tier[] = [
  { amount: 1, label: 'Just saying thanks', note: 'Thanks for Stash it' },
  { amount: 3, label: 'Buy me a coffee', note: 'Coffee for Stash it' },
  { amount: 5, label: 'Buy me a slice of pizza', note: 'Pizza for Stash it' },
  { amount: 10, label: 'Buy me lunch', note: 'Lunch for Stash it' },
];

/** Roughly a month. Exactness buys nothing for a reminder about a tip. */
export const MONTH_DAYS = 30;

export interface VenmoLink {
  handle?: string;
  amount: number;
  note: string;
  monthly?: boolean;
}

/**
 * The payment URL.
 *
 * `audience=private` on purpose: Venmo defaults to a public feed, and someone
 * tipping a warranty app has not agreed to have that broadcast. The web URL
 * rather than the venmo:// scheme, because it redirects into the app when
 * it's installed and still resolves to something usable when it isn't.
 */
export function venmoUrl({ handle = VENMO_HANDLE, amount, note, monthly }: VenmoLink): string {
  const params = new URLSearchParams({
    txn: 'pay',
    audience: 'private',
    recipients: handle,
    amount: amount.toFixed(2),
    note: monthly ? `${note} (monthly)` : note,
  });
  return `https://venmo.com/?${params.toString()}`;
}

/** Whether the monthly reminder has come due. */
export function monthlyDue(lastAt: string | undefined, now = new Date()): boolean {
  if (!lastAt) return false;
  const at = new Date(lastAt).getTime();
  if (Number.isNaN(at)) return false;
  return now.getTime() - at >= MONTH_DAYS * 86_400_000;
}

/** "£3" in whatever the device calls dollars. Venmo is USD regardless. */
export function money(amount: number): string {
  try {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      maximumFractionDigits: 0,
    }).format(amount);
  } catch {
    return `$${amount}`;
  }
}
