/// Reading a shared receipt email.
///
/// Translated from `src/lib/receipt.ts`.
///
/// When something is shared into the app from a mail client we get, at best, a
/// subject line, a slab of body text and some attachments. This turns that into
/// a filled-in form: who sold it, when, for how much.
///
/// ── The rule the whole file is built on ───────────────────────────────────
/// **A wrong guess is worse than no guess.** A blank field is obviously blank
/// and takes five seconds to fill; a plausible-looking wrong date gets saved,
/// and surfaces years later when someone tries to claim against a warranty that
/// expired two months earlier than the app said.
///
/// So every extractor returns null rather than its best effort, and ambiguous
/// input is refused outright — see `parseLooseDate` on why numeric dates like
/// 03/04/2026 are dropped on the floor.
library;

import '../models/types.dart';

class SharedText {
  const SharedText({this.title, this.text, this.url});
  final String? title;
  final String? text;
  final String? url;
}

class ReceiptGuess {
  const ReceiptGuess({
    this.merchant,
    this.purchaseDate,
    this.totalCents,
    this.currency,
    this.orderNumber,
  });

  final String? merchant;

  /// `YYYY-MM-DD`.
  final String? purchaseDate;

  final int? totalCents;
  final String? currency;
  final String? orderNumber;
}

/* ------------------------------------------------------------- merchant */

/// Mail clients prefix these; they are never part of the merchant's name.
final RegExp _subjectNoise =
    RegExp(r'^\s*(re|fwd|fw|forwarded message|tr|aw|wg)\s*:\s*', caseSensitive: false);

/// Patterns in the order we trust them. Each captures the merchant in group 1.
/// Ordered most-specific first: "Your receipt from Apple" is a stronger signal
/// than a bare "Apple" appearing somewhere in a subject line.
///
/// **Multiline throughout**: the body arrives as lines, and an anchor meaning
/// "end of the whole email" would only ever match the last one. "Thanks for
/// your order at Wickes\nDetails below" has to terminate the merchant at the
/// newline, or the capture runs on into the next sentence.
final List<RegExp> _merchantPatterns = [
  RegExp(
    r"\b(?:receipt|invoice|order|purchase|confirmation)\s+from\s+([A-Z0-9][\w.&' -]{1,40}?)(?=[.,!|–—-]|\s+(?:for|on|is|has|dated)\b|\s*$)",
    caseSensitive: false,
    multiLine: true,
  ),
  RegExp(
    r"\byour\s+([A-Z0-9][\w.&' -]{1,40}?)\s+(?:order|receipt|invoice|purchase)\b",
    caseSensitive: false,
    multiLine: true,
  ),
  RegExp(
    r"\bthanks?\s+for\s+(?:your\s+)?(?:order|purchase|shopping)\s+(?:at|with|from)\s+([A-Z0-9][\w.&' -]{1,40}?)(?=[.,!|–—-]|\s*$)",
    caseSensitive: false,
    multiLine: true,
  ),
  RegExp(
    r"^([A-Z0-9][\w.&' -]{1,40}?)\s*[:|–—-]\s*(?:your\s+)?(?:order|receipt|invoice)\b",
    caseSensitive: false,
    multiLine: true,
  ),
];

/// Words that mean we matched the sentence, not the shop.
const Set<String> _notAMerchant = {
  'your', 'our', 'the', 'this', 'that', 'us', 'we', 'me', 'you', //
  'order', 'receipt', 'invoice', 'purchase', 'store', 'shop', 'online',
};

String? guessMerchant(SharedText shared) {
  final subject = (shared.title ?? '').replaceFirst(_subjectNoise, '').trim();

  // The subject is worth far more than the body: it is written to be scanned,
  // and the body is mostly legal boilerplate and shipping addresses.
  for (final source in [subject, _firstLines(shared.text, 6)]) {
    if (source.isEmpty) continue;
    for (final re in _merchantPatterns) {
      final m = re.firstMatch(source);
      final raw = m?.group(1);
      if (raw == null) continue;
      final name = _tidyMerchant(raw);
      if (name.isNotEmpty && !_notAMerchant.contains(name.toLowerCase())) {
        return name;
      }
    }
  }

  // Last resort: the domain of a shared link. "order.johnlewis.com" is a good
  // guess at John Lewis, and a bad guess is visible in the form before save.
  return _merchantFromUrl(shared.url);
}

