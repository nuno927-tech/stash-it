/// "Kettle moved to the bin. Undo."
///
/// ── Why this is not a `SnackBar` ──────────────────────────────────────────
/// Two reasons, and the first one is a bug.
///
/// **It would not go away.** A `SnackBar` starts its dismissal timer when its
/// entrance animation finishes, and this app keeps several animation
/// controllers repeating for ever — Scout breathes on every screen. The
/// messenger's queue never saw the settle it was waiting for, so the bar sat
/// there until it was tapped. Fighting that from the outside means either
/// stopping the mascot or reaching into the messenger, and both are worse than
/// owning the timer.
///
/// **And it cannot be put where it belongs.** A floating `SnackBar` spans the
/// width the `insetPadding` leaves it, centred — so under the "Stash it" pill,
/// which is the one control it must not cover, because the pill is exactly
/// where a thumb already is after a swipe.
///
/// So: an overlay entry with its own clock, sitting to the left of the button
/// on the same line as it.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Shows the bar, replacing any already on screen.
///
/// `onUndo` runs on the tap; the bar removes itself either way after five
/// seconds — long enough to notice and reach, short enough not to become
/// furniture.
void showUndo(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  _current?.dismiss();

  final overlay = Overlay.of(context);
  final entry = _UndoEntry(message: message, onUndo: onUndo);
  _current = entry;
  entry.insert(overlay);
}

_UndoEntry? _current;

class _UndoEntry {
  _UndoEntry({required this.message, required this.onUndo});

  final String message;
  final VoidCallback onUndo;

  OverlayEntry? _entry;
  Timer? _timer;

  void insert(OverlayState overlay) {
    _entry = OverlayEntry(
      builder: (context) => _Bar(
        message: message,
        onUndo: () {
          onUndo();
          dismiss();
        },
      ),
    );

    overlay.insert(_entry!);
    _timer = Timer(const Duration(seconds: 5), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    if (_current == this) _current = null;
  }
}

class _Bar extends StatefulWidget {
  const _Bar({required this.message, required this.onUndo});

  final String message;
  final VoidCallback onUndo;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 16,
      /*
        Clear of the button, not under it.

        The pill is about 165 wide at this type size and sits 16 from the right
        edge; leaving 190 puts this bar's right edge just short of it, on the
        same line. On a narrow phone the message ellipsises rather than the two
        overlapping — a truncated sentence is recoverable, a covered Undo is
        not.
      */
      right: 190,
      // The same 90 the button uses, so the two sit on one line above the nav.
      bottom: 90 + bottom,
      child: AnimatedBuilder(
        animation: _in,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_in.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
          );
        },
        child: Material(
          color: c.slate600,
          borderRadius: BorderRadius.circular(Radii.pill),
          elevation: 6,
          shadowColor: const Color(0x66000000),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.text),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: widget.onUndo,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Undo',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
