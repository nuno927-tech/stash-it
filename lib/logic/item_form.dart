/// What a half-filled item form means, and when it can be saved.
///
/// Translated from the validation half of `src/lib/addItem.ts`.
///
/// Pure, and separate from the widget, because the rules are the interesting
/// part and a rule buried in an `onPressed` is a rule nobody can test.
///
/// ── The governing idea ────────────────────────────────────────────────────
/// **Refuse as little as possible.** Almost everything here is optional,
/// because an app that will not save a kettle until you find the receipt is an
/// app people stop opening. There are exactly two refusals below and each one
/// exists because saving anyway would produce a record that lies.
library;

import '../models/types.dart';
import 'format.dart';

/*
  `defaultCoverageLabel` is imported, not redeclared.

  There is one word the app calls an unnamed policy, and a second constant
  with the same name and the same value is exactly how a form and a list start
  disagreeing about what to show. The same reasoning as the ending-soon
  default in nudges.dart.
*/
import 'warranty.dart' show coveragesOf, defaultCoverageLabel;

/// A coverage as the form holds it: text in boxes, not yet a policy.
class CoverageDraft {
  CoverageDraft({
    this.id,
    this.label = '',
    this.unit = CoverageUnit.years,
    this.amountText = '',
    this.covers = '',
    this.provider = '',
    this.policyNumber = '',
    this.startsOn,
    this.phone,
    this.url,
  });

  final String? id;
  String label;
  CoverageUnit unit;
  String amountText;
  String covers;
  String provider;
  String policyNumber;

  /// Carried, not edited. None of these three is on the form, and all three
  /// would be erased on save if the draft did not hold them — see the note on
  /// `ItemDraft.thumbBlobId`.
  String? startsOn;
  String? phone;
  String? url;

  /// A row nobody has touched. Blank rows are dropped rather than refused —
  /// tapping "add cover" and changing your mind is not an error.
  bool get isBlank =>
      label.trim().isEmpty &&
      amountText.trim().isEmpty &&
      covers.trim().isEmpty &&
      provider.trim().isEmpty &&
      policyNumber.trim().isEmpty;

  /// Lifetime has no number, so a blank amount is complete for it.
  bool get hasTerm =>
      unit == CoverageUnit.lifetime || (int.tryParse(amountText.trim()) ?? 0) > 0;
}

class ItemDraft {
  ItemDraft({
    this.id,
    this.name = '',
    this.brand = '',
    this.model = '',
    this.serial = '',
    this.retailer = '',
    this.purchaseDate = '',
    this.priceText = '',
    this.currency = 'USD',
    this.notes = '',
    this.leadDays,
    this.roomId,
    this.thumbBlobId,
    this.photoBlobId,
    List<CoverageDraft>? coverages,
  }) : coverages = coverages ?? [];

  final String? id;
  String name;
  String brand;
  String model;
  String serial;
  String retailer;

  /// `YYYY-MM-DD`, or empty.
  String purchaseDate;

  /// As typed, with grouping and a currency symbol possibly in it.
  String priceText;
  String currency;
  String notes;

  /// Null means "use the setting". Zero is a real answer.
  int? leadDays;

  /// Which room it lives in.
  String? roomId;

  /*
    ── Carried, not edited, and that distinction is the bug ─────────────────

    These two are not on the form and nothing here changes them. They are
    fields on the draft anyway, because a draft that does not carry a field is
    a draft that DELETES it on save.

    That is not hypothetical: `toItem` did not mention `roomId`,
    `thumbBlobId` or `photoBlobId`, so every edit to an existing item silently
    dropped its room and severed its photograph — leaving the picture in the
    database as an orphan, and the item looking as though it never had one.
    Opening an item and pressing Save was enough.

    It is the same failure as `Doc.blobId`: a field that one layer does not
    know about is a field that layer erases. The rule that comes out of both:
    **a form model must round-trip every field of the record, whether or not
    the form shows it.**
  */
  String? thumbBlobId;
  String? photoBlobId;

  final List<CoverageDraft> coverages;

  /// The rows that are actually about something.
  List<CoverageDraft> get realCoverages =>
      coverages.where((c) => !c.isBlank).toList();
}

