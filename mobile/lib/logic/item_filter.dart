import '../models/types.dart';
import 'dashboard.dart';
import 'warranty.dart';

/*
  ── One vocabulary for "which items", shared by whoever asks ────────────────

  Every screen that offers a count of items also, sooner or later, offers to
  show you them. The dashboard ring does it four ways, the Needs a minute card
  does it four more, and the Items tab's own chips do it three. Until now each
  of those counted with its own inline `where`, and the list they opened
  filtered with a different one — which is how a figure reading 3 opened a list
  of 21 and how "no warranty length" and "no term" turned out to mean two
  slightly different things.

  So the predicate is written once, here, and both the count and the list call
  it. They cannot disagree, because there is only one of them.

  `withReceipt` is threaded through because exactly one of these questions
  cannot be answered from an item alone — a receipt is a row in another table.
  Passing it explicitly is uglier than a free function and much harder to get
  wrong than reaching for a repository from inside a predicate.
*/
enum ItemFilter {
  /// Cover has not run out yet but is inside its notice window. The ring's
  /// honey figure.
  endingSoon,

  /// Cover has run out. The ring's ember figure.
  lapsed,

  /// Nothing to count down from at all. The ring's gold figure.
  noTerm,

  /// No receipt attached — the Needs a minute card's first row.
  noReceipt,

  /*
    Not the same question as `noTerm`, and the difference is the whole reason
    both exist.

    `noTerm` asks what the countdown can say: an item with a two-year warranty
    and no purchase date has a term and still cannot be counted down, so the
    ring calls it undated. This asks whether a term was ever entered. Sharing
    one filter between the two counts would make one of the two numbers lie.
  */
  noCoverage,

  /// No purchase date, so cover can only be guessed from.
  noPurchaseDate,

  /// No photograph.
  noPhoto,
}

/// The chip label, which is also what the list says it is showing.
const Map<ItemFilter, String> filterLabel = {
  ItemFilter.endingSoon: 'Action needed',
  ItemFilter.lapsed: 'Lapsed',
  ItemFilter.noTerm: 'No term',
  ItemFilter.noReceipt: 'No receipt',
  ItemFilter.noCoverage: 'No warranty length',
  ItemFilter.noPurchaseDate: 'No purchase date',
  ItemFilter.noPhoto: 'No photo',
};

/// The three the Items tab offers as standing controls.
///
/// The rest are arrival filters: they come from a card that already explained
/// itself, and a permanent chip for each would be seven chips across four
/// lines answering a question nobody on this screen asked.
const List<ItemFilter> standingFilters = [
  ItemFilter.endingSoon,
  ItemFilter.lapsed,
  ItemFilter.noTerm,
];

bool matchesFilter(
  ItemFilter filter,
  Item item, {
  required Set<String> withReceipt,
}) =>
    switch (filter) {
      ItemFilter.endingSoon => warrantyState(item) == WarrantyState.endingSoon,
      ItemFilter.lapsed => warrantyState(item) == WarrantyState.expired,
      ItemFilter.noTerm => warrantyState(item) == WarrantyState.unknown,
      ItemFilter.noReceipt => !withReceipt.contains(item.id),
      ItemFilter.noCoverage => coveragesOf(item).isEmpty,
      ItemFilter.noPurchaseDate => (item.purchaseDate ?? '').isEmpty,
      ItemFilter.noPhoto => item.thumbBlobId == null,
    };

/// What the Needs a minute card's rows open.
const Map<GapKind, ItemFilter> gapFilter = {
  GapKind.receipt: ItemFilter.noReceipt,
  GapKind.warranty: ItemFilter.noCoverage,
  GapKind.date: ItemFilter.noPurchaseDate,
  GapKind.photo: ItemFilter.noPhoto,
};
