/// One item, as a product page.
///
/// ── Why this replaced a full screen ───────────────────────────────────────
/// Tapping a document or a subscription opened a sheet; tapping an item pushed
/// a whole route. Three lists, two ideas of what "looking at one of these"
/// means — and the item, which is the richest record in the app, got the
/// heavier, slower one.
///
/// A sheet is also the better fit for what this actually is. Nobody comes here
/// to work; they come to check one fact — when does the cover run out, what is
/// the serial, is the receipt in here — and then leave. A route says "you have
/// gone somewhere". A sheet says "here it is, and the list is still behind
/// you", which is the truth.
///
/// ── The shape is a product page, not a form ───────────────────────────────
/// The old screen was a label-and-value table: `Brand | Bosch`, one per line,
/// left column fixed at 110px. Correct, and it read like a database admin
/// panel. What somebody wants first is the picture, the name, and the one
/// number that says whether they need to do anything — so those are the top
/// third, at size, and the details are a grid of cells underneath rather than
/// a column of rows.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/repository.dart';
import '../logic/card.dart';
import '../logic/dates.dart';
import '../logic/format.dart';
import '../logic/manuals.dart';
import '../logic/prefs.dart' show leadLabel;
import '../logic/timeline.dart';
import '../logic/warranty.dart';
import '../models/types.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'item_form_sheet.dart';
import 'thumb.dart';
import 'share_card_sheet.dart';
import 'status_pill.dart';
import 'theme.dart';
import 'view_sheet_parts.dart';

/// Opens the sheet. Resolves once it closes.
Future<void> showItemView(
  BuildContext context, {
  required Repository repo,
  required Item item,
}) {
  feedback(Cue.expand);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) =>
        SheetEntrance(child: ItemView(repo: repo, item: item)),
  );
}

/// One item, as a sheet on a phone and as the right-hand pane on a tablet.
///
/// ── Public, and the same widget either way ─────────────────────────────────
/// It was private, because a sheet is opened by its own `show` function and
/// nothing else needs to name it. A wide screen needs to name it: the pane
/// holds this directly rather than opening a sheet over the list.
///
/// One widget, two frames. A second version of this screen written for tablets
/// would be a hundred lines to keep in step, and the tablet's would be the copy
/// nobody noticed had drifted.
class ItemView extends StatefulWidget {
  const ItemView({
    required this.repo,
    required this.item,
    this.pane = false,
    this.onGone,
    super.key,
  });

  final Repository repo;
  final Item item;

  /// True when this is the right-hand pane rather than a sheet.
  ///
  /// The difference is the frame and nothing else: a sheet is a
  /// `DraggableScrollableSheet` that can be flung away, and a pane is simply a
  /// column filling the space it was given.
  final bool pane;

  /// What to do when the record stops existing — deleted, or edited into
  /// nothing.
  ///
  /// A sheet pops itself. A pane cannot: popping from inside a pane would take
  /// the whole tab off the navigator, list and all. So the owner is told and
  /// clears its selection.
  final VoidCallback? onGone;

  @override
  State<ItemView> createState() => _ItemViewState();
}

class _ItemViewState extends State<ItemView> {
  late Item _item = widget.item;
  late Future<List<Doc>> _docs = widget.repo.docsForItem(_item.id);
  Room? _room;

