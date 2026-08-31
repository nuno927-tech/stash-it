/// The pieces every product sheet is built from.
///
/// ── One set, three records ────────────────────────────────────────────────
/// An item, a document and a subscription are different things with the same
/// shape of question behind them: what is it, is it a problem, how long have I
/// got, and what are the details. Three sheets answering that three different
/// ways would be three chances for one of them to drift — a heading at 25pt on
/// one screen and 22 on another, a countdown reading "days left" here and "d"
/// there.
///
/// So the shape lives here and the three sheets supply the content. What each
/// one keeps for itself is the bit that is genuinely its own: an item's
/// photograph and cover schedule, a document's promise about scans, a
/// subscription's next charge.
library;

import 'package:flutter/material.dart';

import 'status_pill.dart';
import 'theme.dart';

/// The face at the top: a photograph, a glyph, a logo.
///
/// Always the same height and inset, whatever is inside it, so three sheets
/// opened one after another do not each start at a different place.
class ViewFace extends StatelessWidget {
  const ViewFace({required this.child, this.height = 150, super.key});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      decoration: BoxDecoration(
        color: c.slate800,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: Center(child: child),
    );
  }
}

/// The name, what kind of thing it is, and the two-part answer underneath.
///
/// ── The pill and the number are a pair ────────────────────────────────────
/// The state in words and the count in digits answer different questions —
/// "is this a problem" and "how long have I got". Somebody scanning wants the
/// first; somebody deciding whether to act wants the second. Together on one
/// line they read as one statement rather than as two facts stacked up.
///
/// A null [count] draws no number at all. A lifetime warranty, a document with
/// no expiry and a subscription that was cancelled all have nothing to count,
/// and printing a zero would be the screen inventing a measurement.
class ViewHeadline extends StatelessWidget {
  const ViewHeadline({
    required this.title,
    required this.status,
    required this.statusWord,
    this.subtitle,
    this.count,
    this.countUnit = 'left',
    super.key,
  });

  final String title;
  final String? subtitle;
  final StashStatus status;
  final String statusWord;

  /// Days. Negative or null draws nothing.
  final int? count;
  final String countUnit;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final n = count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 25,
              height: 1.12,
              letterSpacing: -0.6,
              color: c.text,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13,
                color: c.muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(status: status, label: statusWord),
              const Spacer(),
              if (n != null && n >= 0) ...[
                Text(
                  '$n',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w200,
                    fontSize: 34,
                    height: 1,
                    letterSpacing: -1,
                    color: c.text,
                  ),
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${n == 1 ? 'day' : 'days'} $countUnit',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11.5,
                      color: c.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A section heading: small, quiet, identical on every block of every sheet.
class ViewLabel extends StatelessWidget {
  const ViewLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontFamily: fontBody,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: StashColors.of(context).muted,
        ),
      );
}

/// The details, as a grid of cells rather than a column of rows.
///
/// ── Why not a label column ────────────────────────────────────────────────
/// These screens were `Brand | Bosch` on one line, `Model | …` on the next,
/// with a fixed label column holding the left third of the screen empty. Six
/// facts filled a viewport and none of them was easier to find for it.
///
/// Two per line, label above value, so the eye scans a block rather than
/// tracking across a gap. A fact with nothing in it is not drawn — a cell
/// reading "Serial —" is a row about an absence.
class ViewCells extends StatelessWidget {
  const ViewCells({required this.label, required this.cells, super.key});

  final String label;
  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ViewLabel(label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, value) in cells)
                _Cell(label: name, value: value),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    final full = MediaQuery.of(context).size.width - 44;

    return ConstrainedBox(
      /*
        Two per line, and a long serial takes the whole width rather than being
        cut in half to keep the grid tidy.

        The maximum matters as much as the minimum. Without it a value with no
        spaces in it — which is exactly what a serial number is — lays out at
        its natural width and paints off the edge of the screen. With it, the
        text wraps instead, which is the right answer here: a serial is the one
        field somebody needs to read in full, so it must not be truncated.
      */
      constraints: BoxConstraints(minWidth: full / 2, maxWidth: full),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
        decoration: BoxDecoration(
          color: c.slate800,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Free text, in a panel so it reads as somebody's words rather than a field.
class ViewNote extends StatelessWidget {
  const ViewNote({required this.text, this.label = 'Notes', super.key});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ViewLabel(label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: c.slate800,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.line),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13,
                height: 1.5,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit wide, Send beside it, Delete quiet underneath.
///
/// ── The three are not equals ──────────────────────────────────────────────
/// Three buttons of the same weight would make deleting as easy to hit as
/// editing, on a sheet somebody opened in order to read something. Edit is
/// what most visits end in, Send is occasional, and Delete is rare and
/// irreversible-feeling even though the bin catches it.
class ViewFooter extends StatelessWidget {
  const ViewFooter({
    required this.onEdit,
    required this.onDelete,
    required this.deleteLabel,
    this.onSend,
    super.key,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String deleteLabel;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: c.slate900,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.gold,
                      foregroundColor: c.onGold,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                    child: Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: c.onGold,
                      ),
                    ),
                  ),
                ),
                if (onSend != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: c.slate800,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.line),
                    ),
                    child: IconButton(
                      tooltip: 'Send to someone',
                      icon: Icon(Icons.ios_share, size: 19, color: c.text),
                      onPressed: onSend,
                    ),
                  ),
                ],
              ],
            ),
            TextButton(
              onPressed: onDelete,
              child: Text(
                deleteLabel,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 12.5,
                  color: c.ember,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
