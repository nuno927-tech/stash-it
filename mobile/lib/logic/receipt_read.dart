/// Reading a receipt, once something else has turned it into text.
///
/// ── The app is called Stash it and it could not read a receipt ─────────────
/// Somebody photographs a receipt and then types in the date, the price and
/// the shop that are printed on the thing they just photographed. Every one of
/// those is on the paper; the app simply was not looking.
///
/// ── Nothing in here touches a camera ───────────────────────────────────────
/// The recognition is one call in `io/text_recognition.dart`. What arrives
/// here is a list of lines, top to bottom, and everything after that is
/// arithmetic on strings — which is why it can be tested against fifty real
/// receipts without a phone in the room.
///
/// ── Proposals, never answers ───────────────────────────────────────────────
/// A receipt is a badly printed, badly lit, thermally faded document that says
/// TOTAL four times and has three dates on it. Getting it right most of the
/// time is achievable; getting it right always is not, and an app that fills a
/// field silently from a guess is an app that quietly records the wrong
/// purchase date on somebody's warranty.
///
/// So every field comes back with a confidence and the screen shows what it
/// read beside what it will fill. Low confidence is offered the same way as
/// high — visibly, and correctable — because hiding an uncertain guess just
/// means nobody sees the one that was right.
library;

/// How sure the reading is, and therefore how it is presented.
enum Sureness {
  /// The line said what it was. "TOTAL 74.99", a date in an unambiguous form.
  clear,

  /// Inferred from shape or position rather than a label — the largest amount
  /// on the receipt, or the first line of the page.
  likely,
}

/// One field read off a receipt.
class ReadField<T> {
  const ReadField({
    required this.value,
    required this.sureness,
    required this.saw,
  });

  final T value;
  final Sureness sureness;

  /// The line it came from, shown beside the proposal so somebody can check
  /// the reading rather than just the result. "Total: 74.99" is a claim;
  /// "from: TOTAL          74.99" is evidence.
  final String saw;
}

/// What a receipt appears to say. Every part optional, because most receipts
/// are missing at least one and a guess would be worse than a blank.
class ReceiptReading {
  const ReceiptReading({this.date, this.totalCents, this.retailer});

  /// `YYYY-MM-DD`, the form the rest of the app stores.
  final ReadField<String>? date;
  final ReadField<int>? totalCents;
  final ReadField<String>? retailer;

  bool get isEmpty => date == null && totalCents == null && retailer == null;
}

/// Reads what it can, and says how sure it is of each part.
///
/// [today] bounds the dates: a receipt is for something already bought, so a
/// date in the future is a misread and is dropped rather than offered.
ReceiptReading readReceipt(List<String> lines, {DateTime? today}) {
  final at = today ?? DateTime.now();
  final kept = [
    for (final line in lines)
      if (line.trim().isNotEmpty) line.trim(),
  ];

  return ReceiptReading(
    date: _readDate(kept, at),
    totalCents: _readTotal(kept),
    retailer: _readRetailer(kept),
  );
}

/* ------------------------------------------------------------------ dates */

/*
  ── Every separator, and the ambiguity is faced rather than ignored ─────────

  04/03/2025 is the fourth of March in most of the world and the third of April
  in the United States, and no amount of cleverness resolves that from the
  digits alone. Two things narrow it honestly:

    - A number above twelve can only be a day, which settles most receipts.
    - A four digit year first (2025-03-04) is unambiguous everywhere.

  When it genuinely cannot be told apart, the reading is `likely` rather than
  `clear` and the screen shows the line it came from — because somebody
  standing there with the receipt in their hand can settle in a second what no
  parser can settle at all.
*/
final RegExp _isoish = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
final RegExp _slashed = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b');
final RegExp _spelled = RegExp(
  r'\b(\d{1,2})[\s-]*'
  r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*'
  r'[\s,-]*(\d{2,4})\b',
  caseSensitive: false,
);
final RegExp _spelledFirst = RegExp(
  r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*'
  r'[\s.]*(\d{1,2})[\s,]*(\d{2,4})\b',
  caseSensitive: false,
);

const List<String> _monthWords = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];

ReadField<String>? _readDate(List<String> lines, DateTime at) {
  for (final line in lines) {
    for (final read in [_isoDate, _spelledDate, _slashedDate]) {
      final got = read(line, at);
      if (got != null) return got;
    }
  }

  return null;
}

ReadField<String>? _isoDate(String line, DateTime at) {
  final m = _isoish.firstMatch(line);
  if (m == null) return null;

  return _fieldFor(
    year: int.parse(m.group(1)!),
    month: int.parse(m.group(2)!),
    day: int.parse(m.group(3)!),
    at: at,
    line: line,
    // Year first is unambiguous in every country there is.
    sureness: Sureness.clear,
  );
}

