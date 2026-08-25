/// The small pieces every tab uses.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/timeline.dart';
import '../logic/warranty.dart';
import 'feedback.dart';
import 'scout.dart';
import 'theme.dart';

/// One number with a word under it, as `.coverstat` draws it.
///
/// ── The number is LIGHT, not bold ─────────────────────────────────────────
/// 24px of the display face at weight 200. That looks backwards for a figure
/// somebody is meant to read first, and it is the reason the row works: four
/// bold numbers in a row compete with each other and with the ring above them,
/// and the eye lands nowhere. Thin and large reads as a quantity; heavy and
/// large reads as a warning, which only one of these is.
///
/// The colour lives in the dot beside the label rather than in the digits, for
/// the same reason.
class Figure extends StatelessWidget {
  const Figure({
    required this.value,
    required this.label,
    this.onTap,
    this.tone,
    super.key,
  });

  final String value;
  final String label;

  /// Null when there is nothing to show. A figure that navigates to an empty
  /// screen is worse than one that does not respond.
  final VoidCallback? onTap;

  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              feedback(Cue.tap);
              onTap!();
            },
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w200,
                fontSize: 24,
                letterSpacing: -0.72,
                height: 1,
                color: c.text,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (tone != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                      color: c.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The row those figures sit in: equal columns, with a rule above.
///
/// A grid rather than a `Wrap`, because four equal columns is what makes them
/// scan as one measurement broken into parts. Wrapped, they read as four
/// separate facts that happen to be near each other — which is how the port had
/// them, and why they stopped looking like the PWA's.
class FigureRow extends StatelessWidget {
  const FigureRow(this.figures, {super.key});

  final List<Widget> figures;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: StashColors.of(context).slate600)),
      ),
      child: Row(
        children: [for (final f in figures) Expanded(child: f)],
      ),
    );
  }
}

/// A heading, in sentence case rather than shouted.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The heading at the top of a tab.
///
/// ── Every screen says what it is ──────────────────────────────────────────
/// The PWA gives each tab an `.apphead` with the screen's name in the display
/// face, and the port had none of them: five screens that opened straight into
/// a list. On a phone that is a real loss rather than a cosmetic one — the
/// bottom bar shows five icons and a small label, and after a swipe between
/// tabs the only thing telling you where you landed is the content.
///
/// Home is the exception and takes the wordmark instead, because a masthead
/// saying "Home" would be the app introducing itself as a navigation state.
class TabTitle extends StatelessWidget {
  const TabTitle(this.title, {this.pose, this.trailing, super.key});

  final String title;

  /// Scout, small, at the right-hand end. The PWA gives every tab head one —
  /// `.subshead`, `.masthead` — doing the job that screen is for.
  final ScoutPose? pose;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              // The same style as the wordmark, deliberately. These are all
              // mastheads — the app naming the screen you are on — and a
              // heading that changes face between tabs reads as two apps.
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (pose != null)
            Scout(pose: pose!, height: 74, motion: const [ScoutMotion.breathe]),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// "Stash **it**" — the masthead, with the second word in gold.
///
/// One widget rather than a string, because the colour change mid-phrase is
/// the wordmark. Written as `it` in gold everywhere it appears, including the
/// PWA's `.apptitle span`.
class Wordmark extends StatelessWidget {
  const Wordmark({this.fontSize = 27, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.headlineSmall!.copyWith(fontSize: fontSize);

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Stash '),
          TextSpan(
            text: 'it',
            style: base.copyWith(color: StashColors.of(context).gold),
          ),
        ],
      ),
    );
  }
}

/// What an empty list should say, which is never nothing.
class Blank extends StatelessWidget {
  const Blank(this.message, {this.pose, this.poseHeight = 170, super.key});

  final String message;

  /*
    ── Scout stands on the empty screens, and this is not decoration ─────────

    An empty list is the least informative thing an app can show, and it is
    also the first thing a new user sees on four of the five tabs. The PWA puts
    a pose on every one of them for that reason — floating, with a shadow, so
    the screen has a subject rather than a paragraph in the middle of nothing.

    Which pose is not arbitrary either: the one holding a receipt on Items,
    the one holding up a month on Subscriptions, the one with a clipboard on
    Documents. He is doing the job the screen is for.
  */
  final ScoutPose? pose;
  final double poseHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pose != null) ...[
              Scout(
                pose: pose!,
                height: poseHeight,
                motion: const [ScoutMotion.float],
                shadow: true,
              ),
              const SizedBox(height: 28),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// The colour a warranty state earns. Green, amber, red, grey.
Color toneOf(WarrantyState state, BuildContext context) => switch (state) {
      WarrantyState.covered => const Color(0xFF5FBF7E),
      WarrantyState.endingSoon => const Color(0xFFF2B33D),
      WarrantyState.expired => Theme.of(context).colorScheme.error,
      WarrantyState.unknown => Theme.of(context).disabledColor,
    };

/// A row from the merged timeline.
class TimelineTile extends StatelessWidget {
  const TimelineTile({required this.entry, super.key});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        entry.flagged ? Icons.error_outline : Icons.schedule,
        color: entry.flagged ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(entry.title),
      subtitle: Text(entry.detail),
      trailing: Text(
        whenLabelFor(entry),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

/// The ring: how much of what can run out still has not.
///
/// ── What it counts, and what it leaves out ────────────────────────────────
/// Warranties and documents. **Not subscriptions** — a subscription cannot
/// lapse, it renews, so counting nine of them as nine healthy units would make
/// the score rise when you take on a service and fall when you cancel one.
///
/// Undated records are not drawn and not in the divisor either. Including them
/// would mean the score DROPS when you add a record with a date missing, which
/// punishes the one behaviour the app wants.
class Ring extends StatelessWidget {
  const Ring({
    required this.inDate,
    required this.needsStarting,
    required this.lapsed,
    required this.percent,
    super.key,
  });

  final int inDate;
  final int needsStarting;
  final int lapsed;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 168,
      width: 168,
      child: CustomPaint(
        painter: _RingPainter(
          covered: inDate.toDouble(),
          soon: needsStarting.toDouble(),
          lapsed: lapsed.toDouble(),
          track: theme.colorScheme.surfaceContainerHighest,
          error: theme.colorScheme.error,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$percent%', style: theme.textTheme.headlineMedium),
              Text('in date', style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.covered,
    required this.soon,
    required this.lapsed,
    required this.track,
    required this.error,
  });

  final double covered;
  final double soon;
  final double lapsed;
  final Color track;
  final Color error;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Offset.zero & size;
    final circle = Rect.fromCircle(
      center: rect.center,
      radius: (math.min(size.width, size.height) - stroke) / 2,
    );

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;

    canvas.drawArc(circle, 0, math.pi * 2, false, base);

    final total = covered + soon + lapsed;
    if (total == 0) return;

    // Green, then amber, then red — worst last, so the eye lands on it as the
    // arc closes rather than meeting it first.
    var start = -math.pi / 2;
    for (final wedge in [
      (covered, const Color(0xFF5FBF7E)),
      (soon, const Color(0xFFF2B33D)),
      (lapsed, error),
    ]) {
      if (wedge.$1 == 0) continue;
      final sweep = (wedge.$1 / total) * math.pi * 2;
      canvas.drawArc(
        circle,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = wedge.$2,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.covered != covered || old.soon != soon || old.lapsed != lapsed;
}
