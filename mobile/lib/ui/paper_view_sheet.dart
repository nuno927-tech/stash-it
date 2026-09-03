/// One document, as a product page.
///
/// ── Tapping a record should show it, not open a form ──────────────────────
/// Tapping a document went straight into the edit sheet: every field a text
/// box, a keyboard one tap away, and a Save button on a screen nobody had come
/// to change anything on. Most visits here are a question — when does this
/// expire, whose is it, where did I put it — and answering with a form makes
/// somebody read their own data out of input boxes.
///
/// So this reads, and Edit is one button away. Same shape as the item sheet:
/// a face at the top, the name at size, the state and the countdown paired,
/// then details as cells.
///
/// ── Scans live here now, and the lock is what made that possible ──────────
/// There was no photograph here and no field for one, because a `.stashit`
/// backup was a plain zip the moment it was shared — and that is the path a
/// passport scan would actually have escaped by.
///
/// A backup can be sealed with a passphrase now, so the objection has an
/// answer. The lock is asked for before the first scan is taken and cannot be
/// removed while any remain: see `allowScan` and `whyKeepTheLock`. Document
/// numbers are still not a field, and that is unchanged — a number typed into
/// a box is a number in every backup, and nothing about it needs to be.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/card.dart';
import '../logic/dates.dart';
import '../logic/papers.dart';
import '../logic/timeline.dart';
import '../models/paper.dart';
import '../models/types.dart';
import 'confirm_delete.dart';
import 'item_view_sheet.dart' show FileChip;
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'paper_form_sheet.dart';
import 'paper_icon.dart';
import 'share_card_sheet.dart';
import 'status_pill.dart';
import 'thumb.dart';
import 'theme.dart';
import 'view_sheet_parts.dart';

/// Opens the sheet. Resolves once it closes.
///
/// No return value: the caller refreshes either way. A "did anything change"
/// flag cannot be reported honestly from a sheet somebody can drag away — the
/// dismissal returns null and the flag goes with it — and a field written but
/// never read is how this codebase has grown dead code before.
Future<void> showPaperView(
  BuildContext context, {
  required Repository repo,
  required Paper paper,
}) async {
  feedback(Cue.expand);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) =>
        SheetEntrance(child: PaperView(repo: repo, paper: paper)),
  );
}

/// One paper, as a sheet on a phone and as the right-hand pane on a
/// tablet.
///
/// Public and frame-agnostic for the same reason as `ItemView` — the longer
/// note is there. One widget, two frames; a tablet-only copy of a record screen
/// is a copy that drifts.
class PaperView extends StatefulWidget {
  const PaperView({
    required this.repo,
    required this.paper,
    this.pane = false,
    this.onGone,
    super.key,
  });

  final Repository repo;
  final Paper paper;

  /// True when this is the right-hand pane rather than a sheet.
  final bool pane;

  /// Told when the record stops existing. A pane cannot pop itself — that
  /// would take the whole tab off the navigator, list and all.
  final VoidCallback? onGone;

  @override
  State<PaperView> createState() => _PaperViewState();
}

class _PaperViewState extends State<PaperView> {
  late Paper _paper = widget.paper;

  /// Held rather than rebuilt: a `FutureBuilder` handed a fresh future on
  /// every frame re-runs the query for ever.
  late Future<List<Doc>> _scans = widget.repo.docsForPaper(_paper.id);

