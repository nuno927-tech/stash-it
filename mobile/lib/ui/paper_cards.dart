/// The three cards a document is made of, drawn once for both ways in.
///
/// ── Why they moved out of the form ─────────────────────────────────────────
/// `paper_form_sheet.dart` was the only place a document could be made, so the
/// cards lived inside it. Then the step-by-step sheet arrived and needed the
/// same three — the same thirteen tiles, the same pair of dates, the same five
/// warning choices.
///
/// Copying them would have started identical and drifted the first time either
/// side was touched. Same move as `sub_cards.dart` and `CoverageList` before
/// it: **one card, two screens.**
///
/// ── They own nothing ───────────────────────────────────────────────────────
/// Each takes the draft and a callback, mutates the draft in place and calls
/// back so whoever owns the screen can rebuild. The name field's controller is
/// passed in rather than made here, because tapping a tile rewrites the name
/// and a `TextFormField` will not notice a changed `initialValue`.
library;

import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../logic/paper_form.dart';
import '../logic/papers.dart';
import '../models/paper.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'paper_icon.dart';
import 'theme.dart';

const List<(int, String)> _leadChoices = [
  (0, 'Day of'),
  (30, '1 mth'),
  (90, '3 mths'),
  (180, '6 mths'),
  (240, '8 mths'),
];


/* ------------------------------------------------------------ what is it */

/// Which kind of document, what it is called, and whose it is.
class PaperKindCard extends StatefulWidget {
  const PaperKindCard({
    required this.draft,
    required this.label,
    required this.onChanged,
    this.title = 'What is it',
    super.key,
  });

  final PaperDraft draft;

  /// Owned by the caller. Tapping a tile writes the kind's own word into it.
  final TextEditingController label;

  final VoidCallback onChanged;
  final String title;

  @override
  State<PaperKindCard> createState() => _PaperKindCardState();
}

