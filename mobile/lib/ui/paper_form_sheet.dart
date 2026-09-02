/// Adding and editing a document, as the sheet the PWA uses.
///
/// The rules live in `logic/paper_form.dart`, the vocabulary in
/// `logic/papers.dart`, the three cards in `paper_cards.dart` and the write in
/// `save_paper.dart`. This is the order they go in and the footer.
///
/// ── The grid names the thing for you ──────────────────────────────────────
/// Tapping Passport fills "Call it" with the word Passport, and typing over it
/// keeps whatever was typed even if the kind is corrected afterwards — a
/// household has four passports and they get called "Nuno's passport". That
/// rule is `renameForKind`, and it is in the logic because it is the only part
/// of this screen worth being sure about.
///
/// ── Why so little is left here ─────────────────────────────────────────────
/// This form shows all three cards at once, which is the right shape for
/// EDITING. `paper_wizard_sheet.dart` shows the same three one at a time, which
/// is the right shape for the first thirty seconds. They draw the same cards.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/auto_advance.dart';
import '../logic/paper_form.dart';
import '../logic/papers.dart';
import '../models/paper.dart';
import '../notify/sync.dart';
import 'auto_advance.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'paper_cards.dart';
import 'save_paper.dart';
import 'theme.dart';

/// Opens the form. Resolves true when something was saved.
Future<bool?> showPaperForm(
  BuildContext context, {
  required Repository repo,
  Paper? existing,

  /*
    What was already chosen on the way here.

    The step-by-step sheet offers a way out into this form, and an escape hatch
    that throws away the kind and the name somebody has already picked is one
    they use once. Ignored when `existing` is set.
  */
  PaperDraft? starting,
}) {
  feedback(Cue.expand);

  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => SheetEntrance(
      child: _PaperFormSheet(
        repo: repo,
        existing: existing,
        starting: starting,
      ),
    ),
  );
}

class _PaperFormSheet extends StatefulWidget {
  const _PaperFormSheet({required this.repo, this.existing, this.starting});

  final Repository repo;
  final Paper? existing;

  /// Filled in on the step-by-step sheet before somebody asked for the long
  /// way.
  final PaperDraft? starting;

  @override
  State<_PaperFormSheet> createState() => _PaperFormSheetState();
}

class _PaperFormSheetState extends State<_PaperFormSheet> {
  late final PaperDraft _draft = widget.existing != null
      ? draftOfPaper(widget.existing!)
      : (widget.starting ?? PaperDraft());

  /// Held rather than rebuilt from `initialValue`, because tapping a kind
  /// rewrites the name and a `TextFormField` will not notice.
  late final TextEditingController _label =
      TextEditingController(text: _draft.label);

  String? _problem;
  bool _saving = false;

  /*
    Two cards can be finished with; the third is the end of the form. Each key
    marks the card being scrolled TO, not the one being completed.
  */
  final GlobalKey _datesCardKey = GlobalKey();
  final GlobalKey _warningCardKey = GlobalKey();

  late final AutoAdvance _toDates = AutoAdvance(_datesCardKey);
  late final AutoAdvance _toWarning = AutoAdvance(_warningCardKey);

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();

    /*
      A new document opens as a passport, named Passport.

      The draft's own default kind is passport and its label is empty, which
      means the first thing somebody sees is a lit tile above an empty box that
      the app could have filled in. Running the rename once at the start says
      what the tile means before anybody has to tap it.
    */
    if (_isNew && _draft.label.isEmpty) {
      _draft.label = kindLabel[_draft.kind]!;
      _label.text = _draft.label;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _toDates.dispose();
    _toWarning.dispose();
    super.dispose();
  }

  /* ------------------------------------------------------------- saving */

  Future<void> _save() async {
    final problem = whyNotSaveablePaper(_draft);
    if (problem != null) {
      feedback(Cue.error);
      setState(() => _problem = problem);
      return;
    }

    setState(() {
      _problem = null;
      _saving = true;
    });

    final outcome = await savePaperDraft(
      context,
      repo: widget.repo,
      draft: _draft,
      isNew: _isNew,
    );

    if (!mounted) return;

    switch (outcome) {
      case PaperNotSaved(:final message):
        setState(() {
          _problem = message;
          _saving = false;
        });

      case PaperSaved():
        Navigator.of(context).pop(true);
    }
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _draft.label);
    if (!sure || widget.existing == null) return;

    await widget.repo.softDeletePaper(widget.existing!.id);
    unawaited(syncReminders(widget.repo));
    if (mounted) Navigator.of(context).pop(true);
  }

  /* -------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Just under the tab heading — see `sheetTop`. Five cards of answers do
    // not fit in two thirds, and what you saw first was a third of a form.
    final top = sheetTop(context);

    /*
      ── The whole card, optionals included ──────────────────────────────────

      The kind is never unset, so it is not listed. Everything else on the card
      is, including "Whose" and "Call it" — see `cardFilled` for why the
      inventory is written out rather than reduced to the field that matters.
    */
    _toDates.update(context,
        complete: cardFilled([_draft.label, _draft.holder]));
    _toWarning.update(
      context,
      complete: cardFilled([
        _draft.expiresOn,
        _draft.issuedOn,
        _draft.authority,
        _draft.storedAt,
      ]),
    );

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
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              children: [
                PaperKindCard(
                  draft: _draft,
                  label: _label,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _datesCardKey,
                  child: PaperDatesCard(
                    draft: _draft,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: _warningCardKey,
                  child: PaperWarningCard(
                    draft: _draft,
                    onChanged: () => setState(() {}),
                  ),
                ),
                if (!_isNew) ...[
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon:
                          Icon(Icons.delete_outline, size: 18, color: c.ember),
                      label: Text(
                        'Delete this document',
                        style: TextStyle(fontFamily: fontBody, color: c.ember),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SheetFooter(
            label: _isNew ? 'Save document' : 'Save changes',
            // Said before the button is pressed rather than after. The one
            // refusal this form makes, in the one place somebody is already
            // looking.
            problem: _problem ?? whyNotSaveablePaper(_draft),
            onSave: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
