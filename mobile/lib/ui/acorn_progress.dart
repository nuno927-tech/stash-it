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
/// Ten acorns is a coarse readout: on a hundred files each one covers ten of
/// them and the picture sits still for a long time. The hairline underneath
/// moves continuously, so there is always something saying the app is alive
/// even when the count has not ticked over.
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
    final filled = (progress.fraction * count).floor().clamp(0, count);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                /*
                  Each one fades rather than switching on, and they are
                  staggered by their own position — so the row fills like
                  something being gathered rather than like a meter flicking
                  between two states.
                */
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 260 + i * 20),
                  curve: Curves.easeOut,
                  opacity: i < filled ? 1 : 0.22,
                  child: Acorn(color: i < filled ? c.gold : c.muted, size: 20),
                ),
              ),
          ],
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