class _PaperKindCardState extends State<PaperKindCard> {
  /// Tapping a tile renames the box, unless somebody typed in it.
  void _pickKind(PaperKind kind) {
    feedback(Cue.tap);
    widget.draft.pickKind(kind);
    widget.label.text = widget.draft.label;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Twelve in a grid of three, then Other across the bottom on its own.
    // Not because it does not fit — because it is the answer for everything
    // the other twelve are not, and a thirteenth tile in the grid makes it
    // look like a fourteenth kind of document.
    final grid = PaperKind.values.where((k) => k != PaperKind.other).toList();

    return SheetCard(
      title: widget.title,
      trailing: PaperMark(widget.draft.kind, size: 40),
      children: [
        LayoutBuilder(
          builder: (context, box) {
            /*
              Closed up, because thirteen tiles are one palette and not
              thirteen buttons.

              A grid this size is read by sweeping it, and gaps wide enough to
              separate two controls are wide enough to stop it reading as one
              set. Eight between them and nine of padding inside still leaves
              every tile well over the forty-eight the touch guidance asks for
              — the mark alone is thirty-four.
            */
            const gap = 8.0;
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
                      on: widget.draft.kind == kind,
                      onTap: () => _pickKind(kind),
                    ),
                  ),
                SizedBox(
                  width: box.maxWidth,
                  child: _KindTile(
                    kind: PaperKind.other,
                    on: widget.draft.kind == PaperKind.other,
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
        if (widget.draft.kind == PaperKind.other) ...[
          const FieldLabel('Call it'),
          WhiteField(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: widget.label,
              autofocus: true,
              style:
                  TextStyle(fontFamily: fontBody, fontSize: 16, color: c.text),
              cursorColor: c.gold,
              decoration: bareInput(
                hint: 'What is it?',
                hintStyle: TextStyle(
                    fontFamily: fontBody, fontSize: 16, color: c.muted),
              ),
              onChanged: (v) {
                widget.draft.label = v;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        const FieldLabel('Whose'),
        TextBox(
          initial: widget.draft.holder,
          hint: 'Optional',
          onChanged: (v) {
            widget.draft.holder = v;
            widget.onChanged();
          },
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
          "No document numbers, just what's needed so Scout can remind "
          'you when the time comes. Because your privacy matters.',
          style: TextStyle(
              fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
      ],
    );
  }
}

/* ---------------------------------------------------------------- dates */

/// When it expires, when it was issued, by whom, and where the paper lives.
class PaperDatesCard extends StatefulWidget {
  const PaperDatesCard({
    required this.draft,
    required this.onChanged,
    this.title = 'Dates',
    super.key,
  });

  final PaperDraft draft;
  final VoidCallback onChanged;
  final String title;

  @override
  State<PaperDatesCard> createState() => _PaperDatesCardState();
}

class _PaperDatesCardState extends State<PaperDatesCard> {
  /*
    ── Owned here, so the action key has somewhere to go ────────────────────

    Two focus nodes for the two typed boxes. Left alone the keyboard's corner
    key is a tick, which puts the keyboard away and leaves somebody looking at
    a field they then have to reach past it to tap. Same fix as the split
    fields on a subscription — see `TextBox.action`.
  */
  final FocusNode _authority = FocusNode();
  final FocusNode _storedAt = FocusNode();

  /// On the row those two boxes sit in, so tapping either can lift it clear
  /// of the keyboard.
  final GlobalKey _typedRow = GlobalKey();

  /*
    ── A field somebody TAPPED, not one the app chose ──────────────────────

    These two sit at the foot of the card, and the keyboard opens over the
    bottom half of the screen — so tapping either put the cursor in a box
    behind it.

    Flutter scrolls the caret into view by itself, which is enough on a card
    with room underneath and not enough on one that ends where the fields do.
    Asking again, once the keyboard has finished arriving, is what makes it
    reliable on both. `focusThenReveal` re-requests a focus the node already
    has, which is a no-op.
  */
  @override
  void initState() {
    super.initState();

    for (final node in [_authority, _storedAt]) {
      node.addListener(() {
        if (node.hasFocus && mounted) {
          focusThenReveal(context, focus: node, at: _typedRow);
        }
      });
    }
  }

  @override
  void dispose() {
    _authority.dispose();
    _storedAt.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool expires}) async {
    final now = DateTime.now();
    final current =
        parseDate(expires ? widget.draft.expiresOn : widget.draft.issuedOn);

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

    if (expires) {
      widget.draft.expiresOn = iso;
    } else {
      widget.draft.issuedOn = iso;
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SheetCard(
      title: widget.title,
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
                    value: widget.draft.expiresOn,
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
                    value: widget.draft.issuedOn,
                    onTap: () => _pickDate(expires: false),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          key: _typedRow,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Issued by'),
                  TextBox(
                    initial: widget.draft.authority,
                    focus: _authority,
                    hint: 'Optional',
                    action: TextInputAction.next,
                    onSubmitted: _storedAt.requestFocus,
                    onChanged: (v) {
                      widget.draft.authority = v;
                      widget.onChanged();
                    },
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
                    initial: widget.draft.storedAt,
                    focus: _storedAt,
                    hint: 'Fireproof box...',
                    // The last box on the card keeps the tick: there is
                    // genuinely nothing after it.
                    action: TextInputAction.done,
                    onSubmitted: _storedAt.unfocus,
                    onChanged: (v) {
                      widget.draft.storedAt = v;
                      widget.onChanged();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/* -------------------------------------------------------------- warning */

/// How long before the expiry to say something, and anything worth noting.
class PaperWarningCard extends StatefulWidget {
  const PaperWarningCard({
    required this.draft,
    required this.onChanged,
    this.title = 'How much warning',
    super.key,
  });

  final PaperDraft draft;
  final VoidCallback onChanged;
  final String title;

  @override
  State<PaperWarningCard> createState() => _PaperWarningCardState();
}

class _PaperWarningCardState extends State<PaperWarningCard> {
  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    final lead = leadDaysFor(widget.draft.kind, widget.draft.leadDays);

    return SheetCard(
      title: widget.title,
      children: [
        SegRow<int>(
          value: lead,
          options: _leadChoices,
          onPick: (v) {
            /*
              Choosing the kind's own number means "follow the kind", not
              "override it with the same value". Otherwise correcting a
              passport to an ID card afterwards would leave it on eight months
              — a number nobody chose, silently kept.
            */
            widget.draft.leadDays =
                v == defaultLeadDays[widget.draft.kind] ? null : v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        Text(
          leadExplanation(widget.draft),
          style: TextStyle(
              fontFamily: fontBody, fontSize: 13, height: 1.45, color: c.muted),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Notes'),
        TextBox(
          initial: widget.draft.notes,
          hint: 'Optional',
          lines: 4,
          onChanged: (v) => widget.draft.notes = v,
        ),
      ],
    );
  }
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
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(
                color: on ? c.washGoldLine : Colors.transparent,
                width: on ? 1.5 : 1),
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
                    const SizedBox(height: 5),
                    label,
                  ],
                ),
        ),
      ),
    );
  }
}