final RegExp _runsOfSpace = RegExp(r'\s+');
final RegExp _trailingPunctuation = RegExp(r'[\s.,;:!-]+$');
final RegExp _tld =
    RegExp(r'\.(com|co\.uk|net|org|io|shop|store)$', caseSensitive: false);

String _tidyMerchant(String raw) {
  final cleaned = raw
      .replaceAll(_runsOfSpace, ' ')
      .replaceFirst(_trailingPunctuation, '')
      .replaceFirst(_tld, '')
      .trim();
  return cleaned.length > 1 && cleaned.length <= 40 ? cleaned : '';
}

final RegExp _host = RegExp(r'^https?://([^/?#]+)', caseSensitive: false);
final RegExp _publicSuffix =
    RegExp(r'^(com|co|uk|org|net|io|shop|store|de|fr|ca|au)$');

String? _merchantFromUrl(String? url) {
  if (url == null) return null;
  final m = _host.firstMatch(url.trim());
  if (m == null) return null;

  final parts = m.group(1)!.toLowerCase().split('.').where((p) => p != 'www').toList();

  // Drop the TLD, and the second-level part of things like .co.uk.
  while (parts.length > 1 && _publicSuffix.hasMatch(parts.last)) {
    parts.removeLast();
  }

  final name = parts.isEmpty ? null : parts.last;
  if (name == null || name.length < 2 || _notAMerchant.contains(name)) return null;
  return name[0].toUpperCase() + name.substring(1);
}

/* ---------------------------------------------------------------- money */

const Map<String, String> _currencyOfSymbol = {
  r'$': 'USD',
  '£': 'GBP',
  '€': 'EUR',
  '¥': 'JPY',
  '₹': 'INR',
  r'R$': 'BRL',
};

/// Labels that mark the number we actually want, best first.
final List<RegExp> _totalLabels = [
  RegExp(r'(?:order|grand|invoice)\s+total', caseSensitive: false),
  RegExp(r'total\s+(?:charged|paid|due|amount)', caseSensitive: false),
  RegExp(r'amount\s+(?:charged|paid|due)', caseSensitive: false),
  RegExp(r'\btotal\b', caseSensitive: false),
  RegExp(r'\bpaid\b', caseSensitive: false),
];

class Money {
  const Money(this.cents, this.currency);
  final int cents;
  final String? currency;
}

class _Amount {
  const _Amount(this.cents, this.currency, this.index);
  final int cents;
  final String? currency;
  final int index;
}

/// The **total**, not the biggest number.
///
/// An order email is full of numbers — subtotals, shipping, tax, the price of
/// each line, a promo code — and the largest is as likely to be an order id as
/// a price. So: find the labelled one, and only fall back to "the largest
/// amount" when nothing is labelled.
Money? guessTotal(String? text) {
  if (text == null) return null;

  final amounts = _findAmounts(text);
  if (amounts.isEmpty) return null;

  for (final label in _totalLabels) {
    final m = label.firstMatch(text);
    if (m == null) continue;

    // The nearest amount after the label, within a line or so. Receipts put
    // the number to the right of its label, or directly beneath it.
    for (final a in amounts) {
      if (a.index >= m.start && a.index - m.start < 120) {
        return Money(a.cents, a.currency);
      }
    }
  }

  var largest = amounts.first;
  for (final a in amounts) {
    if (a.cents > largest.cents) largest = a;
  }
  return Money(largest.cents, largest.currency);
}

/*
  ── The invisible characters are written out ──────────────────────────────

  The TypeScript's character class contained a literal non-breaking space and a
  narrow no-break space, pasted in and indistinguishable from an ordinary one
  in every editor. They are there for a reason — European receipts use them as
  thousands separators — but a regex whose behaviour depends on which of three
  identical-looking characters got typed is a regex nobody can safely edit.

  Written as escapes here, which means the string cannot be fully raw: adjacent
  literals concatenate, so the escaped part is spliced into the raw parts.
*/
const String _spaceChars = '\u00a0\u202f ';

