/// Everything you own.
///
/// Ordered by what runs out first, with lifetime cover and undated records at
/// the bottom — the same order `coverageSchedule` uses inside a single item,
/// applied across the list.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../notify/sync.dart';

import '../db/repository.dart';
import '../logic/bin.dart';
import '../logic/dashboard.dart';
import '../logic/prefs.dart';
import '../models/settings.dart';
import '../logic/item_icon.dart';
import '../logic/search.dart';
import '../logic/timeline.dart';
import '../logic/warranty.dart';
import '../models/types.dart';
import 'bin_screen.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'item_detail_screen.dart';
import 'item_form_sheet.dart';
import 'notify_offer_dialog.dart';
import 'parts.dart';
import 'room_icon.dart';
import 'scout.dart';
import 'status_pill.dart';
import 'swipe_to_delete.dart';
import 'theme.dart';
import 'undo_bar.dart';
import 'thumb.dart';
import 'warranty_ring.dart';

/// Which slice of the collection the list is showing.
///
/// **Null is the fourth state and the default**: everything except lapsed.
/// Named states are exclusive slices — only lapsed, or only the ones with no
/// term entered — and tapping the chip that is already on returns to null.
///
/// ── What this replaced, and what it gave up ───────────────────────────────
/// Two independent booleans, `_showLapsed` and `_onlyNoTerm`, which between
/// them could express "everything including lapsed" — a view that has quietly
/// gone. It was the least useful of the four: a list sorted by what expires
/// soonest with every dead warranty mixed back into it is the pile the sort
/// exists to unmake.
///
/// What it buys is that the dashboard can now say "lapsed" and mean it. A
/// figure that reads 6 has to land on six rows; landing on the whole list
/// with six of them somewhere in it is a link that technically worked.
enum ItemFilter { lapsed, noTerm }

/*
  ── Third notifier of this shape ────────────────────────────────────────────

  `pendingLink` carries a notification tap, `settingsJump` carries the
  dashboard's backup line, and this carries a dashboard figure. All three
  exist because the widget that knows where to go and the widget that can go
  there are two tabs apart with a shell between them.

  Three is the point at which this should become one mechanism rather than
  three notifiers with three sets of the same listener-plus-post-frame
  boilerplate. It has not been done here because it is a refactor and this is
  a feature, but it is now overdue rather than hypothetical.

  Set before the tab changes, so — as with the other two — a listener alone is
  not enough. A `ValueNotifier` does not replay to somebody who was not
  listening when it was written, and the Items tab is often built for the
  first time a frame AFTER the value is set.
*/
final ValueNotifier<ItemFilter?> itemsFilter = ValueNotifier<ItemFilter?>(null);

class ItemsTab extends StatefulWidget {
  const ItemsTab({required this.repo, super.key});

  final Repository repo;

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

/// How the list is ordered.
///
/// Ordered by how often the answer is wanted, not alphabetically and not by how
/// the enum happens to read. **Expiring is the default and therefore first**;
/// Room is the most specific question and goes last.
enum _Sort { expiry, newest, az, room }

const Map<_Sort, String> _sortLabel = {
  _Sort.expiry: 'Expiring',
  _Sort.newest: 'Newest',
  _Sort.az: 'A–Z',
  _Sort.room: 'Room',
};

class _ItemsTabState extends State<ItemsTab> {
  String _query = '';
  _Sort _sort = _Sort.expiry;

  /*
    Null by default, which means lapsed is hidden.

    A collection accumulates dead warranties for ever — they never leave, and
    on a list sorted by what expires soonest they pile up at the bottom where
    they push the live ones off the screen. So the default view is the live
    one, and lapsed is a place you go deliberately.

    The chips say what they select rather than what tapping them does. "Show
    Lapsed 12" / "Hide Lapsed 12" was a button label pretending to be a filter,
    and it could not express the state the dashboard needs — only lapsed, and
    nothing else.
  */
  ItemFilter? _filter;

  /*
    ── Room grouping, and the setting that was inert without it ─────────────

    `roomsView` has been in the settings model since phase 1 and nothing read
    it — the list sorted by room but drew no headings, so a preference called
    "Rooms start collapsed" governed nothing at all.

    Headings only appear under the Room sort. Under Expiring they would cut the
    one list this screen is for into a dozen pieces ordered by something else.
  */
  final Set<String> _shut = {};
  bool _grouped = false;

