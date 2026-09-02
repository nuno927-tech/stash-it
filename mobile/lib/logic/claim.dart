/// The letter an item becomes when it breaks.
///
/// ── The app's most valuable moment, and it did nothing with it ─────────────
/// A warranty coming to an end turns a row amber. That is the app noticing
/// something worth acting on and then leaving the acting entirely to the
/// person: they open the record, read the serial off the screen, type it into
/// an email, go back for the purchase date, go back again for the retailer,
/// then hunt for the receipt.
///
/// Every one of those facts is already here, together, in one record. This
/// turns them into the message that gets the dishwasher fixed.
///
/// ── Written for a stranger who owes you nothing ────────────────────────────
/// The reader is a service desk with a queue. They are looking for four
/// things — what it is, when it was bought, proof of that, and whether it is
/// still covered — and every sentence that is not one of those makes the four
/// harder to find.
///
/// So: no greeting, no pleading, no explanation of what Stash it is. Facts in
/// the order the desk needs them, and a line at the top saying what is being
/// asked for. The person adds their own words above it in whatever they send
/// it with.
///
/// ── And nothing invented ───────────────────────────────────────────────────
/// A field nobody filled in is left out, not printed empty and not guessed at.
/// "Serial: unknown" in a claim is worse than silence: it tells the desk the
/// sender does not have one, when in fact the sender simply never typed it in
/// and could go and read it off the back of the machine.
library;

import '../models/types.dart';
import 'format.dart';
import 'warranty.dart';

/// One `Label: value` line, already formatted.
typedef ClaimLine = (String, String);

/// The facts, in the order a service desk reads them.
///
/// Returned as pairs rather than one string so the sheet can show exactly what
/// is about to be sent, line for line, and the text and the preview cannot
/// disagree.
List<ClaimLine> claimLines(Item item, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final lines = <ClaimLine>[];

  void add(String label, String? value) {
    final text = (value ?? '').trim();
    if (text.isNotEmpty) lines.add((label, text));
  }

  add('Item', item.name);
  add('Brand', item.brand);
  add('Model', item.model);

  // The one the desk asks for and nobody has to hand. It is why the app asks
  // for it at all.
  add('Serial', item.serial);

  add('Bought', _readableDate(item.purchaseDate));
  add('From', item.retailer);

  if (item.purchasePriceCents != null) {
    add(
      'Price',
      '${currencySymbol(item.currency ?? 'USD')}'
      '${(item.purchasePriceCents! / 100).toStringAsFixed(2)}',
    );
  }

  /*
    Every policy, not just the one expiring soonest.

    A couch has a lifetime frame, ten years on the cushions and one on the
    fabric, and which of those is being claimed against is the desk's decision
    rather than this app's. Printing only the nearest would be answering a
    question that has not been asked yet.
  */
  for (final dated in coverageSchedule(item, at)) {
    add(coverageLabel(dated.coverage), _coverText(dated));

    add('${coverageLabel(dated.coverage)} — provider',
        dated.coverage.provider);
    add('${coverageLabel(dated.coverage)} — policy',
        dated.coverage.policyNumber);
  }

  return lines;
}

/// The whole message, ready to be handed to a share sheet.
///
/// [attached] names the files travelling with it. Listed by name because an
/// email with three attachments and no mention of them reads as an email with
/// something wrong with it — and because a share target that silently drops
/// attachments is then visible rather than assumed.
String claimText(
  Item item, {
  List<String> attached = const [],
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final lines = claimLines(item, now: at);

  final out = StringBuffer()
    ..writeln(_opening(item, at))
    ..writeln();

  for (final (label, value) in lines) {
    out.writeln('$label: $value');
  }

  if (attached.isNotEmpty) {
    out.writeln();

    if (attached.length == 1) {
      out.writeln('Attached: ${attached.single}');
    } else {
      out.writeln('Attached:');
      for (final one in attached) {
        out.writeln('  $one');
      }
    }
  }

  return out.toString().trimRight();
}

/// The first line, which is the only one that says what is wanted.
///
/// It changes with the state of the cover, because the ask changes with it: an
/// item still in warranty is a claim, and one whose cover has run out is a
/// question about goodwill or a paid repair. Sending the second worded as the
/// first is how somebody gets a flat no to a letter they never meant to write.
String _opening(Item item, DateTime at) {
  final ends = effectiveExpiry(item, at);
  final state = warrantyState(item, at);

  return switch (state) {
    WarrantyState.expired => 'I am asking about a repair for the item below. '
        'Its warranty ended${ends == null ? '' : ' on ${_longDate(ends)}'}.',
    WarrantyState.unknown =>
      'I am asking about a repair for the item below. I do not have a warranty '
          'length recorded for it.',
    _ => 'I would like to make a warranty claim for the item below'
        '${ends == null ? '' : ', covered until ${_longDate(ends)}'}.',
  };
}

/// "covered until 4 March 2027", "lifetime", "ended 2 January 2024".
String _coverText(DatedCoverage dated) {
  final end = dated.end;
  if (end == null) return 'lifetime';

  final left = dated.daysLeft ?? 0;
  return left < 0
      ? 'ended ${_longDate(end)}'
      : 'covered until ${_longDate(end)}';
}

/// `2026-09-02` as `2 September 2026`.
///
/// A service desk in another country reads 03/09 as March the ninth. The month
/// is spelled out for the same reason the app stores dates the other way round
/// — one of the two forms is unambiguous everywhere and it is this one.
String? _readableDate(String? iso) {
  final text = (iso ?? '').trim();
  if (text.isEmpty) return null;

  final parsed = DateTime.tryParse(text);
  return parsed == null ? null : _longDate(parsed);
}

String _longDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// What the share sheet calls it.
///
/// The item's name, because that is what the recipient's inbox will show and
/// what the sender will search for in six months when the desk has not
/// replied.
String claimSubject(Item item) => 'Warranty claim — ${item.name}';