/// Why this cannot be saved, or null when it can.
///
/// One message at a time, in the order somebody would fix them. A form that
/// lights up four errors at once is a form that gets abandoned.
String? whyNotSaveable(ItemDraft d) {
  if (d.name.trim().isEmpty) return 'Give it a name — anything you would call it.';

  /*
    ── The one real refusal ──────────────────────────────────────────────

    A term with no purchase date to count from is not a warranty, it is a
    number. Every countdown, every colour, the ring and the reminder are all
    arithmetic on that date, so saving "24 months" without it produces an item
    the app will quietly report as `unknown` forever — while the person who
    typed 24 believes it is covered.

    Refusing here is the only place the app is allowed to be difficult.
  */
  final wantsCountdown = d.realCoverages.any(
    (c) => c.hasTerm && c.unit != CoverageUnit.lifetime,
  );
  if (wantsCountdown && d.purchaseDate.trim().isEmpty) {
    return 'Add the purchase date — the countdown is measured from it.';
  }

  for (final c in d.realCoverages) {
    if (!c.hasTerm) {
      return 'How long does "${c.label.trim().isEmpty ? 'that cover' : c.label.trim()}" run for?';
    }
  }

  return null;
}

/// The draft as a record, ready for the repository.
///
/// Assumes `whyNotSaveable` returned null. Blank strings become null: a field
/// somebody opened and left empty is not different from one they never opened,
/// and storing `''` makes every reader test for two kinds of nothing.
Item toItem(ItemDraft d, {required String propertyId, DateTime? createdAt}) {
  String? clean(String s) => s.trim().isEmpty ? null : s.trim();

  return Item(
    id: d.id ?? '',
    propertyId: propertyId,
    name: d.name.trim(),
    brand: clean(d.brand),
    model: clean(d.model),
    serial: clean(d.serial),
    retailer: clean(d.retailer),
    purchaseDate: clean(d.purchaseDate),
    purchasePriceCents: parseMoneyToCents(d.priceText),
    currency: d.currency,
    notes: clean(d.notes),
    leadDays: d.leadDays,
    // Carried through untouched — see the note on the draft's fields. Dropping
    // any of these three is a silent delete, not a missing feature.
    roomId: d.roomId,
    thumbBlobId: d.thumbBlobId,
    photoBlobId: d.photoBlobId,
    createdAt: createdAt,
    coverages: [
      for (var i = 0; i < d.realCoverages.length; i++)
        _toCoverage(d.realCoverages[i], i),
    ],
  );
}

Coverage _toCoverage(CoverageDraft c, int index) {
  String? clean(String s) => s.trim().isEmpty ? null : s.trim();

  return Coverage(
    // Keeps its id when editing, so an existing policy is updated rather than
    // replaced — which matters because the id is what the schedule sorts by
    // when two policies end on the same day.
    id: c.id ?? 'c$index',
    label: c.label.trim().isEmpty ? defaultCoverageLabel : c.label.trim(),
    unit: c.unit,
    amount: c.unit == CoverageUnit.lifetime
        ? 0
        : int.tryParse(c.amountText.trim()) ?? 0,
    covers: clean(c.covers),
    provider: clean(c.provider),
    policyNumber: clean(c.policyNumber),
    startsOn: c.startsOn,
    phone: c.phone,
    url: c.url,
  );
}

/// An existing item, opened for editing.
ItemDraft draftOf(Item item) => ItemDraft(
      id: item.id,
      name: item.name,
      brand: item.brand ?? '',
      model: item.model ?? '',
      serial: item.serial ?? '',
      retailer: item.retailer ?? '',
      purchaseDate: item.purchaseDate ?? '',
      priceText: item.purchasePriceCents == null
          ? ''
          : (item.purchasePriceCents! / 100).toStringAsFixed(2),
      currency: item.currency ?? 'USD',
      notes: item.notes ?? '',
      leadDays: item.leadDays,
      roomId: item.roomId,
      thumbBlobId: item.thumbBlobId,
      photoBlobId: item.photoBlobId,

      /*
        ── `coveragesOf`, NOT `item.coverages` ────────────────────────────────

        An item written before the coverages list existed keeps its warranty in
        `warranty` and `extendedWarranty`, and `coveragesOf` is the read-time
        fold that presents those as policies. Reading the raw list instead
        opened every such record with NO cover shown — and saving then wrote
        that back, destroying a warranty by opening the form and pressing Save.

        Folding here means an edit also completes the migration for that
        record: the policies land in the real list, and `toItem` leaving the
        legacy fields behind is then correct rather than destructive.
      */
      coverages: [
        for (final c in coveragesOf(item))
          CoverageDraft(
            id: c.id,
            label: c.label,
            unit: c.unit,
            amountText: c.unit == CoverageUnit.lifetime ? '' : '${c.amount}',
            covers: c.covers ?? '',
            provider: c.provider ?? '',
            policyNumber: c.policyNumber ?? '',
            startsOn: c.startsOn,
            phone: c.phone,
            url: c.url,
          ),
      ],
    );
