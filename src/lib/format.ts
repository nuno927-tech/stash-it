/**
 * Input formatting for the two fields people type in a shape.
 *
 * Both format as you type rather than on blur. Correcting a field after the
 * fact makes people wonder whether they typed it wrong; showing the shape as
 * they go makes the rule obvious without a hint underneath.
 */

/* --------------------------------------------------------------- money */

/** Symbols worth showing. Anything else falls back to the code itself. */
const SYMBOLS: Record<string, string> = {
  USD: '$',
  CAD: '$',
  AUD: '$',
  NZD: '$',
  MXN: '$',
  EUR: '€',
  GBP: '£',
  JPY: '¥',
  INR: '₹',
  BRL: 'R$',
  ZAR: 'R',
  CHF: 'CHF',
  SEK: 'kr',
};

export function currencySymbol(currency: string): string {
  return SYMBOLS[currency] ?? currency;
}

/** Currencies with no minor unit — a yen is a whole yen. */
const ZERO_DECIMAL = new Set(['JPY', 'KRW', 'VND', 'CLP', 'ISK']);

export function decimalsFor(currency: string): number {
  return ZERO_DECIMAL.has(currency) ? 0 : 2;
}

/**
 * Groups the whole part and holds the decimal the user is mid-way through
 * typing. "1234.5" becomes "1,234.5", not "1,234.50" — rounding someone's
 * input while their finger is still on the keyboard is maddening.
 */
export function formatMoneyInput(raw: string, currency = 'USD'): string {
  const decimals = decimalsFor(currency);
  const cleaned = raw.replace(/[^\d.]/g, '');
  if (!cleaned) return '';

  // Only the first dot counts; the rest are typos.
  const firstDot = cleaned.indexOf('.');
  const whole = firstDot === -1 ? cleaned : cleaned.slice(0, firstDot);
  let frac = firstDot === -1 ? '' : cleaned.slice(firstDot + 1).replace(/\./g, '');

  if (decimals === 0) return group(whole);
  frac = frac.slice(0, decimals);

  const grouped = group(whole);
  if (firstDot === -1) return grouped;
  return `${grouped || '0'}.${frac}`;
}

function group(digits: string): string {
  const trimmed = digits.replace(/^0+(?=\d)/, '');
  return trimmed.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/** Pads a half-finished decimal once the user has moved on. */
export function completeMoneyInput(raw: string, currency = 'USD'): string {
  const decimals = decimalsFor(currency);
  if (!raw.trim() || decimals === 0) return formatMoneyInput(raw, currency);

  const formatted = formatMoneyInput(raw, currency);
  if (!formatted) return '';

  const [whole, frac = ''] = formatted.split('.');
  return `${whole}.${frac.padEnd(decimals, '0')}`;
}

/* --------------------------------------------------------------- phone */

/**
 * Formats North American numbers, and leaves everything else alone beyond
 * tidying the spacing.
 *
 * Guessing at international formats would be worse than not trying: the rules
 * differ per country and the only signal available is digits the user may not
 * have finished typing. A number that keeps the shape it was entered in is
 * still dialable, which is the whole job.
 */
export function formatPhoneInput(raw: string): string {
  // A leading + means the user is being explicit about the country. Respect it.
  if (raw.trim().startsWith('+')) return raw.replace(/[^\d+\s()-]/g, '');

  const digits = raw.replace(/\D/g, '');
  if (!digits) return '';

  // 1-800-123-4567: keep the country digit visible, since people read it aloud.
  // Exactly eleven — a longer run is some other country's number, not a North
  // American one with a stray digit, and guessing would mangle it.
  if (digits.length === 11 && digits.startsWith('1')) {
    return `1-${chunk(digits.slice(1))}`;
  }

  if (digits.length > 10) return digits; // not a shape we recognise
  return chunk(digits);
}

/** 8605551234 → (860) 555-1234, progressively as it's typed. */
function chunk(digits: string): string {
  if (digits.length <= 3) return digits;
  if (digits.length <= 6) return `(${digits.slice(0, 3)}) ${digits.slice(3)}`;
  return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6, 10)}`;
}

/** Strips formatting back to something `tel:` can dial. */
export function phoneHref(display: string): string {
  const trimmed = display.trim();
  const digits = trimmed.replace(/\D/g, '');
  return trimmed.startsWith('+') ? `+${digits}` : digits;
}