ReadField<String>? _spelledDate(String line, DateTime at) {
  var m = _spelled.firstMatch(line);
  var day = 0, month = 0, year = 0;

  if (m != null) {
    day = int.parse(m.group(1)!);
    month = _monthWords.indexOf(m.group(2)!.toLowerCase()) + 1;
    year = int.parse(m.group(3)!);
  } else {
    m = _spelledFirst.firstMatch(line);
    if (m == null) return null;

    month = _monthWords.indexOf(m.group(1)!.toLowerCase()) + 1;
    day = int.parse(m.group(2)!);
    year = int.parse(m.group(3)!);
  }

  return _fieldFor(
    year: year,
    month: month,
    day: day,
    at: at,
    line: line,
    // A month spelled out cannot be mistaken for a day.
    sureness: Sureness.clear,
  );
}

ReadField<String>? _slashedDate(String line, DateTime at) {
  final m = _slashed.firstMatch(line);
  if (m == null) return null;

  final first = int.parse(m.group(1)!);
  final second = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);

  /*
    One of them above twelve can only be the day, and that settles the other.

    When neither is, it is genuinely ambiguous — 04/03/2025 is the fourth of
    March in most of the world and the third of April in the United States, and
    nothing in the digits decides it. Day first, because that is the reading
    almost everywhere, and `likely` rather than `clear` so the screen shows the
    line it came from. Somebody holding the receipt settles in a second what no
    parser settles at all.
  */
  final (day, month) = second > 12 ? (second, first) : (first, second);

  return _fieldFor(
    year: year,
    month: month,
    day: day,
    at: at,
    line: line,
    sureness: first > 12 || second > 12 ? Sureness.clear : Sureness.likely,
  );
}

ReadField<String>? _fieldFor({
  required int year,
  required int month,
  required int day,
  required DateTime at,
  required String line,
  required Sureness sureness,
}) {
  // Two digit years. A receipt is not from 1925.
  final full = year < 100 ? 2000 + year : year;

  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final made = DateTime(full, month, day);

  // Round-tripped, because DateTime(2025, 2, 30) silently becomes 2 March and
  // a receipt that says the thirtieth of February is a misread, not a date.
  if (made.month != month || made.day != day) return null;

  /*
    Bounded at both ends.

    A receipt is for something already bought, so anything after today is a
    misread — most often a "use by" or a card expiry, which are printed in the
    same format right next to the purchase date. And nothing before 1990,
    which catches a serial number that happened to look like a date.
  */
  if (made.isAfter(at) || full < 1990) return null;

  return ReadField(
    value: '${full.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}',
    sureness: sureness,
    saw: line,
  );
}

/* ----------------------------------------------------------------- totals */

/*
  ── The word TOTAL appears four times, and one of them is the answer ────────

  A supermarket receipt has SUBTOTAL, TOTAL TAX, TOTAL, and TOTAL SAVINGS, and
  the one that matters is rarely the first. So the labels are ranked rather
  than searched for: the last plain TOTAL beats the first, an AMOUNT DUE beats
  a SUBTOTAL, and anything with SAVINGS, TAX, CHANGE or CASH in it is not the
  purchase price whatever else the line says.

  When no label can be found at all, the largest amount on the receipt is
  offered as `likely`. That is right more often than it is wrong — the total is
  usually the biggest number on the page — and it is exactly the case where the
  line it came from has to be shown.
*/
/*
  A dot and a comma are both thousands separators and both decimal points,
  depending on the country the receipt was printed in.

  So both are allowed in both roles and the LAST one is the decimal, which is
  what tells `1,299.00` from `1.299,00` without having to know where it came
  from. Getting this wrong is not a rounding error: it read 1.299,00 as 299,00
  and proposed a price a thousand euros light.
*/
final RegExp _amount =
    RegExp(r'(\d{1,3}(?:[,.\s]\d{3})*|\d+)[.,](\d{2})\b');

const List<String> _totalWords = [
  'amount due',
  'balance due',
  'total due',
  'grand total',
  'to pay',
  'total',
  'amount',
];

/// Lines that say total and do not mean it.
const List<String> _notTheTotal = [
  'subtotal',
  'sub total',
  'tax',
  'vat',
  'savings',
  'saved',
  'discount',
  'change',
  'cash',
  'tender',
  'points',
  'balance',
];

