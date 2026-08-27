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
  if (status == StashStatus.settled || status == StashStatus.unknown) return null;

  final (_, wash) = statusInk(c, status);

  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [wash, wash.withValues(alpha: 0)],
    stops: const [0, 0.55],
  );
}

/// The word, on its own tint.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, required this.label, super.key});

  final StashStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final (ink, wash) = statusInk(c, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        // The unknown state gets the muted ink on a plain recess: it is a
        // statement about the record being incomplete, not about the thing
        // being in trouble, and a coloured pill would say otherwise.
        color: status == StashStatus.unknown ? c.field : wash,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: fontBody,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: ink,
        ),
      ),
    );
  }
}
