/**
 * Reading a shared receipt email.
 *
 * When something is shared into the app from a mail client we get, at best, a
 * subject line, a slab of body text and some attachments. This turns that into
 * a filled-in form: who sold it, when, for how much.
 *
 * The rule throughout is that a wrong guess is worse than no guess. A blank
 * field is obviously blank and takes five seconds to fill; a plausible-looking
 * wrong date gets saved, and surfaces years later when someone tries to claim
 * against a warranty that expired two months earlier than the app said. So
 * every extractor here returns undefined rather than its best effort, and
 * ambiguous input is refused outright — see `parseLooseDate` on why numeric
 * dates like 03/04/2026 are dropped on the floor.
 *
 * Pure and string-in, string-out, so all of it is testable in Node.
 */

import type { DocKind } from '@/db/types';

export interface SharedText {
  title?: string;
  text?: string;
  url?: string;
}

export interface ReceiptGuess {
  merchant?: string;
  /** ISO yyyy-mm-dd. */
  purchaseDate?: string;
  totalCents?: number;
  currency?: string;
  orderNumber?: string;
}

/* --------------------------------------------------------------- merchant */

/** Mail clients prefix these; they are never part of the merchant's name. */
const SUBJECT_NOISE =
  /^\s*(re|fwd|fw|forwarded message|tr|aw|wg)\s*:\s*/i;

/**
 * Patterns in the order we trust them. Each captures the merchant in group 1.
 * Ordered most-specific first: "Your receipt from Apple" is a stronger signal
 * than a bare "Apple" appearing somewhere in a subject line.
 */
/*
 * Multiline throughout: the body arrives as lines, and an anchor that means
 * "end of the whole email" would only ever match the last one. "Thanks for
 * your order at Wickes\nDetails below" has to terminate the merchant at the
 * newline, or the capture runs on into the next sentence.
 */
