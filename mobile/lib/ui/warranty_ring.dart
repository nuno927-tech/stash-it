/// The ring that goes round a photograph.
///
/// Ported from `src/components/WarrantyRing.tsx`. One arc per policy, the one
/// lapsing soonest outermost, drawn concentrically inward.
///
/// ── Why a ring and not a bar ──────────────────────────────────────────────
/// A ring holds something in the middle, which a 9px bar cannot, and on a list
/// row the thing in the middle is the photograph of the object. The state and
/// the picture occupy one piece of space instead of two.
///
/// ── Three numbers that have to agree ──────────────────────────────────────
/// The ring's diameter, its stroke, and the inset the photo is drawn at. They
/// are named rather than typed inline because the row shrank from 50 to 44 when
/// it stopped being a card, and a thumbnail still insetting for a 50px ring
/// would have put a photo corner over an arc.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/warranty.dart';
import '../models/types.dart';
import 'theme.dart';

/// Past this the arcs stop being countable, so the rest are not drawn and the
/// count is written on the corner instead.
const int maxRings = 4;

/// How much each inner ring steps in by.
const double ringStep = 4.5;

class WarrantyRing extends StatelessWidget {
  const WarrantyRing({
    required this.arcs,
    this.size = 44,
    this.stroke = 2.8,
    super.key,
  });

  final List<CoverageArc> arcs;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          arcs: arcs.take(maxRings).toList(),
          stroke: stroke,
          track: c.slate600,
          tone: (state) => switch (state) {
            WarrantyState.covered => c.moss,
            WarrantyState.endingSoon => c.honey,
            WarrantyState.expired => c.ember,
            WarrantyState.unknown => c.line,
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.arcs,
    required this.stroke,
    required this.track,
    required this.tone,
  });

  final List<CoverageArc> arcs;
  final double stroke;
  final Color track;
  final Color Function(WarrantyState) tone;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i < arcs.length; i++) {
      final radius = size.width / 2 - stroke / 2 - i * ringStep;
      if (radius <= 0) break;

      final rect = Rect.fromCircle(center: centre, radius: radius);

      // The empty track first. Without it a policy with two days left is a
      // three-degree tick floating in space, and the row reads as damaged
      // rather than as urgent.
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track,
      );

      final progress = arcs[i].progress.clamp(0.0, 1.0);
      if (progress <= 0) continue;

      canvas.drawArc(
        rect,
        // From the top, clockwise. Twelve o'clock is where every dial in the
        // world starts and this is not the place to be interesting.
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = tone(arcs[i].state),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.arcs.length != arcs.length ||
      old.stroke != stroke ||
      old.track != track;
}

/// The ring with the item's photograph inside it, and the policy count on the
/// corner when there is more than one.
///
/// The photo gives up whatever the extra rings take, and no more — computed
/// from the ring count rather than a size per count, because it has to match
/// the step the ring actually draws with.
class ItemArt extends StatelessWidget {
  const ItemArt({
    required this.item,
    required this.thumb,
    this.size = 44,
    this.stroke = 2.8,
    this.fallback,
    super.key,
  });

  final Item item;

  /// The decoded thumbnail, or null when there is none.
  final ImageProvider? thumb;

  final double size;
  final double stroke;

  /// What to draw when there is no photograph.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final arcs = coverageArcs(item);
    final policies = coveragesOf(item).length;

    final inset = stroke / 2 + 3 + (math.min(arcs.length, maxRings) - 1) * ringStep;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          WarrantyRing(arcs: arcs, size: size, stroke: stroke),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: ClipOval(
                child: Container(
                  color: c.slate700,
                  child: thumb == null
                      ? Center(child: fallback ?? Icon(Icons.inventory_2_outlined, size: size * 0.4, color: c.muted))
                      : Image(image: thumb!, fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          /*
            The count sits on the corner because the arcs stop being countable
            past three or so — and past four they are not all drawn, so the
            ring alone would understate an item with six.
          */
          if (policies > 1)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.slate600,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.slate800, width: 1.5),
                ),
                child: Text(
                  '$policies',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The countdown, drawn the same way everywhere it appears.
///
/// It used to be markup inside the item row while the dashboard wrote its own
/// version — so the same item read "5m" in a chip on one screen and "5 / months
/// left" on the other, and the number that mattered was the small one on the
/// screen you land on first. One widget, one answer.
class TimeLeft extends StatelessWidget {
  const TimeLeft({required this.item, super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final left = warrantyParts(item);

    final colour = switch (warrantyState(item)) {
      WarrantyState.covered => c.moss,
      WarrantyState.endingSoon => c.honey,
      WarrantyState.expired => c.ember,
      WarrantyState.unknown => c.muted,
    };

    // "Ended", "Today" and "2y 4m" are words, not a two-digit number, and at
    // 27px they crowd the item name off the row. Decided here rather than left
    // to the layout to guess from the content.
    final wordy = !RegExp(r'^\d+$').hasMatch(left.value);

    return SizedBox(
      width: 66,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          /*
            Cross-faded, in step with the pill on the other side of the row.

            The two say the same thing in different alphabets — "Lapsed" and
            a red number — so one of them snapping while the other eases makes
            the row look like it changed twice. 260ms is the pill's number,
            copied deliberately rather than chosen again.
          */
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            /*
              ── Weight, not just size ────────────────────────────────────────

              This was 200 — the thinnest weight Bricolage has — at 27px. Large
              and pale is a combination that reads as decorative: the number
              was the biggest thing on the row and still not the first thing
              seen, because a hairline stroke in moss green on a dark row has
              almost no contrast to carry that size.

              800 at the same size is the same information with something
              behind it. The unit under it stays light, which is what keeps the
              pair from becoming a block.
            */
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: wordy ? 17 : 27,
              letterSpacing: -1.2,
              height: 1.05,
              color: colour,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            child: Text(left.value, textAlign: TextAlign.right),
          ),
          const SizedBox(height: 3),
          Text(
            left.unit,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: fontBody,
              fontSize: 10.5,
              fontWeight: FontWeight.w300,
              color: c.muted,
            ),
          ),
        ],
      ),
    );
  }
}
