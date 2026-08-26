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
import 'item_form_screen.dart';
import 'notify_offer_dialog.dart';
import 'parts.dart';
import 'scout.dart';
import 'swipe_to_delete.dart';
import 'theme.dart';
import 'undo_bar.dart';
import 'thumb.dart';
import 'warranty_ring.dart';

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
    Lapsed hidden by default.

    A collection accumulates dead warranties for ever — they never leave, and
    on a list sorted by what expires soonest they all pile up at the bottom
    where they push the live ones off the screen. The toggle says what tapping
    it DOES rather than what is currently true: as a state — "Lapsed shown" —
    it read as a label, and you had to work out the inverse to know what would
    happen.
  */
  bool _showLapsed = false;

  /// The one filter kept from the port's own chip row.
  ///
  /// It survives because it answers a question the sorts cannot: "what have I
  /// not finished entering". The four it replaced — All, Ending soon, Covered,
  /// Lapsed — were all restatements of the order the list is already in.
  bool _onlyNoTerm = false;

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

        var shown = all;
        if (_onlyNoTerm) {
          shown = shown.where((i) => warrantyState(i) == WarrantyState.unknown).toList();
        }
        if (!_showLapsed) {
          shown = shown.where((i) => warrantyState(i) != WarrantyState.expired).toList();
        }

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
          border: Border.all(color: c.hairline),
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

  Widget _chips(int lapsed, StashColors c) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Wrap(
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

          /*
            Offered only when there is something to hide. A toggle for a
            category you own nothing in is a control that does nothing, sitting
            where a useful one could be.
          */
          if (lapsed > 0)
            _Chip(
              label: _showLapsed ? 'Hide Lapsed $lapsed' : 'Show Lapsed $lapsed',
              on: !_showLapsed,
              onTap: () {
                feedback(Cue.tap);
                setState(() => _showLapsed = !_showLapsed);
              },
            ),

          _Chip(
            label: 'No term',
            on: _onlyNoTerm,
            tone: c.line,
            onTap: () {
              feedback(Cue.tap);
              setState(() => _onlyNoTerm = !_onlyNoTerm);
            },
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
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => item == null
            ? ItemFormScreen(repo: widget.repo)
            : ItemDetailScreen(repo: widget.repo, item: item),
      ),
    );
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: c.slate700,
        child: Row(
          children: [
            AnimatedRotation(
              turns: shut ? -0.25 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.expand_more, size: 20, color: c.muted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
            Text(
              '\$count',
              style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.muted),
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
                  border: Border.all(color: c.hairline),
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
    this.onTap,
    this.onDelete,
  });

  final Repository repo;
  final Item item;
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

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        // A hairline between rows rather than nothing. Twenty-five rows of
        // photograph, name and number with no rule between them read as one
        // block of texture — the line is what makes each one a row.
        decoration: BoxDecoration(
          color: c.slate800,
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
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    second,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: fontBody, fontSize: 12, color: c.muted),
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
