/// Scrolling the next card into view once the last one is finished with.
///
/// Ported from `useAutoAdvance` in `src/components/useAutoAdvance.ts`, rules
/// intact. The predicate is `cardFilled` in `logic/auto_advance.dart`.
///
/// ── The intent, and the risk ──────────────────────────────────────────────
/// Answering the last question in a card should take you to the next one, so a
/// long form reads as a sequence rather than a scroll.
///
/// Against that: **moving the page under somebody is one of the most
/// unpleasant things an interface can do.** Every rule below exists to make
/// this fire less often, and each one was earned.
library;

import 'dart:async';

import 'package:flutter/material.dart';

class AutoAdvance {
  AutoAdvance(this.target);

  /// The card to bring into view. Attached to the *next* card, not the one
  /// being completed.
  final GlobalKey target;

  /*
    ── Once per card ─────────────────────────────────────────────────────────
    It fires on the false-to-true edge and then latches. A card you complete,
    edit, and complete again does not throw you forward a second time.
  */
  bool _fired = false;

  /*
    ── Not on arrival ────────────────────────────────────────────────────────
    Opening an already-complete record — which is every edit, ever — would
    otherwise scroll straight past the thing you came to change. The first
    call is recorded and never acted on.
  */
  bool _started = false;

  Timer? _pending;

  void dispose() => _pending?.cancel();

  /// Call from `build`, with the card's whole inventory already reduced to a
  /// yes or no by `cardFilled`.
  void update(BuildContext context, {required bool complete}) {
    if (!_started) {
      _started = true;
      // Arriving complete is not the same as becoming complete.
      if (complete) _fired = true;
      return;
    }

    if (!complete || _fired) return;

    /*
      ── Not while the keyboard is up ────────────────────────────────────────

      A keyboard on screen means somebody is still working, and scrolling then
      hides the thing they are looking at behind it. This is also what stops a
      text field advancing the page mid-word, now that typing can complete a
      card.

      The web version tested `document.activeElement`; the honest equivalent
      here is the inset the keyboard is taking up, which is the same condition
      said in the terms the platform actually offers.
    */
    if (MediaQuery.of(context).viewInsets.bottom > 0) return;

    _fired = true;

    /*
        ── Read now, used later ──────────────────────────────────────────────

        Reduced motion is looked up HERE, inside `build`, with a context that
        is alive. It used to be read inside the timer below, from the target
        card's context — and an inherited lookup outside a build phase is
        exactly what the framework forbids. It registers that element as a
        dependent of the MediaQuery at a moment when nothing will come back to
        unregister it, and the tear-down then trips `_dependents.isEmpty`.

        The window is small and entirely reachable: complete a card, and 220
        milliseconds later a sheet may have closed over the top of it.

        Reduced motion downgrades the animation, not the behaviour: the jump
        still happens, it just does not slide.
      */
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    /*
      A beat first, so the tap that completed the card is seen to land before
      the page moves. Without it the two read as one event and the movement
      looks like a mis-tap.
    */
    _pending?.cancel();
    _pending = Timer(const Duration(milliseconds: 220), () {
      final node = target.currentContext;
      /*
          `mounted`, not just non-null: a GlobalKey still hands back a context
          while its element is being taken down, and scrolling to something on
          its way out reaches into a tree that is mid-tear-down.
        */
      if (node == null || !node.mounted) return;

      Scrollable.ensureVisible(
        node,
        duration: still ? Duration.zero : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0,
      );
    });
  }
}
