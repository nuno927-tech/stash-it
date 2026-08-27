/// Adding and editing a document, as the sheet the PWA uses.
///
/// The rules live in `logic/paper_form.dart` and the vocabulary in
/// `logic/papers.dart`. This is the boxes.
///
/// ── The grid names the thing for you ──────────────────────────────────────
/// Tapping Passport fills "Call it" with the word Passport, and typing over it
/// keeps whatever was typed even if the kind is corrected afterwards — a
/// household has four passports and they get called "Nuno's passport". That
/// rule is `renameForKind`, and it is in the logic because it is the only part
/// of this screen worth being sure about.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../billing/current.dart';
import '../db/repository.dart';
import '../logic/dates.dart';
import '../logic/paper_form.dart';
import '../logic/papers.dart';
import '../models/paper.dart';
import '../logic/notify_offer.dart';
import '../notify/sync.dart';
import '../logic/auto_advance.dart';
import 'auto_advance.dart';
import 'confirm_delete.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'paper_icon.dart';
import 'theme.dart';
import 'unlock_sheet.dart';

/// Opens the form. Resolves true when something was saved.
Future<bool?> showPaperForm(
  BuildContext context, {
  required Repository repo,
  Paper? existing,
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
    builder: (context) => _PaperFormSheet(repo: repo, existing: existing),
  );
}

/*
  ── The five that matter ────────────────────────────────────────────────────

  Nobody wants to dial in 197 days. "On the day", "a month", "three months",
  "six months" and "eight months" — and the last is there because a passport
  genuinely needs it: six months of validity most countries require, plus about
  two months of processing.

  There is no "Default" button, unlike the item form's. The default is not an
  absence here — every kind has a real number — so the row simply opens on
  whichever one the kind already means, and picking that same one puts the
  draft back to following the kind rather than overriding it.
*/
const List<(int, String)> _leadChoices = [
  (0, 'On the day'),
  (30, '1 mth'),
  (90, '3 mths'),
  (180, '6 mths'),
  (240, '8 mths'),
];

class _PaperFormSheet extends StatefulWidget {
  const _PaperFormSheet({required this.repo, this.existing});

  final Repository repo;
  final Paper? existing;

  @override
  State<_PaperFormSheet> createState() => _PaperFormSheetState();
}

class _PaperFormSheetState extends State<_PaperFormSheet> {
  late final PaperDraft _draft =
      widget.existing == null ? PaperDraft() : draftOfPaper(widget.existing!);

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

