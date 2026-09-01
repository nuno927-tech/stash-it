/// The year ahead, as a line rather than bars.
///
/// ── Why the bars went ─────────────────────────────────────────────────────
/// Bars compare quantities that have nothing to do with each other — sales by
/// region, votes by party. These six months are the same quantity over time,
/// and the thing worth seeing is not how tall November is but that it **rises
/// into November and comes back down**. A line says that; six separate columns
/// make the reader do it.
///
/// ── And why there is an average on it ─────────────────────────────────────
/// The mean is there to be disagreed with. The gap between the dashed line and
/// the peak is the difference between what subscriptions cost you and what
/// actually leaves your account in November — which is the whole reason
/// anybody looks at this.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/subscriptions.dart';
import 'theme.dart';

class SpendLine extends StatelessWidget {
  const SpendLine({required this.spend, super.key});

  final List<MonthSpend> spend;

  static const List<String> _short = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    if (spend.isEmpty) return const SizedBox.shrink();

    final peak = heaviest(spend);
    final mean = spend.fold<int>(0, (n, m) => n + m.cents) / spend.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 26, 14, 12),
      decoration: BoxDecoration(
        color: c.slate700,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: cardShadow(c,
            dark: Theme.of(context).brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 128,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LinePainter(
                spend: spend,
                mean: mean,
                gold: c.gold,
                line: c.line,
                muted: c.muted,
                surface: c.slate700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < spend.length; i++)
                Expanded(
                  child: Text(
                    _short[spend[i].month - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      // This month in gold, the rest muted. The line starts
                      // where you are standing, and saying so costs a colour.
                      color: i == 0 ? c.gold : c.muted,
                    ),
                  ),
                ),
            ],
          ),
          if (peak != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_month(peak.month)} is the heavy one: '
              '\$${(peak.cents / 100).toStringAsFixed(2)}.',
              style: TextStyle(
                  fontFamily: fontBody, fontSize: 11.5, color: c.muted),
            ),
          ],
        ],
      ),
    );
  }

  static String _month(int m) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][m - 1];
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.spend,
    required this.mean,
    required this.gold,
    required this.line,
    required this.muted,
    required this.surface,
  });

  final List<MonthSpend> spend;
  final double mean;
  final Color gold;
  final Color line;
  final Color muted;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    /*
      The scale runs from zero to a little above the peak, not from the lowest
      month to the highest.

      Starting the axis at the minimum is the classic way to make a 4% rise
      look like a cliff — and this chart's whole job is to say how much of your
      money moves, so exaggerating it would be lying in the app's own favour.
      The headroom is for the value labels, which sit above their points.
    */
    final most = spend.fold<int>(0, (n, m) => math.max(n, m.cents));
    final top = most == 0 ? 1.0 : most * 1.12;

    const labelRoom = 16.0;
    final h = size.height - labelRoom;
    final step = spend.length == 1 ? 0.0 : size.width / (spend.length - 1);

    Offset at(int i) => Offset(
          spend.length == 1 ? size.width / 2 : i * step,
          labelRoom + h - (spend[i].cents / top) * h,
        );

    final points = [for (var i = 0; i < spend.length; i++) at(i)];

    // The floor, so the area has an edge to sit on rather than fading into the
    // bottom of the card.
    canvas.drawLine(
      Offset(0, labelRoom + h),
      Offset(size.width, labelRoom + h),
      Paint()
        ..color = line
        ..strokeWidth = 1,
    );

    /*
      The average, dashed.

      Dashed rather than solid because it is a derived number, not a measured
      one — a solid second line reads as a second series, and somebody would
      reasonably ask which months it belongs to.
    */
    final meanY = labelRoom + h - (mean / top) * h;
    final dash = Paint()
      ..color = gold.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, meanY), Offset(x + 3, meanY), dash);
    }

    if (points.length > 1) {
      // Gold at the curve, nothing at the baseline. It gives the line a body
      // without becoming a second solid shape competing with it.
      final area = Path()..moveTo(points.first.dx, labelRoom + h);
      for (final p in points) {
        area.lineTo(p.dx, p.dy);
      }
      area
        ..lineTo(points.last.dx, labelRoom + h)
        ..close();

      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Heavier than it was. At 22% the fill was so close to the card
            // that the curve looked unattached to anything, and the area is
            // what turns a line into a quantity.
            colors: [
              gold.withValues(alpha: 0.42),
              gold.withValues(alpha: 0.04)
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );

      final stroke = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        /*
          Rounded through the points rather than straight between them.

          The control points sit half a step either side at the neighbours'
          heights, which is a Catmull-Rom curve in the only form Flutter's Path
          offers — and it will not overshoot below zero on a month with nothing
          in it, which a naive spline would.
        */
        final a = points[i - 1];
        final b = points[i];
        final mid = (a.dx + b.dx) / 2;
        stroke.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
      }

      canvas.drawPath(
        stroke,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = gold,
      );
    }

    // The points, and the figure above each one.
    for (var i = 0; i < points.length; i++) {
      final p = points[i];

      // Solid, not ringed. A hollow dot on a 2px line is three concentric
      // strokes at the exact place the eye is meant to read one value.
      canvas.drawCircle(p, 3.6, Paint()..color = gold);

      final label = TextPainter(
        text: TextSpan(
          text: '\$${(spend[i].cents / 100).toStringAsFixed(2)}',
          style: TextStyle(
            fontFamily: fontBody,
            fontSize: 10.5,
            // This month named in gold, the rest quiet — the same rule as the
            // month labels underneath.
            color: i == 0 ? gold : muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // Clamped to the card, so the first and last figures do not hang off the
      // edge of a chart that is exactly as wide as its data.
      final x = (p.dx - label.width / 2).clamp(0.0, size.width - label.width);
      label.paint(canvas, Offset(x, p.dy - 16));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.spend != spend || old.mean != mean;
}