  /// Gone. See `ItemView.onGone` for why a pane cannot just pop.
  void _close() {
    if (widget.onGone != null) {
      widget.onGone!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _readRoom();
  }

  Future<void> _readRoom() async {
    if (_item.roomId == null) return;
    final rooms = await widget.repo.rooms();
    if (!mounted) return;
    setState(
        () => _room = rooms.where((r) => r.id == _item.roomId).firstOrNull);
  }

  Future<void> _edit() async {
    await showItemForm(context, repo: widget.repo, existing: _item);
    if (!mounted) return;

    // It may have been deleted rather than edited, in which case this sheet is
    // about a record that no longer exists and should not be sitting open.
    final fresh = await widget.repo.item(_item.id);
    if (!mounted) return;
    if (fresh == null) {
      _close();
      return;
    }
    setState(() {
      _item = fresh;
      _docs = widget.repo.docsForItem(_item.id);
      _room = null;
    });
    unawaited(_readRoom());
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _item.name);
    if (!sure || !mounted) return;
    await widget.repo.softDeleteItem(_item.id);
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final state = warrantyState(_item);
    final schedule = coverageSchedule(_item);
    final top = sheetTop(context);

    final status = switch (state) {
      WarrantyState.expired => StashStatus.overdue,
      WarrantyState.endingSoon => StashStatus.soon,
      WarrantyState.unknown => StashStatus.unknown,
      _ => StashStatus.settled,
    };

    /*
      The same contents in both frames.

      A pane gets no `ScrollController` because it is not being dragged by one
      — the list simply scrolls itself inside the space the pane was given.
    */
    Widget contents(ScrollController? scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                children: [
                  _Hero(repo: widget.repo, item: _item, status: status),
                  _headline(c, status),
                  if (schedule.isNotEmpty) _cover(c, schedule),
                  _facts(c),
                  _files(c),
                  _manual(c),
                ],
              ),
            ),
            _footer(),
          ],
        );

    if (widget.pane) return contents(null);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: top,
      minChildSize: 0.4,
      maxChildSize: top,
      builder: (context, scroll) => contents(scroll),
    );
  }

  /* ------------------------------------------------------------- headline */

  Widget _headline(StashColors c, StashStatus status) {
    final end = effectiveExpiry(_item);
    return ViewHeadline(
      title: _item.name,
      subtitle: [
        if ((_item.brand ?? '').isNotEmpty) _item.brand!,
        if ((_item.model ?? '').isNotEmpty) _item.model!,
      ].join(' · '),
      status: status,
      statusWord: _word(status),
      count: end == null ? null : daysUntil(end),
      // The colour the row in the list was wearing — see `TimeLeft.item`.
      countColour: switch (warrantyState(_item)) {
        WarrantyState.covered => c.moss,
        WarrantyState.endingSoon => c.honey,
        WarrantyState.expired => c.ember,
        WarrantyState.unknown => c.muted,
      },
    );
  }

  String _word(StashStatus s) => switch (s) {
        StashStatus.overdue => 'Lapsed',
        StashStatus.soon => 'Ending soon',
        StashStatus.unknown => 'No term',
        StashStatus.settled => 'In date',
      };

  /* ---------------------------------------------------------------- cover */

  Widget _cover(StashColors c, List<DatedCoverage> schedule) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ViewLabel('Cover'),
          const SizedBox(height: 8),
          for (final dated in schedule)
            Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
              decoration: BoxDecoration(
                color: c.slate800,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      coverageLabel(dated.coverage),
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: c.text,
                      ),
                    ),
                  ),
                  Text(
                    switch ((dated.end, dated.daysLeft)) {
                      // Lifetime has no date and must not be given one — see
                      // the note on `CoverageUnit.lifetime`.
                      (null, _) => 'For life',
                      (final end?, final d?) when d < 0 =>
                        'Ended ${dayMonth(end)}',
                      (final end?, _) => 'Until ${dayMonth(end)}',
                    },
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 12.5,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------- facts */

  Widget _facts(StashColors c) {
    final cells = <(String, String)>[
      if (_room != null) ('Where', _room!.name),
      if ((_item.purchaseDate ?? '').isNotEmpty)
        ('Bought', _bought(_item.purchaseDate!)),
      if (_item.purchasePriceCents != null)
        (
          'Paid',
          '${currencySymbol(_item.currency ?? 'USD')}'
              '${(_item.purchasePriceCents! / 100).toStringAsFixed(2)}',
        ),
      if ((_item.retailer ?? '').isNotEmpty) ('From', _item.retailer!),
      if ((_item.serial ?? '').isNotEmpty) ('Serial', _item.serial!),

      /*
        ── The notice window, said out loud ─────────────────────────────────

        Two items can show the same countdown and wear different colours,
        because how much warning an item wants is the item's own choice — a
        roof and a kettle do not deserve the same notice. That is deliberate,
        and it was invisible: the list showed "27 days left" on both and lit
        only one, with nothing anywhere explaining the difference.

        Shown for every item rather than only the interesting ones, because a
        cell that appears when something is unusual is a cell nobody knows to
        look for.
      */
      if (coveragesOf(_item).isNotEmpty)
        ('Warn me', leadLabel(itemLeadDays(_item))),
    ];

    final notes = (_item.notes ?? '').trim();
    if (cells.isEmpty && notes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
        child: Text(
          'Just a name, so far. Tap Edit to fill in the rest.',
          style: TextStyle(fontFamily: fontBody, fontSize: 13, color: c.muted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ViewCells(label: 'Details', cells: cells),
        if (notes.isNotEmpty) ViewNote(text: notes),
      ],
    );
  }

  String _bought(String iso) {
    final d = parseDate(iso);
    return d == null ? iso : dayMonthMaybeYear(d);
  }

  /* ---------------------------------------------------------------- files */

  Widget _files(StashColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: FutureBuilder<List<Doc>>(
        future: _docs,
        builder: (context, snap) {
          final docs = snap.data;
          if (docs == null) return const SizedBox(height: 40);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ViewLabel('Files'),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                Text(
                  // Names the one that matters rather than saying "no files".
                  'No receipt attached. It is the first thing a claim asks for.',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12.5,
                    height: 1.45,
                    color: c.muted,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final doc in docs)
                      _FileChip(repo: widget.repo, doc: doc),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  /* --------------------------------------------------------------- manual */

  /*
    ── A way to the manual, not the manual ──────────────────────────────────

    The brand and model are already typed, which is nine tenths of finding a
    manual — so the app builds the manufacturer's own search URL and hands it to
    the browser. See `logic/manuals.dart` for why it does not fetch anything
    itself, and why the manufacturer's site beats a web search.

    Shown only when there is a model. Brand alone lands on a support home page,
    which is a button that promises an answer and delivers a menu.
  */
  Widget _manual(StashColors c) {
    if ((_item.model ?? '').trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ViewLabel('Manual'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              feedback(Cue.tap);
              final where =
                  manualSearch(brand: _item.brand, model: _item.model);
              await launchUrl(where, mode: LaunchMode.externalApplication);
            },
            icon: Icon(Icons.menu_book_outlined, size: 17, color: c.gold),
            label: Text(
              manualButtonLabel(_item.brand),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.line),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            // Says where it goes before it goes there. A button that silently
            // leaves the app is the one thing this app should never do quietly.
            'Opens your browser. Nothing is sent from Stash it.',
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 11.5,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }

  /* --------------------------------------------------------------- footer */

  Widget _footer() => ViewFooter(
        onEdit: _edit,
        onDelete: _delete,
        deleteLabel: 'Delete this item',
        onSend: () => shareCardSheet(
          context,
          repo: widget.repo,
          pick: CardPick(items: {_item.id}),
        ),
      );
}

/* ------------------------------------------------------------------ parts */

/// The photograph across the top, or the item's glyph when there is none.
///
/// Full-bleed and 190 tall: it is the first thing on the sheet and the fastest
/// way to know you opened the right record. The scrim exists because a
/// photograph of a white appliance and a dark sheet meet at a hard line
/// otherwise, and the name sits directly under it.
class _Hero extends StatelessWidget {
  const _Hero({required this.repo, required this.item, required this.status});

  final Repository repo;
  final Item item;
  final StashStatus status;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final blobId = item.photoBlobId ?? item.thumbBlobId;

    if (blobId == null) {
      /*
        No photograph, so the glyph — large, centred, on a tinted panel.

        Not a grey box and not nothing. A blank band at the top of a sheet
        reads as something that failed to load; a big icon on a wash reads as a
        choice, and it is the same icon the list row shows, so the two screens
        agree about what this thing is.
      */
      return Container(
        height: 150,
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
        decoration: BoxDecoration(
          color: c.slate800,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.line),
        ),
        child: Center(
          child: Icon(itemIcon(item), size: 52, color: c.muted),
        ),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: repo.blob(blobId).then((b) => b?.bytes),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return const SizedBox(height: 150);

        return Container(
          height: 190,
          margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: c.line),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: BoxFit.cover),
              // Bottom third only, so the picture is not dimmed for the sake
              // of an edge nobody was struggling with.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      c.slate900.withValues(alpha: 0.55)
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One attachment, and tapping it hands the file out.
///
/// ── Shared rather than opened, and that is not a shortcut ─────────────────
/// The bytes live inside an encrypted database, so nothing on the phone can
/// open them where they are — they have to be written somewhere first. Once
/// they are written, the share sheet is the honest offer: it lists every app
/// that can handle the file, including the PDF viewer, and it does not pretend
/// the file stayed private.
///
/// The copy goes to the cache, which Android reclaims. A decrypted receipt
/// should not be left in permanent storage because somebody glanced at it.
class _FileChip extends StatefulWidget {
  const _FileChip({required this.repo, required this.doc});

  final Repository repo;
  final Doc doc;

  @override
  State<_FileChip> createState() => _FileChipState();
}

class _FileChipState extends State<_FileChip> {
  bool _busy = false;

  Future<void> _open() async {
    final blobId = widget.doc.blobId;
    if (blobId == null || _busy) return;

    setState(() => _busy = true);
    try {
      final blob = await widget.repo.blob(blobId);
      if (blob == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              // Honest rather than reassuring: this is what a document whose
              // file went missing looks like, and saying so is how somebody
              // knows to restore rather than assuming it is fine.
              content: Text('The file for this one is missing.'),
            ),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final name = _fileName(widget.doc, blob.mime);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(blob.bytes);

      await Share.shareXFiles([XFile(file.path)], subject: name);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final doc = widget.doc;
    final missing = doc.blobId == null && doc.url == null;

    /*
      ── The chip is bounded, and the name inside it gives way ───────────────

      A `Row` inside a `Wrap` has no width to fit into, so a document titled
      "Bosch SMV4HCX40G dishwasher extended warranty certificate" laid itself
      out at its natural width and painted the overflow stripes off the right
      edge.

      Shortening the string would have hidden it at one text size and let it
      back at the next, so the fix is the constraint rather than the content:
      the pill can be as wide as the sheet and no wider, and the name is what
      gives way inside it. Everything else in the chip is fixed-width and
      load-bearing — an icon that says what kind of file it is, and the words
      "no file" when there is not one.
    */
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.pill),
      onTap: missing ? null : _open,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 36,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.slate800,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _docIcon(doc.kind),
              size: 15,
              color: missing ? c.muted : c.gold,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                doc.title?.trim().isNotEmpty == true
                    ? doc.title!.trim()
                    : _docWord(doc.kind),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 12.5,
                  color: missing ? c.muted : c.text,
                ),
              ),
            ),
            if (missing) ...[
              const SizedBox(width: 6),
              Text(
                'no file',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 11,
                  color: c.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _docIcon(DocKind kind) => switch (kind) {
      DocKind.receipt => Icons.receipt_long,
      DocKind.manual => Icons.menu_book,
      DocKind.warranty => Icons.verified_outlined,
      DocKind.photo => Icons.image_outlined,
      DocKind.other => Icons.description_outlined,
    };

String _docWord(DocKind kind) => switch (kind) {
      DocKind.receipt => 'Receipt',
      DocKind.manual => 'Manual',
      DocKind.warranty => 'Warranty',
      DocKind.photo => 'Photo',
      DocKind.other => 'File',
    };

/// A filename somebody would recognise in their downloads, with a real
/// extension so the receiving app knows what it is holding.
String _fileName(Doc doc, String mime) {
  final base = (doc.title?.trim().isNotEmpty ?? false)
      ? doc.title!.trim()
      : _docWord(doc.kind);

  final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '').trim();
  final ext = switch (mime) {
    'application/pdf' => 'pdf',
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'bin',
  };

  return safe.toLowerCase().endsWith('.$ext') ? safe : '$safe.$ext';
}
