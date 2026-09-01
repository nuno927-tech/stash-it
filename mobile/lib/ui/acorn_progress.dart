/// The bar that plays while a backup is being made.
///
/// ── Acorns, because that is what Scout does with them ─────────────────────
/// He is drawn holding one on the launch screen and again on the lock screen —
/// the thing worth keeping, carried somewhere safe. A backup is the same idea
/// with the mascot taken out, so the row of acorns filling up is the app
/// saying what it is doing in its own vocabulary rather than borrowing a
/// system spinner.
///
/// ── And a bar as well as the acorns ───────────────────────────────────────
/// Eight acorns is a coarse readout on its own. They fill continuously rather
/// than one at a time — see `_FillingAcorn` — and the hairline underneath says
/// the same thing in a form that is easy to read at a glance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../logic/backup_progress.dart';
import 'theme.dart';

/// One acorn: cap, body, and the little stalk.
///
/// Inline rather than an asset, the same way `PaperGlyph` carries the document
/// marks — it is one path, it needs to take a colour at runtime, and a file in
/// `assets/` for it would be a build step for twelve lines of geometry.
const String _acornPath = '''
<path d="M6.2 8.4h11.6" />
<path d="M6.9 8.4c0-2.4 2.3-4.1 5.1-4.1s5.1 1.7 5.1 4.1" />
<path d="M12 4.3V2.6" />
<path d="M7.3 8.4c0 4.6 2.1 8.4 4.7 11 2.6-2.6 4.7-6.4 4.7-11" />
''';

class Acorn extends StatelessWidget {
  const Acorn({required this.color, this.size = 18, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    return SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"
     width="$size" height="$size" fill="none" stroke="$hex" stroke-width="1.7"
     stroke-linecap="round" stroke-linejoin="round">
$_acornPath
</svg>
''',
      width: size,
      height: size,
    );
  }
}

/// A row of acorns that fill, with the stage said underneath.
class AcornProgress extends StatelessWidget {
  const AcornProgress({required this.progress, this.count = 8, super.key});

  final BackupProgress progress;

  /// How many acorns the row holds. Eight fits a sheet at a readable size.
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /*
          ── The row fills continuously, not in eighths ───────────────────────

          Each acorn used to be on or off, so with eight of them the picture
          only changed every twelfth of the job — long enough on a slow step to
          look stuck. Now the whole row is tweened: an acorn's share of the
          fraction decides how much of it is gold, and the one at the leading
          edge is part-filled while the work moves through it.

          Tweened here rather than at each acorn so they cannot drift out of
          step with the bar underneath, which reads the same value.
        */
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.fraction),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          builder: (context, value, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _FillingAcorn(
                    // 0 for one not reached, 1 for one behind the edge, and
                    // the remainder for the one being worked through.
                    fill: (value * count - i).clamp(0, 1),
                    lit: c.gold,
                    unlit: c.slate600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // The continuous half. `TweenAnimationBuilder` rather than setting the
        // value straight, so a jump from one batch to the next slides.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.fraction),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: c.slate600,
              valueColor: AlwaysStoppedAnimation<Color>(c.gold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          progress.label,
          style: TextStyle(
            fontFamily: fontBody,
            fontSize: 12.5,
            color: c.muted,
          ),
        ),
      ],
    );
  }
}

/// One acorn, filled from the bottom up.
///
/// Two copies stacked: the unlit one always drawn, the gold one clipped to the
/// bottom [fill] of its height. Drawing it bottom-up rather than left-to-right
/// because an acorn is a container and that is how containers fill.
class _FillingAcorn extends StatelessWidget {
  const _FillingAcorn({
    required this.fill,
    required this.lit,
    required this.unlit,
  });

  /// 0..1.
  final double fill;
  final Color lit;
  final Color unlit;

  static const double _size = 20;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          Acorn(color: unlit, size: _size),
          if (fill > 0)
            ClipRect(
              clipper: _FromTheBottom(fill),
              child: Acorn(color: lit, size: _size),
            ),
        ],
      ),
    );
  }
}

class _FromTheBottom extends CustomClipper<Rect> {
  const _FromTheBottom(this.fill);

  final double fill;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        0,
        size.height * (1 - fill),
        size.width,
        size.height,
      );

  @override
  bool shouldReclip(_FromTheBottom old) => old.fill != fill;
}
