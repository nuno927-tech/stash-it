/// The furniture every step-by-step sheet is built from.
///
/// One rail, one question, one footer. They were written inside
/// `item_wizard_sheet.dart` when items were the only thing added a question at
/// a time; subscriptions now are too, and a second copy of a footer is a second
/// place to fix the next time a label is cut off — which has already happened
/// once to this exact row.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Segments that fill as you go.
///
/// Not a dot per step: a rail says how much is left in a shape somebody reads
/// without counting.
class WizardRail extends StatelessWidget {
  const WizardRail({
    required this.steps,
    required this.at,
    required this.c,
    super.key,
  });

  final int steps;

  /// Zero-based. Everything up to and including it is lit.
  final int at;

  final StashColors c;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
        child: Row(
          children: [
            for (var i = 0; i < steps; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= at ? c.gold : c.slate600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i != steps - 1) const SizedBox(width: 5),
            ],
          ],
        ),
      );
}

/// One question: the words, and whatever answers it.
class WizardAsk extends StatelessWidget {
  const WizardAsk({
    required this.question,
    required this.hint,
    required this.answer,
    super.key,
  });

  final String question;
  final String hint;

  /// Whatever answers it — a field, a row of chips, or a whole card off the
  /// long form.
  ///
  /// Named `answer` rather than `child` on purpose: this one sits between the
  /// question and the way past it, and a name that says what it holds is worth
  /// more than one that says where it goes.
  final Widget answer;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Scrolls, because a step can be taller than what the keyboard leaves.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 25,
              height: 1.15,
              letterSpacing: -0.7,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 13.5,
              height: 1.5,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 24),
          answer,
        ],
      ),
    );
  }
}

/// The way on, and the quiet way out beside it.
class WizardFooter extends StatelessWidget {
  const WizardFooter({
    required this.c,
    required this.last,
    required this.ready,
    required this.saving,
    required this.onNext,
    required this.lastLabel,
    required this.quietLabel,
    required this.onQuiet,
    super.key,
  });

  final StashColors c;
  final bool last;

  /// Whether the one required answer is in. The gold button is dead until it
  /// is, because a wizard that lets you walk past the name refuses to save five
  /// screens later.
  final bool ready;

  final bool saving;
  final VoidCallback onNext;

  /// What the gold button says on the final step — "Save item", "Save
  /// subscription". Everywhere before it, "Next".
  final String lastLabel;

  /// "Use the full form instead" on the first screen, "Save now" after it.
  final String quietLabel;

  /// Null hides the quiet button — on the last screen, where the gold one
  /// already says save, and before there is anything to save.
  final VoidCallback? onQuiet;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
        child: Row(
          children: [
            /*
              ── Expanded, and no Spacer beside it ─────────────────────────────

              This was `Flexible` AND a `Spacer`, which is two things asking for
              the same leftover width. The Spacer has flex 1 and always takes
              what it asks for; Flexible only takes what its child needs and
              gives up the rest — so the label was squeezed to whatever the
              Spacer left and ellipsised to "Use the full form in…".

              One flexible child, not two. The button takes the whole remaining
              width and its text sits at the left of it, which puts the words
              where a Spacer would have put the gap anyway.

              "Save now" rather than "Skip", for the other slot: skip says the
              question was a step you got out of, save says the thing exists —
              which is true from the moment it has a name.
            */
            if (onQuiet != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onQuiet,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      quietLabel,
                      maxLines: 1,
                      // A backstop, not the plan. At 13pt the longest label is
                      // comfortably inside what is left beside the gold button
                      // on a 360dp phone.
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 13,
                        color: c.muted,
                      ),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: saving || !ready ? null : onNext,
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                disabledBackgroundColor: c.slate600,
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
              child: Text(
                saving ? 'Saving' : (last ? lastLabel : 'Next'),
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ready ? c.onGold : c.muted,
                ),
              ),
            ),
          ],
        ),
      );
}
