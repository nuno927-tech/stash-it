import '../models/paper.dart';
import '../models/types.dart';
import 'papers.dart';
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
  /*
    ── Cover still running, which used to be the one nobody could open ───────

    The dashboard's biggest number, and for most households the biggest arc on
    the ring. It had no filter because of a reasonable-sounding rule — there is
    nothing to DO about something that is fine, so nothing to tap.

    That holds for a figure and not for the ring. Green is usually most of the
    circle, so a ring that answers only its amber and red slivers ignores the
    majority of taps it will ever get, and a control that does nothing four
    times out of five is read as broken rather than as principled.

    And "show me everything still covered" is a real question. It is the one
    somebody asks before they buy a replacement.
  */
  inDate,

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
  ItemFilter.inDate: 'In date',
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
      ItemFilter.inDate => warrantyState(item) == WarrantyState.covered,
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

/*
  ── The same question, asked of a document ──────────────────────────────────

  The ring counts warranties AND documents — "3 need action" can be two items
  and a passport. A tap can only open one list, so it opens the items, and the
  screen then showed 2 under a number that said 3. Both were right; together
  they looked like a bug, which for a number nobody can check is the same
  thing as being one.

  So the list says so. Not by changing either number — both are honest — but
  by carrying the remainder across: a line under the chips reading "and 1
  document", which goes to the tab that holds it.
*/

/// The three questions that mean something to a document as well as an item.
///
/// "No photograph" and "no receipt" are not questions you can ask a passport.
const Set<ItemFilter> filtersSpanningPapers = {
  // A document in date is in date, exactly as an item is — the ring counts
  // both into one green arc, so the list the arc opens has to carry both.
  ItemFilter.inDate,
  ItemFilter.endingSoon,
  ItemFilter.lapsed,
  ItemFilter.noTerm,
};

bool matchesPaperFilter(ItemFilter filter, Paper paper) => switch (filter) {
      ItemFilter.inDate =>
        expiryOf(paper) != null && paperState(paper) == PaperState.valid,
      ItemFilter.endingSoon =>
        expiryOf(paper) != null && paperState(paper) == PaperState.renew,
      ItemFilter.lapsed =>
        expiryOf(paper) != null && paperState(paper) == PaperState.expired,
      ItemFilter.noTerm => expiryOf(paper) == null,
      _ => false,
    };

/// How many documents the same filter caught. Zero when it does not apply.
int papersMatching(ItemFilter filter, List<Paper> papers) =>
    filtersSpanningPapers.contains(filter)
        ? papers.where((p) => matchesPaperFilter(filter, p)).length
        : 0;