const MERCHANT_PATTERNS: RegExp[] = [
  /\b(?:receipt|invoice|order|purchase|confirmation)\s+from\s+([A-Z0-9][\w.&' -]{1,40}?)(?=[.,!|–—-]|\s+(?:for|on|is|has|dated)\b|\s*$)/im,
  /\byour\s+([A-Z0-9][\w.&' -]{1,40}?)\s+(?:order|receipt|invoice|purchase)\b/im,
  /\bthanks?\s+for\s+(?:your\s+)?(?:order|purchase|shopping)\s+(?:at|with|from)\s+([A-Z0-9][\w.&' -]{1,40}?)(?=[.,!|–—-]|\s*$)/im,
  /^([A-Z0-9][\w.&' -]{1,40}?)\s*[:|–—-]\s*(?:your\s+)?(?:order|receipt|invoice)\b/im,
];

/** Words that mean we matched the sentence, not the shop. */
const NOT_A_MERCHANT = new Set([
  'your', 'our', 'the', 'this', 'that', 'us', 'we', 'me', 'you',
  'order', 'receipt', 'invoice', 'purchase', 'store', 'shop', 'online',
]);

export function guessMerchant(shared: SharedText): string | undefined {
  const subject = (shared.title ?? '').replace(SUBJECT_NOISE, '').trim();
  // The subject is worth far more than the body: it's written to be scanned,
  // and the body is mostly legal boilerplate and shipping addresses.
  for (const source of [subject, firstLines(shared.text, 6)]) {
    if (!source) continue;
    for (const re of MERCHANT_PATTERNS) {
      const m = re.exec(source);
      const name = m?.[1] && tidyMerchant(m[1]);
      if (name && !NOT_A_MERCHANT.has(name.toLowerCase())) return name;
    }
  }

  // Last resort: the domain of a shared link. "order.johnlewis.com" is a good
  // guess at John Lewis, and a bad guess is visible in the form before save.
  return merchantFromUrl(shared.url);
}

function tidyMerchant(raw: string): string {
  const cleaned = raw
    .replace(/\s+/g, ' ')
    .replace(/[\s.,;:!-]+$/, '')
    .replace(/\.(com|co\.uk|net|org|io|shop|store)$/i, '')
    .trim();
  return cleaned.length > 1 && cleaned.length <= 40 ? cleaned : '';
}

function merchantFromUrl(url: string | undefined): string | undefined {
  if (!url) return undefined;
  const m = /^https?:\/\/([^/?#]+)/i.exec(url.trim());
  if (!m) return undefined;
  const parts = m[1]!.toLowerCase().split('.').filter((p) => p !== 'www');
  // Drop the TLD, and the second-level part of things like .co.uk.
  while (parts.length > 1 && /^(com|co|uk|org|net|io|shop|store|de|fr|ca|au)$/.test(parts.at(-1)!)) {
    parts.pop();
  }
  const name = parts.at(-1);
  if (!name || name.length < 2 || NOT_A_MERCHANT.has(name)) return undefined;
  return name.charAt(0).toUpperCase() + name.slice(1);
}

/* ------------------------------------------------------------------ money */

const CURRENCY_SYMBOL: Record<string, string> = {
  $: 'USD', '£': 'GBP', '€': 'EUR', '¥': 'JPY', '₹': 'INR', 'R$': 'BRL',
};

/** Labels that mark the number we actually want, best first. */
const TOTAL_LABELS = [
  /(?:order|grand|invoice)\s+total/i,
  /total\s+(?:charged|paid|due|amount)/i,
  /amount\s+(?:charged|paid|due)/i,
  /\btotal\b/i,
  /\bpaid\b/i,
];

interface Amount {
  cents: number;
  currency?: string;
  index: number;
}

/**
 * The total, not the biggest number. An order email is full of numbers —
 * subtotals, shipping, tax, the price of each line, a promo code — and the
 * largest is as likely to be an order id as a price. So: find the labelled
 * one, and only fall back to "the largest amount" when nothing is labelled.
 */
export function guessTotal(text: string | undefined): { cents: number; currency?: string } | undefined {
  if (!text) return undefined;
  const amounts = findAmounts(text);
  if (amounts.length === 0) return undefined;

  for (const label of TOTAL_LABELS) {
    const m = label.exec(text);
    if (!m) continue;
    // The nearest amount after the label, within a line or so. Receipts put
    // the number to the right of its label, or directly beneath it.
    const from = m.index;
    const near = amounts.find((a) => a.index >= from && a.index - from < 120);
    if (near) return { cents: near.cents, currency: near.currency };
  }

  const largest = amounts.reduce((a, b) => (b.cents > a.cents ? b : a));
  return { cents: largest.cents, currency: largest.currency };
}

const AMOUNT_RE = /(R\$|[$£€¥₹])\s?(\d{1,3}(?:[,.  ]\d{3})*(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?)|(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})\s?(USD|GBP|EUR|CAD|AUD|JPY|INR)\b/g;

function findAmounts(text: string): Amount[] {
  const out: Amount[] = [];
  for (const m of text.matchAll(AMOUNT_RE)) {
    const symbol = m[1];
    const raw = m[2] ?? m[3];
    const code = m[4];
    if (!raw) continue;
    const cents = toCents(raw);
    if (cents === undefined) continue;
    out.push({
      cents,
      currency: code ?? (symbol ? CURRENCY_SYMBOL[symbol] : undefined),
      index: m.index,
    });
  }
  return out;
}

/**
 * "1,234.56" and "1.234,56" are the same money written by different countries.
 * The last separator followed by exactly two digits is the decimal point; the
 * rest are thousands. Same rule as the price field uses, deliberately.
 */
function toCents(raw: string): number | undefined {
  const s = raw.replace(/[  ]/g, '');
  const m = /^(.*?)([.,])(\d{2})$/.exec(s);
  const whole = (m ? m[1]! : s).replace(/[.,]/g, '');
  const frac = m ? m[3]! : '00';
  if (!/^\d+$/.test(whole)) return undefined;
  const cents = Number(whole) * 100 + Number(frac);
  return Number.isSafeInteger(cents) ? cents : undefined;
}

/* ------------------------------------------------------------------ dates */

const MONTHS: Record<string, number> = {
  jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6,
  jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12,
};

const MONTH_NAME = '(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*';

/**
 * A date, but only when it can't be read two ways.
 *
 * 03/04/2026 is the 3rd of April to most of the world and the 4th of March to
 * the United States, and nothing in an email reliably says which. Guessing
 * wrong shifts a warranty expiry by up to eleven months, and the error is
 * invisible until the day it matters — so numeric dates are only accepted when
 * one component is greater than 12 and settles it. Named months are always
 * safe, which is why most receipts use them.
 */
export function parseLooseDate(text: string | undefined, today = new Date()): string | undefined {
  if (!text) return undefined;

  const patterns: { re: RegExp; read: (m: RegExpMatchArray) => [number, number, number] | undefined }[] = [
    // 2026-08-09
    {
      re: /\b(\d{4})-(\d{2})-(\d{2})\b/,
      read: (m) => [Number(m[1]), Number(m[2]), Number(m[3])],
    },
    // 9 August 2026 · 9 Aug 2026
    {
      re: new RegExp(`\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+${MONTH_NAME}\\.?,?\\s+(\\d{4})\\b`, 'i'),
      read: (m) => [Number(m[3]), MONTHS[m[2]!.toLowerCase()]!, Number(m[1])],
    },
    // August 9, 2026 · Aug 9 2026
    {
      re: new RegExp(`\\b${MONTH_NAME}\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4})\\b`, 'i'),
      read: (m) => [Number(m[3]), MONTHS[m[1]!.toLowerCase()]!, Number(m[2])],
    },
    // Numeric, and only when the day is unmistakable.
    {
      re: /\b(\d{1,2})[/.](\d{1,2})[/.](\d{4})\b/,
      read: (m) => {
        const a = Number(m[1]);
        const b = Number(m[2]);
        const year = Number(m[3]);
        if (a > 12 && b <= 12) return [year, b, a]; // 25/08/2026 — day first
        if (b > 12 && a <= 12) return [year, a, b]; // 08/25/2026 — month first
        return undefined; // 03/04/2026 — refuse
      },
    },
  ];

  for (const { re, read } of patterns) {
    const m = re.exec(text);
    if (!m) continue;
    const parts = read(m);
    if (!parts) continue;
    const [y, mo, d] = parts;
    if (!mo || mo < 1 || mo > 12 || d < 1 || d > 31) continue;
    // A receipt is for something already bought. A date in the future is a
    // delivery estimate or a warranty end, and neither is the purchase date.
    const iso = `${y}-${pad(mo)}-${pad(d)}`;
    if (y < 1990 || iso > isoOf(today)) continue;
    return iso;
  }

  return undefined;
}

function pad(n: number): string {
  return String(n).padStart(2, '0');
}

function isoOf(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/* ------------------------------------------------------------ order number */

export function guessOrderNumber(text: string | undefined): string | undefined {
  if (!text) return undefined;
  const m =
    /\border\s*(?:#|no\.?|number|id)?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]{4,24})\b/i.exec(text) ??
    /\b(?:invoice|reference|confirmation)\s*(?:#|no\.?|number)?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]{4,24})\b/i.exec(
      text,
    );
  const id = m?.[1];
  // A run of words isn't a reference. Require at least one digit.
  return id && /\d/.test(id) ? id : undefined;
}

/* ------------------------------------------------------------------- kind */

/**
 * What kind of document this is, from the filename and the subject. Filename
 * first: someone who named a file "extended-warranty.pdf" has told us more
 * than the subject line of the email it arrived in.
 */
export function guessDocKind(filename: string | undefined, shared: SharedText = {}): DocKind {
  // Separators normalised first: "user-guide.pdf" and "user guide.pdf" are the
  // same statement about the file, and only one of them contains "user guide".
  const hay = `${filename ?? ''} ${shared.title ?? ''}`.toLowerCase().replace(/[-_.]+/g, ' ');
  if (/warrant|guarantee|protection plan|cover(age)? plan|service plan/.test(hay)) return 'warranty';
  if (/manual|instruction|user guide|handbook|spec sheet/.test(hay)) return 'manual';
  if (/receipt|invoice|order|purchase|payment|confirmation|billing/.test(hay)) return 'receipt';
  // A shared image with no clue in the name is nearly always a photographed
  // receipt — that's the whole reason someone shares one into this app.
  if (/\.(jpe?g|png|heic|webp)$/i.test(filename ?? '')) return 'receipt';
  return 'receipt';
}

/* ------------------------------------------------------------------ whole */

export function readReceipt(shared: SharedText, today = new Date()): ReceiptGuess {
  // Subject and body together: the date is usually in the body, the merchant
  // in the subject, and the total in either.
  const all = [shared.title, shared.text].filter(Boolean).join('\n');
  const total = guessTotal(all);

  return {
    merchant: guessMerchant(shared),
    purchaseDate: parseLooseDate(all, today),
    totalCents: total?.cents,
    currency: total?.currency,
    orderNumber: guessOrderNumber(all),
  };
}

function firstLines(text: string | undefined, n: number): string {
  if (!text) return '';
  return text.split(/\r?\n/).slice(0, n).join('\n');
}
