/// The developer card, reached by tapping the version pill ten times.
///
/// Translated from `src/lib/devmode.ts`.
///
/// It is not a secret worth keeping — it is that a switch which lifts the item
/// cap has no business being one stray thumb away on someone's settings
/// screen. Ten deliberate taps cannot happen by accident, and the convention is
/// old enough that anyone who needs it will guess it.
///
/// The run resets if you pause: a tap now and a tap tomorrow are two different
/// intentions, and without a gap the counter would quietly accumulate across a
/// week of ordinary use until the card appeared unbidden.
library;

const int tapsToUnlock = 10;
const Duration tapGap = Duration(milliseconds: 1500);

class TapState {
  const TapState(this.count, this.last);
  final int count;
  final DateTime? last;
}

const TapState noTaps = TapState(0, null);

TapState tap(TapState state, DateTime now) {
  final last = state.last;
  final stale = last == null || now.difference(last) > tapGap;
  return TapState(stale ? 1 : state.count + 1, now);
}

bool unlocked(TapState state) => state.count >= tapsToUnlock;

int tapsLeft(TapState state) {
  final left = tapsToUnlock - state.count;
  return left < 0 ? 0 : left;
}

/// Silence until the tapping is obviously deliberate, then count down.
/// Starting the countdown at ten would announce the thing we just decided to
/// hide.
String? tapHint(TapState state) {
  final left = tapsLeft(state);
  if (left == 0 || left > 3) return null;
  return left == 1 ? '1 more tap' : '$left more taps';
}

/* -------------------------------------------------------- staying unlocked */

/// Once open, it stays open until Hide.
///
/// ── The web version needed storage for this; this one does not ────────────
/// The unlock originally lived in the Settings component's state, so it died
/// the moment you left the screen — the wrong shape for what these tools are.
/// Testing a notification means leaving Settings, closing the app, waiting for
/// it to arrive and tapping it, and coming back to ten more taps every time
/// turns a five-second check into a chore, which is how a test bench stops
/// being used.
///
/// The web fix was `sessionStorage`: survives navigation and reload, clears
/// when the tab closes. It came with a caveat and a try/catch, because private
/// modes and locked-down browsers throw on storage access, and the safe end of
/// that failure was "locked".
///
/// **A Flutter app has no tabs and no reloads.** The process is the session, so
/// a library-level flag gives exactly the semantics `sessionStorage` was chosen
/// for — survives navigation, dies on force-quit — with nothing that can throw
/// and nothing to catch. The storage layer and its failure mode both go.
bool _unlocked = false;

bool readUnlocked() => _unlocked;

void rememberUnlocked(bool on) => _unlocked = on;
