/// The mark that says this copy is paid for.
///
/// ── Why it borrows the chip, rather than inventing a badge ────────────────
/// Wash fill, `washGoldLine` hairline, gold text: that is exactly a lit filter
/// chip on the Items tab, and exactly the Go Pro card this replaces. Reusing
/// the language means the badge and the thing it commemorates look related, and
/// it introduces no colour the app did not already have.
///
/// A solid gold fill was the other candidate and lost on one point: the
/// wordmark already spends gold on "it", and a filled pill two characters later
/// gives a three-word masthead two things to look at. The wash sits behind the
/// wordmark instead of competing with it.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// PRO, as a chip.
///
/// [scale] multiplies the whole thing, so the masthead and a settings card can
/// share one widget without either hard-coding sizes the other has to match.
class ProBadge extends StatelessWidget {
  const ProBadge({this.scale = 1, super.key});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2.5 * scale),
      decoration: BoxDecoration(
        color: c.washGold,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.washGoldLine),
      ),
      child: Text(
        'PRO',
        style: TextStyle(
          fontFamily: fontBody,
          fontSize: 10.5 * scale,
          fontWeight: FontWeight.w600,

          /*
            Tracked out, and it is doing real work at this size.

            Three capitals at ten and a half points with default spacing read as
            one dense shape rather than a word. The extra letter-spacing is what
            makes it legible small, which is the only size it is ever drawn at.
          */
          letterSpacing: 0.9 * scale,
          color: c.gold,
          height: 1.25,
        ),
      ),
    );
  }
}