  @override
  void initState() {
    super.initState();
    _readRooms();

    // Listener AND one read now, for the reason in the note on `itemsFilter`.
    itemsFilter.addListener(_takeFilter);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeFilter());
  }

  @override
  void dispose() {
    itemsFilter.removeListener(_takeFilter);
    super.dispose();
  }

  /// Takes whatever the dashboard left, and clears it.
  ///
  /// Cleared by the reader rather than the writer, the same rule `pendingLink`
  /// follows: a value set a frame before this widget exists has to survive
  /// until somebody has actually acted on it.
  void _takeFilter() {
    final wanted = itemsFilter.value;
    if (wanted == null || !mounted) return;

    itemsFilter.value = null;
    setState(() => _filter = wanted);
  }

  List<Room> _rooms = const [];

  Future<void> _readRooms() async {
    final rooms = await widget.repo.rooms();
    final settings = await widget.repo.settings();
    if (!mounted) return;

    setState(() {
      _rooms = rooms;
      _grouped = true;
      if (prefsFrom(settings).roomsView == RoomsView.collapsed) {
        // With a dozen rooms the expanded list is a long scroll, and the
        // question people arrive with is usually "what is in the garage".
        _shut
          ..clear()
          ..addAll(rooms.map((r) => r.id))
          ..add('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return StreamBuilder<List<Item>>(
      stream: widget.repo.watchActiveItems(),
      builder: (context, snap) {
        final all = snap.data;
        if (all == null) return const Center(child: CircularProgressIndicator());

        final lapsed = all.where((i) => warrantyState(i) == WarrantyState.expired).length;

        /*
          One switch, four outcomes, and the default is the one with no chip
          lit. Written as a switch rather than a chain of ifs so the states
          cannot overlap — the previous pair of booleans allowed "only no-term
          AND lapsed hidden", which is a filter combination nobody chose and
          nothing on screen explained.
        */
        var shown = switch (_filter) {
          ItemFilter.lapsed =>
            all.where((i) => warrantyState(i) == WarrantyState.expired).toList(),
          ItemFilter.noTerm =>
            all.where((i) => warrantyState(i) == WarrantyState.unknown).toList(),
          null => all.where((i) => warrantyState(i) != WarrantyState.expired).toList(),
        };

        /*
          Search runs over the whole collection, not the filtered view, and it
          is the one place the app looks at everything at once — see
          logic/search.dart. Here it is items only; the merged search across
          documents and subscriptions belongs on a screen of its own.
        */
        if (_query.trim().isNotEmpty) {
          final hits = searchAll(_query, SearchInput(items: all));
          final ids = {
            for (final h in hits)
              if (h is ItemHit) h.item.id,
          };
          shown = shown.where((i) => ids.contains(i.id)).toList();
        }

        shown = _sorted(shown);

        // See the note in papers_tab.dart — the shell owns the add button.
        return SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              /*
                ── Scout stands beside all three rows, not behind them ───────

                He was in a `Stack` with a negative top offset, which cropped
                his ears against the edge of it — and at 104 he was smaller
                than the two rows he stood next to, so he read as a sticker
                rather than as somebody holding the paperwork.

                A `Row` instead: the left column takes what it needs and he
                takes the rest, reaching from the total down past the chips.
                The search field gives up the width rather than him being
                squeezed into a corner, and it was wider than any query anyone
                types anyway.
              */
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _worth(all, c),
                          _search(c),
                          const SizedBox(height: 10),
                          _chips(lapsed, c),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 6),
                      child: Scout(
                        pose: ScoutPose.receipt,
                        height: 132,
                        motion: const [ScoutMotion.breathe],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: shown.isEmpty
                    ? Blank(
                        all.isEmpty
                            ? 'Nothing saved yet.\n\nTap Stash it to put something in.'
                            : 'Nothing here matches that.',
                        // Paperwork when the list has never had anything in it;
                        // ears up when a search found nothing, because those are
                        // different situations and only one of them is a
                        // beginning.
                        pose: all.isEmpty ? ScoutPose.receipt : ScoutPose.alert,
                        poseHeight: all.isEmpty ? 180 : 120,
                      )
                    : _sort == _Sort.room && _grouped
                        ? _roomList(shown, c)
                        : ListView.builder(
                        // One past the end, for the way into the bin.
                        itemCount: shown.length + 1,
                        // Room for the button to sit over without covering the
                        // last row, which is the row people most often want.
                        padding: const EdgeInsets.only(bottom: 96),
                        itemBuilder: (context, i) => i == shown.length
                            ? _BinLink(repo: widget.repo)
                            : _ItemTile(
                                repo: widget.repo,
                                item: shown[i],
                                lit: _filter == ItemFilter.noTerm,
                                onTap: () => _open(shown[i]),
                                onDelete: () => _delete(shown[i]),
                              ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// What the collection is worth, on the screen that is the collection.
  ///
  /// It used to sit on the dashboard paired with a count, which was the wrong
  /// place: the dashboard is about what needs doing, and a total value needs
  /// nothing done about it. Here it is a caption on the list underneath.
  ///
  /// **Never converted across currencies.** An offline app has no exchange
  /// rates, and inventing one produces a total that is confidently wrong and
  /// impossible to check — so a mixed collection reports its biggest currency
  /// and says which.
  Widget _worth(List<Item> all, StashColors c) {
    final totals = valueByCurrency(all);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            totals.isEmpty ? '—' : shortMoney(totals.first),
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w200,
              fontSize: 30,
              letterSpacing: -1.05,
              height: 1,
              color: c.text,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'recorded across ${all.length} ${all.length == 1 ? 'item' : 'items'}'
              '${totals.length > 1 ? ' · ${totals.first.currency}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 12.5,
                fontWeight: FontWeight.w300,
                color: c.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _search(StashColors c) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        decoration: BoxDecoration(
          color: c.slate700,
          // A pill, like the chips under it. A square field above a row of
          // rounded buttons reads as two different kinds of control.
          borderRadius: BorderRadius.circular(Radii.pill),
          
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: c.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontFamily: fontBody, fontSize: 13.5, color: c.text),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintText: 'Search name, brand, serial…',
                  hintStyle: TextStyle(fontFamily: fontBody, fontSize: 13.5, color: c.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*
    ── Two rows, and they are two rows because they are two questions ────────

    All six chips were in one `Wrap` and fell into three ragged lines, with
    "No term" stranded on the third by itself — which read as an afterthought
    rather than as the pair it belongs to.

    They are now two explicit rows, and the split is not cosmetic: the top row
    answers "in what order", the bottom answers "which ones". Sorts are
    exclusive and one is always on. Filters are exclusive of each other and
    can all be off, which is the default view — so tapping a lit filter turns
    it off rather than doing nothing, and that is the whole reason the
    dashboard can link here at all.
  */
  Widget _chips(int lapsed, StashColors c) {
    void pick(ItemFilter f) {
      feedback(Cue.tap);
      setState(() => _filter = _filter == f ? null : f);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final sort in _Sort.values)
                _Chip(
                  label: _sortLabel[sort]!,
                  on: _sort == sort,
                  onTap: () {
                    feedback(Cue.tap);
                    setState(() => _sort = sort);
                  },
                ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              /*
                Offered only when there is something to look at. A filter for a
                category you own nothing in is a control that does nothing,
                sitting where a useful one could be — and tapping it would give
                an empty screen as the answer to a question with no wrong
                answer.
              */
              if (lapsed > 0)
                _Chip(
                  label: 'Lapsed $lapsed',
                  on: _filter == ItemFilter.lapsed,
                  tone: c.ember,
                  onTap: () => pick(ItemFilter.lapsed),
                ),

              _Chip(
                label: 'No term',
                on: _filter == ItemFilter.noTerm,
                tone: c.line,
                onTap: () => pick(ItemFilter.noTerm),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /*
    ── Swiping a row deletes it, softly, with a way back ──────────────────────

    A horizontal drag is the easiest gesture in the app to make by accident
    while scrolling with a thumb, and the thing behind it is a record of
    something somebody owns. So it is a SOFT delete — thirty days in the bin,
    reachable from the foot of this very list — and the snackbar offers an undo
    that does not need finding the bin at all.

    The PWA slides the row aside to reveal a delete button, which is two
    deliberate actions. Android's idiom is the swipe itself plus an undo, and
    mixing the two would give this screen a gesture that behaves like neither
    platform.
  */
  Future<void> _delete(Item item) async {
    await widget.repo.softDeleteItem(item.id);
    unawaited(syncReminders(widget.repo));

    if (!mounted) return;
    showUndo(
      context,
      message: '${item.name} moved to the bin.',
      onUndo: () async {
        await widget.repo.restoreItem(item.id);
        unawaited(syncReminders(widget.repo));
        if (mounted) setState(() {});
      },
    );
  }

  /// The list, cut into rooms with a heading each.
  ///
  /// One flat `ListView` rather than nested ones: a scroller inside a scroller
  /// fights the gesture, and every heading would need its own height guess.
  Widget _roomList(List<Item> shown, StashColors c) {
    final names = {for (final r in _rooms) r.id: r.name};

    // The order the rooms screen was dragged into, then the unassigned pile.
    // "Nowhere yet" last, because it is a to-do list rather than a place.
    final order = <String>[...names.keys, ''];

    final rows = <Widget>[];
    for (final id in order) {
      final group = shown.where((i) => (i.roomId ?? '') == id).toList();
      if (group.isEmpty) continue;

      final shut = _shut.contains(id);
      rows.add(_RoomHeader(
        name: id.isEmpty ? 'Nowhere yet' : (names[id] ?? 'Somewhere'),
        count: group.length,
        shut: shut,
        onTap: () {
          feedback(shut ? Cue.expand : Cue.collapse);
          setState(() => shut ? _shut.remove(id) : _shut.add(id));
        },
      ));

      if (shut) continue;
      rows.addAll(group.map((item) => _ItemTile(
            repo: widget.repo,
            item: item,
            lit: _filter == ItemFilter.noTerm,
            onTap: () => _open(item),
            onDelete: () => _delete(item),
          )));
    }

    rows.add(_BinLink(repo: widget.repo));

    return ListView.builder(
      itemCount: rows.length,
      padding: const EdgeInsets.only(bottom: 96),
      itemBuilder: (context, i) => rows[i],
    );
  }

  List<Item> _sorted(List<Item> items) {
    final out = [...items];

    switch (_sort) {
      case _Sort.expiry:
        out.sort(_soonestFirst);
      case _Sort.newest:
        // Newest first. A null creation date sorts last rather than first —
        // an undated record is not new, it is unknown.
        out.sort((a, b) {
          final x = a.createdAt;
          final y = b.createdAt;
          if (x == null && y == null) return a.name.compareTo(b.name);
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        });
      case _Sort.az:
        out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.room:
        // Grouping by room properly — headings and all — is a bigger piece of
        // work. Sorting by it puts each room's things together, which answers
        // "what is in the garage" without pretending to be the full feature.
        out.sort((a, b) {
          final x = a.roomId ?? '\u{10FFFF}';
          final y = b.roomId ?? '\u{10FFFF}';
          final byRoom = x.compareTo(y);
          return byRoom != 0 ? byRoom : a.name.compareTo(b.name);
        });
    }

    return out;
  }

  /// The form, for a new item or an existing one.
  ///
  /// Nothing is passed back and nothing needs to be: the list is a Drift
  /// stream, so a save rebuilds it. That is the whole reason the repository
  /// exposes `watchActiveItems` rather than a future.
  ///
  /// ── Why the context is not a parameter ─────────────────────────────────
  /// It was, and the analyzer was right to object: `mounted` describes this
  /// State, and a `BuildContext` handed in from elsewhere is not tied to it.
  /// Using the State's own `context` makes the guard mean what it reads like.
  /// ── Tapping a row opens the item, not the form ────────────────────────
  /// It used to go straight to editing, which was fine while there was nothing
  /// to look at. There is now: the photograph, the receipts, the manuals. An
  /// app where the only way to see your receipt is to open an edit form is an
  /// app that thinks its records are for filing rather than for using.
  ///
  /// The plus button still goes straight to the form — there is nothing to
  /// read about a record that does not exist yet.
  Future<void> _open(Item? item) async {
    if (item == null) {
      await showItemForm(context, repo: widget.repo);
    } else {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => ItemDetailScreen(repo: widget.repo, item: item),
        ),
      );
    }
    if (!mounted) return;
    await maybeOfferNotifications(context, widget.repo);
  }
}

/// Soonest to lapse first; nothing-to-count-down last.
///
/// An item with no term is not a failure and is not urgent either — it sits at
/// the bottom rather than being sorted as though its cover ended in 1970.
int _soonestFirst(Item a, Item b) {
  final ea = effectiveExpiry(a);
  final eb = effectiveExpiry(b);
  if (ea == null && eb == null) return a.name.compareTo(b.name);
  if (ea == null) return 1;
  if (eb == null) return -1;
  final byDate = ea.compareTo(eb);
  return byDate != 0 ? byDate : a.name.compareTo(b.name);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap, this.tone});

  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(Radii.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          // The selected state is a wash and a gold edge, not a fill. A solid
          // gold chip on a row of five is the loudest thing on the screen, and
          // "sorted by expiring" is not news.
          color: on ? c.washGold : c.slate700,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: on ? c.washGoldLine : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tone != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: on ? c.gold : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A room, and how many things are in it.
class _RoomHeader extends StatelessWidget {
  const _RoomHeader({
    required this.name,
    required this.count,
    required this.shut,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool shut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        color: c.slate700,
        child: Row(
          children: [
            /*
              The glyph, in a tinted square.

              A bare icon on a coloured band reads as part of the text; the
              square gives it an edge to sit against, and it is what makes the
              header a place rather than a label. Matched on the name — see
              logic/room_icon.dart for why it is not a stored field.
            */
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.slate600,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Center(child: RoomIcon(name, color: c.gold, size: 21)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: c.text,
                ),
              ),
            ),
            /*
              This printed the four characters "$count" for one release. The
              dollar was escaped in a plain string that was never a template,
              so nothing complained — the analyzer's job is to catch a name
              that does not exist, and `\$count` is not a name, it is the text.

              A wrong number would have been noticed by the arithmetic. Text
              that is quietly not an expression can only be caught by looking.
            */
            Text(
              '$count',
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.muted,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: shut ? -0.25 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.expand_more, size: 22, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The way into the bin, shown only when there is something in it.
///
/// An always-present "Recently deleted (0)" is a row that answers no question,
/// on the screen that can least afford another one. And the moment the app
/// promises the bin — the delete confirmation — is a moment there is certainly
/// something inside it, so the promise is never made about a row that is not
/// there.
class _BinLink extends StatelessWidget {
  const _BinLink({required this.repo});

  final Repository repo;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return FutureBuilder<List<Item>>(
      future: repo.deletedItems(),
      builder: (context, snap) {
        final binned = snap.data ?? const <Item>[];
        if (binned.isEmpty) return const SizedBox.shrink();

        final entries = [
          for (final i in binned)
            BinEntry(id: i.id, kind: BinKind.item, name: i.name, deletedAt: i.deletedAt),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: c.slate700,
            borderRadius: BorderRadius.circular(Radii.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () {
                feedback(Cue.tap);
                showBin(context, repo);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.md),
                  
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recently deleted',
                        style: TextStyle(
                          fontFamily: fontBody,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: c.text,
                        ),
                      ),
                    ),
                    Text(
                      // "1 thing · 23 days left" — how many, and how long the
                      // most urgent one has. The only deadline that matters is
                      // the next one.
                      binSummary(entries),
                      style: TextStyle(fontFamily: fontBody, fontSize: 11.5, color: c.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One row: the photograph inside its rings, the name, and the countdown.
///
/// ── The picture replaced the icon, and that is not decoration ─────────────
/// A guessed icon says "this is probably a kitchen thing". A photograph says
/// "this is your dishwasher", which is the question somebody scanning a list of
/// twenty appliances is actually asking. The icon stays as the fallback for
/// items with no photo, where a guess beats an empty circle.
///
/// The ring goes round the photograph rather than beside it so the state and
/// the picture occupy one piece of space instead of two — see `WarrantyRing`.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.repo,
    required this.item,
    this.lit = false,
    this.onTap,
    this.onDelete,
  });

  final Repository repo;
  final Item item;

  /// Washed gold, for the rows a filter singled out.
  ///
  /// Only ever true for the no-term filter, because that is the one state
  /// `statusWash` deliberately leaves unpainted — an item with no term is not
  /// in trouble, it is unanswered, and tinting every one of them all the time
  /// would be wallpaper. Lit only while somebody has asked to see exactly
  /// these.
  final bool lit;

  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    if (onDelete == null) return _row(context, c);

    return SwipeToDelete(
      id: 'item-${item.id}',
      name: item.name,
      // A tick when the row is far enough — see `SwipeToDelete`, which
      // exists for that one buzz.
      confirm: () => confirmDelete(context, name: item.name),
      onDelete: onDelete!,
      child: _row(context, c),
    );
  }

  Widget _row(BuildContext context, StashColors c) {
    final state = warrantyState(item);
    final end = effectiveExpiry(item);

    /*
      On an item with several policies the cover is the more useful second line
      — which one ends first — so it takes the slot the model and year usually
      hold. On everything else nothing changes: one warranty needs no
      explaining, and "Warranty ends first" down the whole list would be noise
      dressed as information.
    */
    final second = coverSummary(item) ?? _subtitle(item, state, end);

    final status = switch (state) {
      WarrantyState.expired => StashStatus.overdue,
      WarrantyState.endingSoon => StashStatus.soon,
      WarrantyState.unknown => StashStatus.unknown,
      _ => StashStatus.settled,
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        /*
          A hairline between rows rather than nothing. Twenty-five rows of
          photograph, name and number with no rule between them read as one
          block of texture — the line is what makes each one a row.

          The wash sits on top of the fill and fades out by the middle, so the
          name and the countdown stay on the page colour where they are
          legible. Nothing is drawn for a covered item: green on thirty-eight
          rows is wallpaper, not good news. See status_pill.dart.
        */
        decoration: BoxDecoration(
          color: c.slate800,
          /*
            The filter's own wash wins over the status one.

            They cannot both be right: somebody who tapped "no date" on the
            dashboard is looking for that answer, and a row shaded by its
            warranty state would be answering a question they did not ask.
            Same rule the Subscriptions calendar follows for a chosen day.
          */
          gradient: lit ? filterWash(c) : statusWash(c, status),
          border: Border(bottom: BorderSide(color: c.slate700)),
        ),
        child: Row(
          children: [
            ItemArtLive(
              repo: repo,
              item: item,
              fallback: Icon(_icon(item), size: 18, color: c.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 15.5 against the 11.5 underneath it. They were 14.5 and
                    // 12 — near enough that neither was clearly the name.
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (status != StashStatus.settled) ...[
                        StatusPill(status: status, label: _word(status)),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          second,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 11.5,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // The number is the reason to open the row, so it gets the type.
            // The unit sits under it rather than beside it — "142 days left" on
            // one line at 27px wraps on a phone.
            TimeLeft(item: item),
          ],
        ),
      ),
    );
  }

  /// One word for the pill. Not the same words as the sentence beside it —
  /// "Lapsed" next to "Cover ended 4 March" says the state and then the date,
  /// where repeating "Cover ended" twice would say nothing twice.
  String _word(StashStatus status) => switch (status) {
        StashStatus.overdue => 'Lapsed',
        StashStatus.soon => 'Ending',
        StashStatus.unknown => 'No term',
        StashStatus.settled => 'Covered',
      };

  String _subtitle(Item item, WarrantyState state, DateTime? end) {
    if (state == WarrantyState.unknown) return 'No warranty length recorded';
    if (end == null) return 'Covered for life';
    return switch (state) {
      WarrantyState.expired => 'Cover ended ${dayMonth(end)}',
      _ => 'Cover ends ${dayMonth(end)}',
    };
  }
}

/// The icon guesser, mapped onto Material's set.
///
/// A wrong icon is worse than a neutral one — it looks like the app has
/// misunderstood the thing — so anything the keyword table does not recognise
/// gets a plain box rather than a guess.
IconData _icon(Item item) {
  final key = iconKeyFor(IconSubject(
    name: item.name,
    brand: item.brand,
    model: item.model,
    notes: item.notes,
  ));

  return switch (key) {
    IconKey.fridge => Icons.kitchen,
    IconKey.dishwasher || IconKey.washer || IconKey.dryer => Icons.local_laundry_service,
    IconKey.oven || IconKey.microwave => Icons.microwave,
    IconKey.kettle || IconKey.coffee => Icons.coffee,
    IconKey.tv => Icons.tv,
    IconKey.laptop => Icons.laptop,
    IconKey.phone => Icons.smartphone,
    IconKey.speaker => Icons.speaker,
    IconKey.camera => Icons.photo_camera,
    IconKey.router => Icons.router,
    IconKey.console => Icons.videogame_asset,
    IconKey.printer => Icons.print,
    IconKey.saw || IconKey.drill || IconKey.hammer || IconKey.wrench => Icons.handyman,
    IconKey.mower || IconKey.grill => Icons.grass,
    IconKey.bike => Icons.pedal_bike,
    IconKey.car => Icons.directions_car,
    IconKey.sofa || IconKey.chair => Icons.chair,
    IconKey.bed => Icons.bed,
    IconKey.table => Icons.table_restaurant,
    IconKey.lamp => Icons.light,
    IconKey.boiler || IconKey.aircon => Icons.thermostat,
    IconKey.vacuum => Icons.cleaning_services,
    IconKey.watch => Icons.watch,
    IconKey.box => Icons.inventory_2_outlined,
  };
}