  /// Gone. See `onGone`.
  void _close() {
    if (widget.onGone != null) {
      widget.onGone!();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _edit() async {
    await showPaperForm(context, repo: widget.repo, existing: _paper);
    if (!mounted) return;

    final fresh = await widget.repo.paper(_paper.id);
    if (!mounted) return;
    // Deleted from inside the form rather than edited, so there is nothing
    // left for this sheet to be about.
    if (fresh == null) {
      _close();
      return;
    }
    setState(() {
      _paper = fresh;
      // The edit sheet is where scans are added, so coming back from it is
      // exactly when this list is out of date.
      _scans = widget.repo.docsForPaper(_paper.id);
    });
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _paper.label);
    if (!sure || !mounted) return;
    await widget.repo.softDeletePaper(_paper.id);
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final state = paperState(_paper);
    final expires = expiryOf(_paper);
    final renew = renewBy(_paper);
    final action = actionDateOf(_paper);
    final top = sheetTop(context);

    final status = switch (state) {
      PaperState.expired => StashStatus.overdue,
      PaperState.renew => StashStatus.soon,
      PaperState.valid => StashStatus.settled,
    };

    final cells = <(String, String)>[
      if ((_paper.holder ?? '').isNotEmpty) ('Whose', _paper.holder!),
      if (expires != null) ('Expires', _long(expires)),
      if (renew != null && state != PaperState.expired)
        ('Renew from', _long(renew)),
      if ((_paper.issuedOn ?? '').isNotEmpty)
        ('Issued', _fromIso(_paper.issuedOn!)),
      if ((_paper.authority ?? '').isNotEmpty) ('Issued by', _paper.authority!),
      if ((_paper.storedAt ?? '').isNotEmpty) ('Kept', _paper.storedAt!),
    ];

    /*
      The same contents in both frames — a sheet you can fling away, or a pane
      filling the space it was given. See `ItemView` for the longer note.
    */
    Widget contents(ScrollController? scroll) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                children: [
                  /*
                    The scan if there is one, the glyph if there is not.

                    That note used to say documents have no picture and never
                    would. They do now, and the first one somebody took is a
                    better answer to "did I open the right record" than a
                    drawing of a passport is — it is their passport.
                  */
                  _Face(
                    repo: widget.repo,
                    scans: _scans,
                    glyph: PaperGlyph(_paper.kind,
                        color: _tone(c, status), size: 64),
                  ),
                  ViewHeadline(
                    title: _paper.label,
                    subtitle: kindLabel[_paper.kind],
                    status: status,
                    statusWord: _word(state),
                    // Counted and coloured exactly as the list row was:
                    // both ask `actionDateOf`, so the figure cannot change
                    // meaning between the row and the page it opens.
                    count: action == null ? null : daysUntil(action),
                    countColour: _tone(c, status),
                    tight: true,
                  ),
                  if (cells.isNotEmpty)
                    ViewCells(label: 'Details', cells: cells),
                  if ((_paper.notes ?? '').trim().isNotEmpty)
                    ViewNote(text: _paper.notes!.trim()),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                    child: FutureBuilder<List<Doc>>(
                      future: _scans,
                      builder: (context, snap) {
                        final scans = snap.data;
                        if (scans == null) return const SizedBox(height: 40);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const ViewLabel('Scans'),
                            const SizedBox(height: 8),
                            if (scans.isEmpty)
                              Text(
                                /*
                                  Says what a scan is FOR rather than that
                                  there isn't one. A renewal office asks for
                                  the page, not for the expiry date, and that
                                  is the reason to keep one.
                                */
                                'Nothing scanned. A photo of the page is what '
                                'a renewal actually asks for.',
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
                                  for (final scan in scans)
                                    FileChip(repo: widget.repo, doc: scan),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            ViewFooter(
              onEdit: _edit,
              onDelete: _delete,
              deleteLabel: 'Delete this document',
              onSend: () => shareCardSheet(
                context,
                repo: widget.repo,
                pick: CardPick(papers: {_paper.id}),
              ),
            ),
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

  Color _tone(StashColors c, StashStatus s) => switch (s) {
        StashStatus.overdue => c.ember,
        StashStatus.soon => c.honey,
        _ => c.moss,
      };

  String _word(PaperState s) => switch (s) {
        PaperState.expired => 'Expired',
        PaperState.renew => 'Renew now',
        PaperState.valid => 'Valid',
      };

  String _long(DateTime d) => dayMonthMaybeYear(d);

  String _fromIso(String iso) {
    final d = parseDate(iso);
    return d == null ? iso : dayMonthMaybeYear(d);
  }
}

/// The top of the sheet: the first scan, or the kind's glyph.
///
/// ── Reading the same future the attachments list reads ────────────────────
/// `_scans` is already in flight for the list further down the sheet, so this
/// costs no second query — and the two cannot disagree about what is
/// attached, which they could if this asked its own question.
///
/// A scan that will not decode — a PDF, a file that arrived broken in a
/// restore — falls back to the glyph rather than to a grey box. The list below
/// still shows it and still hands it out; this is the face, not the evidence.
class _Face extends StatelessWidget {
  const _Face({
    required this.repo,
    required this.scans,
    required this.glyph,
  });

  final Repository repo;
  final Future<List<Doc>> scans;
  final Widget glyph;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return FutureBuilder<List<Doc>>(
      future: scans,
      builder: (context, snap) {
        String? blobId;
        for (final scan in snap.data ?? const <Doc>[]) {
          // A link has no bytes to draw. The first one with a file wins,
          // which is the first one taken.
          if (scan.blobId != null) {
            blobId = scan.blobId;
            break;
          }
        }

        if (blobId == null) return ViewFace.bare(child: glyph);

        return FutureBuilder<ImageProvider?>(
          future: thumbFor(repo, blobId),
          builder: (context, shot) {
            final image = shot.data;
            if (image == null) return ViewFace.bare(child: glyph);

            // The item sheet's photograph, to the pixel: 190 tall, framed,
            // and dimmed across the bottom third so the name underneath has
            // an edge to sit against rather than a hard line.
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
                  Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => Center(child: glyph),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          c.slate900.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
