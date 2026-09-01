/// What a row is telling you, said in colour and in a word.
///
/// ── Why a pill, when the ring already said it ─────────────────────────────
/// Every list in the app carried its state as a coloured ring around a 38px
/// mark. It is correct, it is quiet, and at arm's length on a phone it is a
/// thin arc of colour that has to be looked *at* rather than seen. Somebody
/// scanning a list of forty items for the two that need something was reading
/// dates.
///
/// Two changes, together:
///
///   The pill names the state. Colour alone is a code you have to learn, and
///   about one man in twelve cannot read the red-green half of it at all. A
///   word costs sixty pixels and removes both problems.
///
///   The row is washed from the leading edge. Not a fill — a fill turns a list
///   into a stack of coloured blocks and the eye stops reading any of them.
///   A wash that fades out by the middle of the row leaves the text on the
///   card's own colour, where it is legible, and puts the signal exactly where
///   the eye enters the row.
///
/// The wash is deliberately absent for the settled state. A list where every
/// row is tinted is a list with no tint: green on thirty-eight rows is not
/// good news, it is wallpaper. Only the two states that want something from
/// you get one.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The three states every list in this app sorts by, whatever it holds.
///
/// Items call them covered/ending/expired, documents call them
/// valid/renew/expired and subscriptions have their own word for due — but the
/// question underneath is the same one, and drawing it three ways would be
/// three chances to disagree about what amber means.
enum StashStatus {
  /// Nothing to do. Draws no wash.
  settled,

  /// Wants attention soon.
  soon,

  /// Wanted attention already.
  overdue,

  /// Nothing to count down to. Not a failure and not urgent — see the note on
  /// sorting in items_tab.dart.
  unknown,
}

/// The ink and the wash for a state.
(Color, Color) statusInk(StashColors c, StashStatus status) => switch (status) {
      StashStatus.settled => (c.moss, c.washMoss),
      StashStatus.soon => (c.honey, c.washHoney),
      StashStatus.overdue => (c.ember, c.washEmber),
      StashStatus.unknown => (c.muted, Colors.transparent),
    };

/// The gradient behind a row, or null when the state is not worth tinting.
///
/// Fades to nothing by 55% of the width. Any further and the text sits on
/// colour; any less and it reads as a stripe rather than as the row being lit.
Gradient? statusWash(StashColors c, StashStatus status) {
  if (status == StashStatus.settled || status == StashStatus.unknown) {
    return null;
  }

  final (_, wash) = statusInk(c, status);

  /*
    ── Stronger, and reaching further across the row ───────────────────────

    It started at the wash's own alpha and was gone by 55% of the width, which
    on a dark row was close to nothing: the state was carried almost entirely
    by the pill, and the shading it was meant to reinforce read as a rendering
    artefact more than a signal.

    Half again as strong at the left edge, fading out at 82%. Still a gradient
    rather than a fill — four solid rows together stop reading as urgent and
    start reading as the background, which is the note on the row builders and
    the reason this is a wash at all.

    Changed here rather than on the `wash*` tokens deliberately. Those are
    shared with the status pill, and a pill is small and already outlined; it
    does not need what a full-width row needs.
  */
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      wash.withValues(alpha: (wash.a * 1.55).clamp(0, 1)),
      wash.withValues(alpha: 0),
    ],
    stops: const [0, 0.82],
  );
}

/*
  ── The wash for a row a filter picked out ──────────────────────────────────

  Gold, matching the dot on the dashboard figure that sends people here. The
  two ends of that journey are one gesture — tap a gold dot, land on gold rows
  — and a different colour at the far end would make it a coincidence rather
  than an answer.

  Here rather than in items_tab so it is built the same way as `statusWash`:
  same direction, same stops, same fade. They sit in the same slot on the same
  rows and the only thing that should differ between them is the hue.
*/
Gradient filterWash(StashColors c) => LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        c.washGold.withValues(alpha: (c.washGold.a * 1.55).clamp(0, 1)),
        c.washGold.withValues(alpha: 0),
      ],
      stops: const [0, 0.82],
    );

/// The word, on its own tint.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, required this.label, super.key});

  final StashStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final (ink, wash) = statusInk(c, status);

    /*
      ── Both the wash and the ink cross-fade ──────────────────────────────

      A pill changes colour when the thing under it changes state — a filter
      switching the list, or cover running out while the app is open. It used
      to repaint: green one frame, amber the next, with nothing to say the two
      were the same pill rather than a different row scrolling into place.

      The text colour has to move with the background or the pair goes briefly
      illegible mid-fade — amber ink on a green wash is a real frame if only
      one of them is animating.

      `AnimatedContainer` and `AnimatedDefaultTextStyle` both no-op when the
      OS asks for no animation, so this needs no guard of its own.
    */
    const swap = Duration(milliseconds: 260);

    return AnimatedContainer(
      duration: swap,
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        // The unknown state gets the muted ink on a plain recess: it is a
        // statement about the record being incomplete, not about the thing
        // being in trouble, and a coloured pill would say otherwise.
        color: status == StashStatus.unknown ? c.field : wash,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: AnimatedDefaultTextStyle(
        duration: swap,
        curve: Curves.easeOut,
        style: TextStyle(
          fontFamily: fontBody,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: ink,
        ),
        child: Text(label),
      ),
    );
  }
}
