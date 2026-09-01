/// Input formatting for the two fields people type in a shape.
///
/// Translated from `src/lib/format.ts`, with `parseMoneyToCents` pulled in
/// from `addItem.ts` — the formatter and the parser have to agree about what a
/// typed price means, and keeping them in one file is how that stays true.
///
/// Both format **as you type** rather than on blur. Correcting a field after
/// the fact makes people wonder whether they typed it wrong; showing the shape
/// as they go makes the rule obvious without a hint underneath.
///
/// The rule that matters most: **a half-typed value must survive intact.**
/// Formatting that fights the user mid-entry is worse than no formatting.
library;

/* ----------------------------------------------------------------- money */

/// Symbols worth showing. Anything else falls back to the code itself.
const Map<String, String> _symbols = {
  'USD': r'$',
  'CAD': r'$',
  'AUD': r'$',
  'NZD': r'$',
  'MXN': r'$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'INR': '₹',
  'BRL': r'R$',
  'ZAR': 'R',
  'CHF': 'CHF',
  'SEK': 'kr',
};

String currencySymbol(String currency) => _symbols[currency] ?? currency;

/// Currencies with no minor unit — a yen is a whole yen.
const Set<String> _zeroDecimal = {'JPY', 'KRW', 'VND', 'CLP', 'ISK'};

int decimalsFor(String currency) => _zeroDecimal.contains(currency) ? 0 : 2;

final RegExp _notMoney = RegExp(r'[^\d.]');
final RegExp _dots = RegExp(r'\.');
final RegExp _leadingZeros = RegExp(r'^0+(?=\d)');
final RegExp _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');

/// Groups the whole part and holds the decimal the user is midway through
/// typing. "1234.5" becomes "1,234.5", not "1,234.50" — rounding someone's
/// input while their finger is still on the keyboard is maddening.
String formatMoneyInput(String raw, [String currency = 'USD']) {
  final decimals = decimalsFor(currency);
  final cleaned = raw.replaceAll(_notMoney, '');
  if (cleaned.isEmpty) return '';

  // Only the first dot counts; the rest are typos.
  final firstDot = cleaned.indexOf('.');
  final whole = firstDot == -1 ? cleaned : cleaned.substring(0, firstDot);
  var frac = firstDot == -1
      ? ''
      : cleaned.substring(firstDot + 1).replaceAll(_dots, '');

  if (decimals == 0) return _group(whole);
  if (frac.length > decimals) frac = frac.substring(0, decimals);

  final grouped = _group(whole);
  if (firstDot == -1) return grouped;
  return '${grouped.isEmpty ? '0' : grouped}.$frac';
}

/// Leading zeros go, but a lone zero stays — someone may be typing "0.99".
String _group(String digits) =>
    digits.replaceFirst(_leadingZeros, '').replaceAll(_thousands, ',');

/// Pads a half-finished decimal once the user has moved on.
String completeMoneyInput(String raw, [String currency = 'USD']) {
  final decimals = decimalsFor(currency);
  if (raw.trim().isEmpty || decimals == 0) {
    return formatMoneyInput(raw, currency);
  }

  final formatted = formatMoneyInput(raw, currency);
  if (formatted.isEmpty) return '';

  final dot = formatted.indexOf('.');
  final whole = dot == -1 ? formatted : formatted.substring(0, dot);
  final frac = dot == -1 ? '' : formatted.substring(dot + 1);
  return '$whole.${frac.padRight(decimals, '0')}';
}

final RegExp _notMoneyish = RegExp(r'[^\d.,-]');
final RegExp _notDigitOrMinus = RegExp(r'[^\d-]');

/// Money is stored as integer minor units, never a float. Accepts what people
/// actually type: currency symbols, thousands separators, a stray space.
///
/// Both separators are ambiguous across locales — "1.299" is one thousand two
/// hundred and ninety-nine euros in Germany and one pound thirty in the UK. The
/// rule: **the last separator followed by exactly two digits is the decimal
/// point.** Anything else is a thousands separator.
int? parseMoneyToCents(String input) {
  final cleaned = input.replaceAll(_notMoneyish, '').trim();
  if (cleaned.isEmpty) return null;

  final lastSep = [cleaned.lastIndexOf('.'), cleaned.lastIndexOf(',')]
      .reduce((a, b) => a > b ? a : b);

  var whole = cleaned;
  var frac = '';
  if (lastSep != -1 && cleaned.length - lastSep - 1 == 2) {
    whole = cleaned.substring(0, lastSep);
    frac = cleaned.substring(lastSep + 1);
  }

  final digits = whole.replaceAll(_notDigitOrMinus, '');
  if (digits.isEmpty || digits == '-') return null;

  final value = double.tryParse('$digits.${frac.isEmpty ? '0' : frac}');
  if (value == null || !value.isFinite) return null;
  return (value * 100).round();
}

/* ----------------------------------------------------------------- phone */

final RegExp _notPhoneish = RegExp(r'[^\d+\s()-]');
final RegExp _notDigit = RegExp(r'\D');

/// Formats North American numbers, and leaves everything else alone beyond
/// tidying the spacing.
///
/// Guessing at international formats would be worse than not trying: the rules
/// differ per country and the only signal available is digits the user may not
/// have finished typing. A number that keeps the shape it was entered in is
/// still dialable, which is the whole job.
String formatPhoneInput(String raw) {
  // A leading + means the user is being explicit about the country. Respect it.
  if (raw.trim().startsWith('+')) return raw.replaceAll(_notPhoneish, '');

  final digits = raw.replaceAll(_notDigit, '');
  if (digits.isEmpty) return '';

  // 1-800-123-4567: keep the country digit visible, since people read it
  // aloud. Exactly eleven — a longer run is some other country's number, not a
  // North American one with a stray digit, and guessing would mangle it.
  if (digits.length == 11 && digits.startsWith('1')) {
    return '1-${_chunk(digits.substring(1))}';
  }

  if (digits.length > 10) return digits; // not a shape we recognise
  return _chunk(digits);
}

/// 8605551234 → (860) 555-1234, progressively as it is typed.
String _chunk(String digits) {
  if (digits.length <= 3) return digits;
  if (digits.length <= 6) {
    return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
  }
  final last = digits.length < 10 ? digits.length : 10;
  return '(${digits.substring(0, 3)}) '
      '${digits.substring(3, 6)}-${digits.substring(6, last)}';
}

/// Strips formatting back to something a dialer can use.
String phoneHref(String display) {
  final trimmed = display.trim();
  final digits = trimmed.replaceAll(_notDigit, '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}
