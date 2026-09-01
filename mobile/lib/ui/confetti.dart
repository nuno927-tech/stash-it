/// Twenty-six pieces of paper, falling once.
///
/// Ported from the `.confetti` rules in app.css. It exists for exactly one
/// moment — the tenth tap on the Settings heading — and it is the only purely
/// decorative thing in the app.
///
/// ── Fixed positions, not random ones ──────────────────────────────────────
/// The columns and delays are worked out from the index rather than from a
/// random number generator. Random ones would be recomputed on every rebuild
/// and the whole shower would twitch; deciding once is the cheapest way to say
/// "this is a thing that happened, not a thing that is happening".
///
/// ── And it obeys reduced motion by not existing ───────────────────────────
/// Everything else in the app degrades to a still version when somebody has
/// asked their phone to stop things moving. This has nothing underneath the
/// movement, so the honest degradation is nothing at all.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Drops confetti over the whole app, once. Removes itself when it lands.
void dropConfetti(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;

  // The root overlay, the same one the album's sheet is pushed onto — see the
  // note on `showScoutAlbum`. Inserting into a nearer one would put the paper
  // behind the sheet instead of over it.
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _Confetti(onDone: () => entry.remove()),
  );

  overlay.insert(entry);
}

class _Confetti extends StatefulWidget {
  const _Confetti({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti>
    with SingleTickerProviderStateMixin {
  static const int _count = 26;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward().then((_) => widget.onDone());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final size = MediaQuery.of(context).size;

    // Four tones, cycling — the brand colour and the three warranty states. A
    // shower in one colour reads as a glitch rather than as a celebration.
    final tones = [c.gold, c.moss, c.honey, c.ember];

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          children: [
            for (var i = 0; i < _count; i++) _piece(i, size, tones[i % 4]),
          ],
        ),
      ),
    );
  }

  Widget _piece(int i, Size size, Color tone) {
    // 37 is coprime with 100, so stepping by it walks the whole width before
    // repeating a column — an even spread from arithmetic rather than luck.
    final left = ((i * 37) % 100) / 100 * size.width;
    final delay = (i % 9) * 0.14 / 2.6;
    final drift = ((i % 5) - 2) * 24.0;

    final t = ((_c.value - delay) / (1 - delay)).clamp(0.0, 1.0);
    if (t == 0) return const SizedBox.shrink();

    // Fast then slowing, which is a piece of paper rather than a stone.
    final fall = Curves.easeOutCubic.transform(t);

    return Positioned(
      left: left + drift * fall,
      top: -14 + fall * (size.height + 40),
      child: Opacity(
        // Fading only at the end: a piece that starts translucent looks like a
        // rendering mistake, and one that ends solid looks like litter.
        opacity: (1 - math.pow(t, 4)).toDouble().clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: fall * 520 * math.pi / 180,
          child: Container(
            width: 8,
            height: 12,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
