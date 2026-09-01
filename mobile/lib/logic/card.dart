/// Sending a few records to somebody else, and receiving theirs.
///
/// ── A card is not a backup, and the difference is the whole design ────────
/// A backup is everything you own and restoring one REPLACES the database. A
/// card is a handful of records somebody chose to send, and receiving one ADDS
/// to what you have. Confusing the two costs a stranger their entire stash in
/// one tap, so they are two file types that refuse each other by name — see
/// the note beside `cardFormat` in bundle.dart.
///
/// ── Everything in here is pure ────────────────────────────────────────────
/// No database, no zip, no file system, no clock unless it is passed in. The
/// zipping and the reading happen in `io/card_file.dart` and the writing to
/// tables in `db/card_import.dart`; what is left here is the two decisions
/// that are actually hard — what a card SAYS, and what happens to ids when it
/// lands somewhere that already has data in it.
library;

import 'bundle.dart';
import 'dashboard.dart';
import 'papers.dart';
import 'warranty.dart';
import '../models/paper.dart';
import '../models/subscription.dart';
import '../models/types.dart';

/// Which records the sender picked.
///
/// Ids rather than objects, because the picking happens on a list and the
/// gathering happens against the database, and passing whole rows between them
/// would mean the file was built from what the screen happened to be showing.
class CardPick {
  const CardPick({
    this.items = const {},
    this.papers = const {},
    this.subscriptions = const {},
    this.attachments = false,
  });

  final Set<String> items;
  final Set<String> papers;
  final Set<String> subscriptions;

  /*
    Photographs, receipts and manuals travel only when this is on, and it is
    off by default.

    A receipt is frequently the most useful thing in a card — it is the first
    thing a claim asks for. It is also a photograph of a piece of paper that
    often carries the last four digits of a card, sometimes a home address, and
    occasionally a signature. Serial numbers are worth having and worth
    stealing.

    None of that makes sharing them wrong. It makes it a decision, and a
    decision belongs to the person pressing send, on the record they are
    sending, rather than to a default set once by somebody who cannot see what
    is in the picture.
  */
  final bool attachments;

  int get count => items.length + papers.length + subscriptions.length;
  bool get isEmpty => count == 0;

  CardPick toggleItem(String id) => _copy(items: _flip(items, id));
  CardPick togglePaper(String id) => _copy(papers: _flip(papers, id));
  CardPick toggleSubscription(String id) =>
      _copy(subscriptions: _flip(subscriptions, id));
  CardPick withAttachments(bool on) => _copy(attachments: on);

  static Set<String> _flip(Set<String> from, String id) =>
      from.contains(id) ? ({...from}..remove(id)) : {...from, id};

  CardPick _copy({
    Set<String>? items,
    Set<String>? papers,
    Set<String>? subscriptions,
    bool? attachments,
  }) =>
      CardPick(
        items: items ?? this.items,
        papers: papers ?? this.papers,
        subscriptions: subscriptions ?? this.subscriptions,
        attachments: attachments ?? this.attachments,
      );
}

/* ------------------------------------------------------- what a card says */

