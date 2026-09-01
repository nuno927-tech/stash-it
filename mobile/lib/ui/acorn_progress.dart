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
  const Acorn({required this.color, this.size = 24, super.key});

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

/// How long the row takes to fill end to end, at its own steady rate.
///
/// ── The rate is the fix, not the duration ─────────────────────────────────
///
/// The acorns opened most of the way full, and the cause was not the
/// animation — it was that the animation had no speed limit.
///
/// `fraction` is driven by the file count, and on a small collection the very
/// first report is already most of the job: one file of two is 0.49, and one
/// of one is 0.94. Every step was then tweened over a fixed 320ms regardless
/// of how far it travelled, so a jump from nothing to seven acorns took
/// exactly as long as a jump of half an acorn — which is to say it was not a
/// jump anybody could see.
///
/// So the DISTANCE sets the duration now. Crossing the whole row always takes
/// this long, whatever the collection, and a big jump therefore sweeps through
/// every acorn on the way rather than teleporting past them.
const Duration acornSweep = Duration(milliseconds: 1100);

/// A row of acorns that fill, with the stage said underneath.
class AcornProgress extends StatefulWidget {
  const AcornProgress({required this.progress, this.count = 8, super.key});

  final BackupProgress progress;

  /// How many acorns the row holds. Eight fits a sheet at a readable size.
  final int count;

  @override
  State<AcornProgress> createState() => _AcornProgressState();
}

class _AcornProgressState extends State<AcornProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this);

  /// What is on screen. Starts empty, and only ever moves at the rate above.
  Animation<double> _shown = const AlwaysStoppedAnimation(0);

  /// Where the last move was heading, so the next one starts from there rather
  /// than from whatever the work has since reported.
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _driveTo(widget.progress.fraction);
  }

  @override
  void didUpdateWidget(AcornProgress old) {
    super.didUpdateWidget(old);
    if (widget.progress.fraction != old.progress.fraction) {
      _driveTo(widget.progress.fraction);
    }
  }

  void _driveTo(double target) {
    final from = _sweep.isAnimating ? _shown.value : _to;
    final distance = (target - from).abs();
    if (distance == 0) return;

    _to = target;

    /*
      Proportional, with a floor.

      Without the floor a run of tiny steps — one file in forty — would each
      get a few milliseconds and the row would flicker rather than move. Ninety
      is short enough to keep up with fast work and long enough to be a
      movement rather than a jump.
    */
    _sweep.duration = Duration(
      milliseconds: (acornSweep.inMilliseconds * distance)
          .round()
          .clamp(90, acornSweep.inMilliseconds),
    );

    _shown = Tween<double>(begin: from, end: target).animate(
      CurvedAnimation(parent: _sweep, curve: Curves.easeOut),
    );
    _sweep.forward(from: 0);
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── The OS setting wins ──────────────────────────────────────────────────

      "Remove animations" is not a taste preference — people turn it on for
      motion sickness and for vestibular disorders. A row of eight things
      filling smoothly is exactly what it means, so with it on the acorns
      simply report where the work is.

      Read in `build` so it takes effect the moment the setting changes.
    */
    final still = MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        final value = still ? widget.progress.fraction : _shown.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /*
              ── The row fills continuously, not in eighths ───────────────────

              Each acorn used to be on or off, so with eight of them the
              picture only changed every eighth of the job — long enough on a
              slow step to look stuck. The whole row is tweened instead: an
              acorn's share of the fraction decides how much of it is gold, and
              the one at the leading edge is part-filled while the work moves
              through it.

              One value drives both this and the bar below, so they cannot
              drift out of step.
            */
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.count; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _FillingAcorn(
                      // 0 for one not reached, 1 for one behind the edge, and
                      // the remainder for the one being worked through.
                      fill: (value * widget.count - i).clamp(0, 1),
                      lit: c.gold,
                      unlit: c.slate600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: c.slate600,
                valueColor: AlwaysStoppedAnimation<Color>(c.gold),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.progress.label,
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 12.5,
                color: c.muted,
              ),
            ),
          ],
        );
      },
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

  /*
    26 rather than 20.

    Eight acorns at 20 read as a dotted line — the shape only became an acorn
    if you went looking for it, which defeats the point of using one instead of
    a spinner. At 26 the cap and the stalk are legible at arm's length, and
    eight of them plus their padding still sit well inside a phone's width.
  */
  static const double _size = 26;

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
