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
/// ── Still no scans and no document numbers ────────────────────────────────
/// There is no photograph here and no field for one. The database is encrypted
/// at rest, but a `.stashit` backup is a plain zip the moment it is shared —
/// and that is the path a passport scan would actually escape by. See the
/// privacy policy, which says so in as many words.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/card.dart';
import '../logic/dates.dart';
import '../logic/papers.dart';
import '../logic/timeline.dart';
import '../models/paper.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'paper_form_sheet.dart';
import 'paper_icon.dart';
import 'share_card_sheet.dart';
import 'status_pill.dart';
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
        SheetEntrance(child: _PaperViewSheet(repo: repo, paper: paper)),
  );
}

class _PaperViewSheet extends StatefulWidget {
  const _PaperViewSheet({required this.repo, required this.paper});

  final Repository repo;
  final Paper paper;

  @override
  State<_PaperViewSheet> createState() => _PaperViewSheetState();
}

class _PaperViewSheetState extends State<_PaperViewSheet> {
  late Paper _paper = widget.paper;

  Future<void> _edit() async {
    await showPaperForm(context, repo: widget.repo, existing: _paper);
    if (!mounted) return;

    final fresh = await widget.repo.paper(_paper.id);
    if (!mounted) return;
    // Deleted from inside the form rather than edited, so there is nothing
    // left for this sheet to be about.
    if (fresh == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _paper = fresh);
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _paper.label);
    if (!sure || !mounted) return;
    await widget.repo.softDeletePaper(_paper.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final state = paperState(_paper);
    final expires = expiryOf(_paper);
    final renew = renewBy(_paper);
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

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: top,
      minChildSize: 0.4,
      maxChildSize: top,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
              children: [
                /*
                  The glyph on a tinted panel, where the item sheet puts a
                  photograph. Documents have no picture and are never going to
                  — so this is the face, at size, rather than a gap where a
                  photograph would have been.
                */
                ViewFace(
                  child: PaperGlyph(_paper.kind, color: _tone(c, status), size: 58),
                ),
                ViewHeadline(
                  title: _paper.label,
                  subtitle: kindLabel[_paper.kind],
                  status: status,
                  statusWord: _word(state),
                  count: expires == null ? null : daysUntil(expires),
                  countUnit: 'left',
                ),
                if (cells.isNotEmpty) ViewCells(label: 'Details', cells: cells),
                if ((_paper.notes ?? '').trim().isNotEmpty)
                  ViewNote(text: _paper.notes!.trim()),

                /*
                  Said on the screen where somebody might expect to attach one,
                  rather than only in a policy nobody opens. It is a promise the
                  app keeps by having no field, and the reason is worth the two
                  lines.
                */
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                  child: Text(
                    'No scan is kept. A backup is a plain file the moment you '
                    'share it, and a scan next to a name travels further than '
                    'you meant it to.',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11.5,
                      height: 1.5,
                      color: c.muted,
                    ),
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
      ),
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