/// The message body that travels beside the file.
///
/// ── Why there is text at all ──────────────────────────────────────────────
/// The file is only openable by somebody who has this app. Most people being
/// sent a warranty do not, and an attachment they cannot open with no words
/// around it is a message that failed. So the text carries the answer on its
/// own — a person can read it, act on it, and never install anything — and the
/// file is there for the one recipient who can use it.
///
/// Written as sentences rather than a field dump. "Bosch dishwasher — warranty
/// until 4 March 2027" is what somebody would have typed; `name: Bosch
/// dishwasher / warrantyEnd: 2027-03-04` is what a form would have.
String cardSummary({
  List<Item> items = const [],
  List<Paper> papers = const [],
  List<Subscription> subscriptions = const [],
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final lines = <String>[];

  for (final item in items) {
    final ends = effectiveExpiry(item, at);
    lines.add(switch (ends) {
      null => '• ${item.name} — no warranty length recorded',
      _ => '• ${item.name} — '
          '${warrantyState(item, at) == WarrantyState.expired ? 'cover ended' : 'covered until'} '
          '${longDate(ends)}',
    });
  }

  for (final paper in papers) {
    final expires = expiryOf(paper);
    lines.add(switch (expires) {
      null => '• ${paper.label} — no expiry recorded',
      _ => '• ${paper.label} — '
          '${paperState(paper, at) == PaperState.expired ? 'expired' : 'expires'} '
          '${longDate(expires)}',
    });
  }

  for (final sub in subscriptions) {
    lines.add('• ${sub.name} — ${monthlyLabel(sub)}');
  }

  /*
    The trailing line names the app and says the attachment is optional.

    Without it the file reads as something you have to open to understand the
    message, which is exactly backwards: everything worth knowing is already
    above, and the attachment is a shortcut for one kind of recipient.
  */
  return '${lines.join('\n')}\n\n'
      'Sent from Stash it. The attached card adds these to your stash if you '
      'have the app — everything you need is above if you do not.';
}

/// `4 March 2027`, which is how somebody reading a text message wants a date.
String longDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

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

/// "£9.99 a month" / "£120 a year", for the summary line.
String monthlyLabel(Subscription sub) {
  final money = shortMoney(CurrencyTotal(sub.currency, sub.amountCents));
  return switch (sub.cadence) {
    Cadence.monthly => '$money a month',
    Cadence.yearly => '$money a year',
    Cadence.weekly => '$money a week',
    Cadence.quarterly => '$money every three months',
  };
}

/* ------------------------------------------------------ what happens on arrival */

/// A card, rewritten so it can be added to a stash that already has data.
class CardMerge {
  const CardMerge({
    required this.items,
    required this.docs,
    required this.papers,
    required this.subscriptions,
    required this.newRooms,
    required this.blobs,
  });

  final List<Item> items;
  final List<Doc> docs;
  final List<Paper> papers;
  final List<Subscription> subscriptions;

  /// Rooms the sender used that the recipient does not have, ready to insert.
  final List<Room> newRooms;

  /// Keyed by the NEW blob id, since every id in here was rewritten.
  final Map<String, BundleBlob> blobs;

  int get count => items.length + papers.length + subscriptions.length;
}

/// Rewrites a parsed card so nothing in it can collide with what is already
/// stored, and returns the rows to insert.
///
/// ── Every id is regenerated, without exception ────────────────────────────
/// Two people who both installed this app have two independent id spaces that
/// happen to look alike. Keeping the sender's ids would mean a card can
/// silently overwrite a record the recipient already had — same id, different
/// dishwasher — and the recipient would find an item they never touched had
/// changed its name. Regenerating makes a collision impossible rather than
/// unlikely.
///
/// ── Rooms are matched by name, not by id ──────────────────────────────────
/// Their "Kitchen" and your "Kitchen" are the same room to a human and two
/// unrelated rows to a database. Matching on the trimmed, case-folded name
/// puts a shared kettle in the kitchen you already have; falling back to
/// creating one means a room you have never heard of arrives named rather than
/// arriving as a blank.
///
/// ── Entitlements are not in here, and that is structural ──────────────────
/// A card carries no settings table at all, so there is no field to read and
/// no branch to get wrong. The paid unlock cannot travel in a file, which is
/// the same rule the backup reader follows for the same reason.
CardMerge planCardMerge(
  ParsedBundle card, {
  required String propertyId,
  required List<Room> existingRooms,
  required String Function() newId,

  /// Null accepts everything in the card. A set accepts only those ids, which
  /// is what the per-record checkboxes on the preview screen produce.
  Set<String>? keep,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final wanted = keep;
  bool takes(String id) => wanted == null || wanted.contains(id);

  // ── rooms ──────────────────────────────────────────────────────────────
  final byName = {
    for (final room in existingRooms)
      if (room.deletedAt == null) _fold(room.name): room.id,
  };
  final roomId = <String, String>{};
  final newRooms = <Room>[];

  for (final room in card.data.rooms) {
    if (room.deletedAt != null) continue;
    final match = byName[_fold(room.name)];
    if (match != null) {
      roomId[room.id] = match;
      continue;
    }
    final made = Room(
      id: newId(),
      propertyId: propertyId,
      name: room.name,
      sortOrder: room.sortOrder,
    );
    roomId[room.id] = made.id;
    byName[_fold(room.name)] = made.id;
    newRooms.add(made);
  }

  // ── blobs ──────────────────────────────────────────────────────────────
  final blobId = <String, String>{};
  final blobs = <String, BundleBlob>{};
  String? mapBlob(String? old) {
    if (old == null) return null;
    final found = card.blobs[old];
    if (found == null) return null;
    final made = blobId[old] ??= newId();
    blobs[made] = found;
    return made;
  }

  // ── the records themselves ─────────────────────────────────────────────
  final itemId = <String, String>{};
  final items = <Item>[];

  for (final item in card.data.items) {
    if (item.deletedAt != null || !takes(item.id)) continue;
    final made = newId();
    itemId[item.id] = made;
    items.add(Item(
      id: made,
      name: item.name,
      propertyId: propertyId,
      brand: item.brand,
      model: item.model,
      serial: item.serial,
      roomId: item.roomId == null ? null : roomId[item.roomId],
      purchaseDate: item.purchaseDate,
      purchasePriceCents: item.purchasePriceCents,
      currency: item.currency,
      retailer: item.retailer,
      coverages: item.coverages,
      warranty: item.warranty,
      extendedWarranty: item.extendedWarranty,
      leadDays: item.leadDays,
      notes: item.notes,
      thumbBlobId: mapBlob(item.thumbBlobId),
      photoBlobId: mapBlob(item.photoBlobId),
      // Now, not the sender's date. It is new to this stash, and the Recently
      // added strip is answering "what did I just put in here".
      createdAt: at,
    ));
  }

  final docs = <Doc>[
    for (final doc in card.data.docs)
      if (doc.deletedAt == null && itemId.containsKey(doc.itemId))
        Doc(
          id: newId(),
          itemId: itemId[doc.itemId]!,
          kind: doc.kind,
          title: doc.title,
          blobId: mapBlob(doc.blobId),
          url: doc.url,
        ),
  ];

  final papers = <Paper>[
    for (final paper in card.data.papers)
      if (paper.deletedAt == null && takes(paper.id))
        Paper(
          id: newId(),
          propertyId: propertyId,
          kind: paper.kind,
          label: paper.label,
          holder: paper.holder,
          expiresOn: paper.expiresOn,
          issuedOn: paper.issuedOn,
          leadDays: paper.leadDays,
          authority: paper.authority,
          storedAt: paper.storedAt,
          notes: paper.notes,
          createdAt: at,
        ),
  ];

  final subscriptions = <Subscription>[
    for (final sub in card.data.subscriptions)
      if (sub.deletedAt == null && takes(sub.id))
        Subscription(
          id: newId(),
          propertyId: propertyId,
          name: sub.name,
          cadence: sub.cadence,
          anchorDate: sub.anchorDate,
          amountCents: sub.amountCents,
          currency: sub.currency,
          serviceId: sub.serviceId,
          logoBlobId: mapBlob(sub.logoBlobId),
          startedDate: sub.startedDate,
          shared: sub.shared,
          payTo: sub.payTo,
          payHow: sub.payHow,
          remindDays: sub.remindDays,
          notes: sub.notes,
          createdAt: at,
        ),
  ];

  return CardMerge(
    items: items,
    docs: docs,
    papers: papers,
    subscriptions: subscriptions,
    newRooms: newRooms,
    blobs: blobs,
  );
}

/// Trimmed and case-folded, so "kitchen " and "Kitchen" are one room.
String _fold(String name) => name.trim().toLowerCase();
