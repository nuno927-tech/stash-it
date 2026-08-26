/// The collection as a spreadsheet.
///
/// ── Why this exists next to a perfectly good backup ───────────────────────
/// A `.stashit` bundle opens in exactly one app. This opens in every one — and
/// the moments somebody most needs their inventory are the moments they are
/// talking to an insurer, a landlord or a solicitor, none of whom will install
/// anything to read it.
///
/// So it is deliberately not a backup: no photographs, no blob ids, no schema
/// version, and importing it back is not offered. It is a printout.
///
/// ── Three files, not one ──────────────────────────────────────────────────
/// Items, documents and subscriptions have almost no columns in common. One
/// sheet holding all three would be mostly empty cells with a "kind" column
/// telling you which quarter of each row to read, which is a shape nobody can
/// sort or total.
library;

import '../logic/warranty.dart';
import '../models/paper.dart';
import '../models/subscription.dart';
import '../models/types.dart';

/// One field, quoted only when it has to be.
///
/// A comma, a quote or a newline inside a value ends the field early in every
/// reader ever written — and item names contain commas constantly ("Sony
/// Bravia 9, 65 inch"). Quotes inside a quoted field are doubled, which is the
/// RFC 4180 rule and the one Excel actually implements.
String _cell(Object? value) {
  final text = value?.toString() ?? '';
  if (!text.contains(RegExp(r'[",\n\r]'))) return text;
  return '"${text.replaceAll('"', '""')}"';
}

String _row(List<Object?> cells) => cells.map(_cell).join(',');

/// `\r\n`, not `\n`.
///
/// Excel on Windows treats a lone newline inside a quoted field as data and
/// the file as one enormous row. Every other reader accepts CRLF, so the
/// stricter one wins.
String _join(List<String> rows) => '${rows.join('\r\n')}\r\n';

String itemsCsv(List<Item> items, {DateTime? now}) {
  final rows = <String>[
    _row([
      'Name', 'Brand', 'Model', 'Serial', 'Bought', 'Price', 'Currency',
      'Retailer', 'Cover ends', 'Days left', 'Policies', 'Notes',
    ]),
  ];

  for (final item in items) {
    final end = effectiveExpiry(item, now);
    final left = warrantyParts(item, now);

    rows.add(_row([
      item.name,
      item.brand,
      item.model,
      item.serial,
      item.purchaseDate,
      // The number, unformatted and in units rather than cents. A currency
      // symbol in a cell turns the column into text and stops it adding up,
      // which is the one thing a spreadsheet is for.
      item.purchasePriceCents == null
          ? ''
          : (item.purchasePriceCents! / 100).toStringAsFixed(2),
      item.currency,
      item.retailer,
      end == null ? '' : _iso(end),
      left.value,
      coveragesOf(item).length,
      item.notes,
    ]));
  }

  return _join(rows);
}

String papersCsv(List<Paper> papers) {
  final rows = <String>[
    _row(['Document', 'Kind', 'Whose', 'Expires', 'Issued', 'Authority', 'Kept', 'Notes']),
  ];

  for (final p in papers) {
    rows.add(_row([
      p.label,
      p.kind.name,
      p.holder,
      p.expiresOn,
      p.issuedOn,
      p.authority,
      p.storedAt,
      p.notes,
    ]));
  }

  return _join(rows);
}

String subscriptionsCsv(List<Subscription> subs, {DateTime? now}) {
  final rows = <String>[
    _row(['Service', 'Amount', 'Currency', 'Every', 'Next renews', 'Per month', 'Notes']),
  ];

  for (final s in subs) {
    final next = nextRenewal(s, now);

    rows.add(_row([
      s.name,
      (s.amountCents / 100).toStringAsFixed(2),
      s.currency,
      s.cadence.name,
      next == null ? '' : _iso(next),
      // The normalised figure, because a yearly plan and a weekly one cannot
      // be compared in the column to the left of it.
      (monthlyCents(s) / 100).toStringAsFixed(2),
      s.notes,
    ]));
  }

  return _join(rows);
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