    try {
      final paper = toPaper(_draft, propertyId: widget.repo.propertyId);

      if (_isNew) {
        await widget.repo.createPaper(paper);
      } else {
        await widget.repo.savePaper(paper);
      }

      unawaited(syncReminders(widget.repo));
      // Not `save` — that is what a settings toggle gets. This is the app
      // doing the one thing it is for. See the note on `Cue.stashed`.
      feedback(Cue.stashed);

      // A document always has an expiry — it is the one thing this form
      // refuses to save without — so a save here always earns the offer.
      if (datedSave(expiresOn: _draft.expiresOn)) armNotifyOffer();

      if (mounted) Navigator.of(context).pop(true);
    } on CapReached catch (e) {
      /*
        The wall, and the way through it, in the same moment.

        Showing the sentence alone leaves somebody holding a filled-in form
        with nowhere to go — and the form is still filled in behind this
        sheet, so unlocking and pressing Save again works with nothing
        retyped. That is the whole reason the offer opens here rather than
        sending them to Settings.
      */
      setState(() => _problem = e.message);
      if (!mounted) return;

      final unlocked = await showUnlock(
        context,
        repo: widget.repo,
        billing: appBilling,
        count: e.count,
      );

      // Straight back into the save they were already trying to make.
      if (unlocked && mounted) {
        setState(() => _problem = null);
        await _save();
      }
    } catch (e) {
      setState(() => _problem = 'That did not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final sure = await confirmDelete(context, name: _draft.label);
    if (!sure || widget.existing == null) return;

    await widget.repo.softDeletePaper(widget.existing!.id);
    unawaited(syncReminders(widget.repo));
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Tapping a tile renames the box, unless somebody typed in it.
  void _pickKind(PaperKind kind) {
    feedback(Cue.tap);
    setState(() {
      _draft.pickKind(kind);
      _label.text = _draft.label;
    });
  }

  Future<void> _pickDate({required bool expires}) async {
    final now = DateTime.now();
    final current = parseDate(expires ? _draft.expiresOn : _draft.issuedOn);

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      /*
        An expiry may be in the future and an issue date may not.

        A passport issued next March is not a passport, and the two dates are
        the two ends of the same document — letting either cross the other
        would produce a record whose own arithmetic disagrees with it.
      */
      firstDate: expires ? DateTime(1990) : DateTime(1920),
      lastDate: expires ? DateTime(now.year + 30) : now,
    );

    if (picked == null) return;
    feedback(Cue.tap);

    final iso = '${picked.year.toString().padLeft(4, '0')}'
        '-${picked.month.toString().padLeft(2, '0')}'
        '-${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      if (expires) {
        _draft.expiresOn = iso;
      } else {
        _draft.issuedOn = iso;
      }
    });
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
    _toDates.update(context, complete: cardFilled([_draft.label, _draft.holder]));
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
                _kindCard(c),
                const SizedBox(height: 14),
                KeyedSubtree(key: _datesCardKey, child: _datesCard(c)),
                const SizedBox(height: 14),
                KeyedSubtree(key: _warningCardKey, child: _warningCard(c)),

                if (!_isNew) ...[
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: Icon(Icons.delete_outline, size: 18, color: c.ember),
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
          _footer(c),
        ],
      ),
    );
  }

  /* ----------------------------------------------------------- what is it */

  Widget _kindCard(StashColors c) {
    // Twelve in a grid of three, then Other across the bottom on its own.
    // Not because it does not fit — because it is the answer for everything
    // the other twelve are not, and a thirteenth tile in the grid makes it
    // look like a fourteenth kind of document.
    final grid = PaperKind.values.where((k) => k != PaperKind.other).toList();

    return SheetCard(
      title: 'What is it',
      trailing: PaperMark(_draft.kind, size: 40),
      children: [
        LayoutBuilder(
          builder: (context, box) {
            const gap = 10.0;
            final width = (box.maxWidth - gap * 2) / 3;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final kind in grid)
                  SizedBox(
                    width: width,
                    child: _KindTile(
                      kind: kind,
                      on: _draft.kind == kind,
                      onTap: () => _pickKind(kind),
                    ),
                  ),
                SizedBox(
                  width: box.maxWidth,
                  child: _KindTile(
                    kind: PaperKind.other,
                    on: _draft.kind == PaperKind.other,
                    wide: true,
                    onTap: () => _pickKind(PaperKind.other),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        /*
          ── "Call it" only appears for Other ──────────────────────────────────

          Twelve of the thirteen tiles have already answered it. Tapping
          Passport puts the word Passport in the box, and then asks you to
          confirm the word it just wrote — a field whose only job, most of the
          time, is to be agreed with.

          Other is the one kind that cannot name itself, so that is the one
          time the box is worth its space. Everything else keeps the name the
          tile gave it, and an existing document that was renamed by hand keeps
          the name it was given — `renameForKind` never overwrites something
          somebody typed, which is what makes hiding the field safe.
        */
        if (_draft.kind == PaperKind.other) ...[
          const FieldLabel('Call it'),
          WhiteField(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: _label,
              autofocus: true,
              style: TextStyle(fontFamily: fontBody, fontSize: 16, color: c.text),
              cursorColor: c.gold,
              decoration: bareInput(
                hint: 'What is it?',
                hintStyle: TextStyle(fontFamily: fontBody, fontSize: 16, color: c.muted),
              ),
              onChanged: (v) => setState(() => _draft.label = v),
            ),
          ),
          const SizedBox(height: 12),
        ],

        const FieldLabel('Whose'),
        TextBox(
          initial: _draft.holder,
          hint: 'Optional',
          onChanged: (v) => _draft.holder = v,
        ),
        const SizedBox(height: 14),

        /*
          ── The line that explains an absence ────────────────────────────────

          There is no field for a passport number and no way to attach a scan,
          and both are deliberate: encryption changes what is *possible*, not
          what is *wise*. A backup is a plaintext zip the moment somebody
          shares it, and a document number is the one thing on a passport worth
          stealing.

          Said out loud rather than left as a gap, because a gap looks like
          something the app has not got round to.
        */
        Text(
          "No scans or document numbers, just what's needed so Scout can remind "
          'you when the time comes. Because your privacy matters.',
          style: TextStyle(fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
      ],
    );
  }

  /* ---------------------------------------------------------------- dates */

  Widget _datesCard(StashColors c) {
    return SheetCard(
      title: 'Dates',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Expires'),
                  DateBox(
                    value: _draft.expiresOn,
                    onTap: () => _pickDate(expires: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Issued'),
                  DateBox(
                    value: _draft.issuedOn,
                    onTap: () => _pickDate(expires: false),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Issued by'),
                  TextBox(
                    initial: _draft.authority,
                    hint: 'Optional',
                    onChanged: (v) => _draft.authority = v,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Where the paper physically is. The one field on this form
                  // that is about the object rather than the record, and the
                  // one people actually come back for at 6am before a flight.
                  const FieldLabel('Kept where'),
                  TextBox(
                    initial: _draft.storedAt,
                    hint: 'Fireproof box...',
                    onChanged: (v) => _draft.storedAt = v,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /* -------------------------------------------------------------- warning */

  Widget _warningCard(StashColors c) {
    final lead = leadDaysFor(_draft.kind, _draft.leadDays);

    return SheetCard(
      title: 'How much warning',
      children: [
        SegRow<int>(
          value: lead,
          options: _leadChoices,
          onPick: (v) => setState(() {
            /*
              Choosing the kind's own number means "follow the kind", not
              "override it with the same value". Otherwise correcting a
              passport to an ID card afterwards would leave it on eight months
              — a number nobody chose, silently kept.
            */
            _draft.leadDays = v == defaultLeadDays[_draft.kind] ? null : v;
          }),
        ),
        const SizedBox(height: 12),
        Text(
          leadExplanation(_draft),
          style: TextStyle(fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
        const SizedBox(height: 14),

        const FieldLabel('Notes'),
        TextBox(
          initial: _draft.notes,
          hint: 'Optional',
          lines: 4,
          onChanged: (v) => _draft.notes = v,
        ),
      ],
    );
  }

  /* --------------------------------------------------------------- footer */

  Widget _footer(StashColors c) => SheetFooter(
        label: _isNew ? 'Save document' : 'Save changes',
        // Said before the button is pressed rather than after. The one refusal
        // this form makes, in the one place somebody is already looking.
        problem: _problem ?? whyNotSaveablePaper(_draft),
        onSave: _saving ? null : _save,
      );

}

/* ------------------------------------------------------------- the pieces */

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.on,
    required this.onTap,
    this.wide = false,
  });

  final PaperKind kind;
  final bool on;
  final VoidCallback onTap;

  /// "Other", which runs the full width and puts its label beside the mark
  /// rather than under it.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    final label = Text(
      kindLabel[kind]!,
      textAlign: wide ? TextAlign.left : TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: fontBody,
        fontSize: 12.5,
        height: 1.25,
        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
        color: on ? c.gold : c.text,
      ),
    );

    return Material(
      color: on ? c.washGold : c.slate800,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: wide ? 12 : 12, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(color: on ? c.washGoldLine : Colors.transparent, width: on ? 1.5 : 1),
          ),
          child: wide
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PaperMark(kind, size: 34),
                    const SizedBox(width: 10),
                    label,
                  ],
                )
              : Column(
                  children: [
                    PaperMark(kind, size: 34),
                    const SizedBox(height: 7),
                    label,
                  ],
                ),
        ),
      ),
    );
  }
}