ReadField<int>? _readTotal(List<String> lines) {
  ReadField<int>? labelled;
  var bestRank = _totalWords.length;

  int? biggest;
  String? biggestLine;

  for (final line in lines) {
    final cents = _centsIn(line);
    if (cents == null) continue;

    if (biggest == null || cents > biggest) {
      biggest = cents;
      biggestLine = line;
    }

    final lower = line.toLowerCase();
    if (_notTheTotal.any(lower.contains)) continue;

    final rank = _totalWords.indexWhere(lower.contains);
    if (rank < 0) continue;

    /*
      `<=` rather than `<`, deliberately.

      A receipt prints the running total and then the final one, both labelled
      TOTAL, and the last is the one that was paid. So an equally good label
      further down the page replaces the one above it.
    */
    if (rank <= bestRank) {
      bestRank = rank;
      labelled = ReadField(
        value: cents,
        sureness: Sureness.clear,
        saw: line,
      );
    }
  }

  if (labelled != null) return labelled;
  if (biggest == null) return null;

  return ReadField(
    value: biggest,
    sureness: Sureness.likely,
    saw: biggestLine!,
  );
}

/// The last amount on a line, in cents.
///
/// The last, because a line reads `TOTAL 3 items    74.99` and the price is on
/// the right. Thousands separators are dropped; the decimal is whichever of
/// `.` or `,` came last, which is what tells a European receipt apart from an
/// American one without having to know where it was printed.
int? _centsIn(String line) {
  final matches = _amount.allMatches(line).toList();
  if (matches.isEmpty) return null;

  final last = matches.last;
  final whole = last.group(1)!.replaceAll(RegExp(r'[,.\s]'), '');
  final frac = last.group(2)!;

  final cents = int.tryParse('$whole$frac');
  return cents == null || cents <= 0 ? null : cents;
}

/* --------------------------------------------------------------- retailer */

/*
  ── The shop's name is at the top, in the least readable part of the page ───

  It is the first thing printed and the first thing to fade, and it is
  surrounded by an address, a phone number, a VAT registration and a slogan.
  There is no label to look for, so this is position and shape: an early line
  that is mostly letters, not an address, not a phone number, and not the word
  RECEIPT.

  Always `likely`. It cannot be anything else — nothing on a receipt says
  "this is the name of the shop" — so it is always shown next to the line it
  came from.
*/
final RegExp _mostlyDigits = RegExp(r'^[\d\s\-()+.,/#*:]+$');
final RegExp _hasLetters = RegExp(r'[a-zA-Z]');

const List<String> _notAName = [
  'receipt',
  'invoice',
  'tax invoice',
  'vat',
  'tel',
  'phone',
  'www',
  'http',
  '.com',
  'street',
  'road',
  'avenue',
  'suite',
  'thank you',
  'welcome',
  'customer copy',
  'merchant copy',
];

ReadField<String>? _readRetailer(List<String> lines) {
  // The top of the page only. A shop name is never two thirds of the way down
  // a receipt, and looking further finds the payment processor instead.
  for (final line in lines.take(6)) {
    if (line.length < 3 || line.length > 40) continue;
    if (_mostlyDigits.hasMatch(line)) continue;
    if (!_hasLetters.hasMatch(line)) continue;

    final lower = line.toLowerCase();
    if (_notAName.any(lower.contains)) continue;

    // A line carrying a price is an item, not a shop.
    if (_centsIn(line) != null) continue;

    return ReadField(
      value: _tidyName(line),
      sureness: Sureness.likely,
      saw: line,
    );
  }

  return null;
}

/// SHOUTING becomes Title Case, and stray punctuation goes.
///
/// Receipts print the shop's name in capitals because that is what a thermal
/// printer does, and "LOWE'S HOME IMPROVEMENT" typed into a field beside
/// "Bosch dishwasher" looks like the app is shouting rather than like a name.
/// Anything already mixed case is left exactly as it is — that one was typed
/// by somebody who meant it.
String _tidyName(String raw) {
  final trimmed = raw.replaceAll(RegExp(r'^[^\w]+|[^\w\s&\x27.-]+$'), '').trim();
  if (trimmed != trimmed.toUpperCase()) return trimmed;

  /*
    Runs of letters, not words split on spaces.

    Splitting on spaces turns B&Q into B&q and H&M into H&m, because an
    ampersand is not a space and the Q is the second character of its word. A
    run of letters is the right unit: `B` and `Q` are two runs and both keep
    their capital, while `LOWE'S` is one run — the apostrophe is part of the
    word — and becomes Lowe's rather than Lowe'S.
  */
  return trimmed.replaceAllMapped(
    RegExp(r"[A-Za-z][A-Za-z\u0027]*"),
    (m) => '${m[0]![0].toUpperCase()}${m[0]!.substring(1).toLowerCase()}',
  );
}