final RegExp _amountRe = RegExp(
  r'(R\$|[$£€¥₹])\s?'
  r'(\d{1,3}(?:[,.'
  '$_spaceChars'
  r']\d{3})*(?:[.,]\d{2})?|\d+(?:[.,]\d{2})?)'
  r'|(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})\s?(USD|GBP|EUR|CAD|AUD|JPY|INR)\b',
);

List<_Amount> _findAmounts(String text) {
  final out = <_Amount>[];
  for (final m in _amountRe.allMatches(text)) {
    final symbol = m.group(1);
    final raw = m.group(2) ?? m.group(3);
    final code = m.group(4);
    if (raw == null) continue;

    final cents = _toCents(raw);
    if (cents == null) continue;

    out.add(_Amount(
      cents,
      code ?? (symbol == null ? null : _currencyOfSymbol[symbol]),
      m.start,
    ));
  }
  return out;
}

final RegExp _spaces = RegExp('[$_spaceChars]');
final RegExp _decimalTail = RegExp(r'^(.*?)([.,])(\d{2})$');
final RegExp _separators = RegExp(r'[.,]');
final RegExp _digitsOnly = RegExp(r'^\d+$');

/// "1,234.56" and "1.234,56" are the same money written by different
/// countries. The last separator followed by exactly two digits is the decimal
/// point; the rest are thousands. **The same rule the price field uses**, and
/// deliberately so — see `parseMoneyToCents` in format.dart.
int? _toCents(String raw) {
  final s = raw.replaceAll(_spaces, '');
  final m = _decimalTail.firstMatch(s);

  final whole = (m == null ? s : m.group(1)!).replaceAll(_separators, '');
  final frac = m == null ? '00' : m.group(3)!;
  if (!_digitsOnly.hasMatch(whole)) return null;

  final wholeValue = int.tryParse(whole);
  if (wholeValue == null) return null;

  // A receipt with a number this large is not a receipt.
  if (wholeValue > 1000000000) return null;
  return wholeValue * 100 + int.parse(frac);
}

/* ---------------------------------------------------------------- dates */

const Map<String, int> _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

const String _monthName = '(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*';

class _DatePattern {
  const _DatePattern(this.re, this.read);
  final RegExp re;

  /// Returns [year, month, day], or null when the match is ambiguous.
  final List<int>? Function(RegExpMatch) read;
}

/// A date, but only when it cannot be read two ways.
///
/// **03/04/2026 is the 3rd of April to most of the world and the 4th of March
/// to the United States**, and nothing in an email reliably says which.
/// Guessing wrong shifts a warranty expiry by up to eleven months, and the
/// error is invisible until the day it matters — so numeric dates are only
/// accepted when one component is greater than 12 and settles it. Named months
/// are always safe, which is why most receipts use them.
String? parseLooseDate(String? text, [DateTime? today]) {
  if (text == null) return null;

  final patterns = <_DatePattern>[
    // 2026-08-09
    _DatePattern(
      RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b'),
      (m) => [int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)],
    ),

    // 9 August 2026 · 9 Aug 2026
    _DatePattern(
      RegExp('\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+$_monthName\\.?,?\\s+(\\d{4})\\b',
          caseSensitive: false),
      (m) => [
        int.parse(m.group(3)!),
        _months[m.group(2)!.toLowerCase()]!,
        int.parse(m.group(1)!),
      ],
    ),

    // August 9, 2026 · Aug 9 2026
    _DatePattern(
      RegExp('\\b$_monthName\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4})\\b',
          caseSensitive: false),
      (m) => [
        int.parse(m.group(3)!),
        _months[m.group(1)!.toLowerCase()]!,
        int.parse(m.group(2)!),
      ],
    ),

    // Numeric, and only when the day is unmistakable.
    _DatePattern(
      RegExp(r'\b(\d{1,2})[/.](\d{1,2})[/.](\d{4})\b'),
      (m) {
        final a = int.parse(m.group(1)!);
        final b = int.parse(m.group(2)!);
        final year = int.parse(m.group(3)!);
        if (a > 12 && b <= 12) return [year, b, a]; // 25/08/2026 — day first
        if (b > 12 && a <= 12) return [year, a, b]; // 08/25/2026 — month first
        return null; // 03/04/2026 — refuse
      },
    ),
  ];

  final now = today ?? DateTime.now();
  final todayIso = _isoOf(now);

  for (final p in patterns) {
    final m = p.re.firstMatch(text);
    if (m == null) continue;

    final parts = p.read(m);
    if (parts == null) continue;

    final y = parts[0], mo = parts[1], d = parts[2];
    if (mo < 1 || mo > 12 || d < 1 || d > 31) continue;

    final iso = '$y-${_pad(mo)}-${_pad(d)}';

    // A receipt is for something already bought. A date in the future is a
    // delivery estimate or a warranty end, and neither is the purchase date.
    if (y < 1990 || iso.compareTo(todayIso) > 0) continue;
    return iso;
  }

  return null;
}

String _pad(int n) => n.toString().padLeft(2, '0');

String _isoOf(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

/* ---------------------------------------------------------- order number */

final RegExp _orderRe = RegExp(
  r'\border\s*(?:#|no\.?|number|id)?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]{4,24})\b',
  caseSensitive: false,
);

final RegExp _referenceRe = RegExp(
  r'\b(?:invoice|reference|confirmation)\s*(?:#|no\.?|number)?\s*[:#]?\s*([A-Z0-9][A-Z0-9-]{4,24})\b',
  caseSensitive: false,
);

final RegExp _hasDigit = RegExp(r'\d');

String? guessOrderNumber(String? text) {
  if (text == null) return null;

  final m = _orderRe.firstMatch(text) ?? _referenceRe.firstMatch(text);
  final id = m?.group(1);

  // A run of words is not a reference. Require at least one digit.
  return id != null && _hasDigit.hasMatch(id) ? id : null;
}

/* ----------------------------------------------------------------- kind */

final RegExp _separatorish = RegExp(r'[-_.]+');
final RegExp _warrantyish =
    RegExp(r'warrant|guarantee|protection plan|cover(age)? plan|service plan');
final RegExp _manualish = RegExp(r'manual|instruction|user guide|handbook|spec sheet');
final RegExp _receiptish =
    RegExp(r'receipt|invoice|order|purchase|payment|confirmation|billing');

/// What kind of document this is, from the filename and the subject.
///
/// Filename first: someone who named a file "extended-warranty.pdf" has told us
/// more than the subject line of the email it arrived in.
///
/// ── One dead branch removed ───────────────────────────────────────────────
/// The TypeScript ended with a test for image extensions returning `'receipt'`,
/// followed by a bare `return 'receipt'`. The two were identical, so the check
/// never changed an outcome. Its reasoning survives as the comment below, which
/// is the part that was actually load-bearing.
DocKind guessDocKind(String? filename, [SharedText shared = const SharedText()]) {
  // Separators normalised first: "user-guide.pdf" and "user guide.pdf" are the
  // same statement about the file, and only one of them contains "user guide".
  final hay = '${filename ?? ''} ${shared.title ?? ''}'
      .toLowerCase()
      .replaceAll(_separatorish, ' ');

  if (_warrantyish.hasMatch(hay)) return DocKind.warranty;
  if (_manualish.hasMatch(hay)) return DocKind.manual;
  if (_receiptish.hasMatch(hay)) return DocKind.receipt;

  // Anything else — including a shared photo with no clue in its name — is
  // assumed to be a receipt. That is the whole reason someone shares an image
  // into this app.
  return DocKind.receipt;
}

/* ---------------------------------------------------------------- whole */

ReceiptGuess readReceipt(SharedText shared, [DateTime? today]) {
  // Subject and body together: the date is usually in the body, the merchant
  // in the subject, and the total in either.
  final all = [shared.title, shared.text]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join('\n');

  final total = guessTotal(all);

  return ReceiptGuess(
    merchant: guessMerchant(shared),
    purchaseDate: parseLooseDate(all, today),
    totalCents: total?.cents,
    currency: total?.currency,
    orderNumber: guessOrderNumber(all),
  );
}

String _firstLines(String? text, int n) {
  if (text == null) return '';
  return text.split(RegExp(r'\r?\n')).take(n).join('\n');
}
