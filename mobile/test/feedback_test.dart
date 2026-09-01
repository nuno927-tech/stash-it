/// Every cue has a voice.
///
/// ── Why this is worth a file of its own ───────────────────────────────────
/// `_play` reaches into the voice table with a `!`. A member added to `Cue`
/// and not to the table is not a compile error and not a warning — it is a
/// crash at the exact moment somebody presses the thing, which is both the
/// worst time to find out and the least likely place anyone would look.
///
/// The buzz side cannot go wrong the same way: it is a `switch` on the enum
/// with no default, so the compiler refuses a missing case. The tone side is a
/// map, and a map has no such opinion.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/ui/feedback.dart';

void main() {
  test('every cue has a tone', () {
    for (final cue in Cue.values) {
      expect(hasVoice(cue), isTrue,
          reason: '$cue has no entry in the voice table');
    }
  });

  /*
    Two cues that must not be the same cue.

    `save` is what a settings toggle gets — the app agreeing with you. Filing
    an item, a document or a subscription is the thing the app is for, and
    sharing a confirmation tone with a preference switch made the two feel
    equally consequential, which is to say it made neither feel like anything.

    Nothing here can hear them. What it can check is that somebody has not
    quietly pointed one at the other.
  */
  test('stashed is its own cue, not an alias for save', () {
    expect(Cue.stashed, isNot(Cue.save));
    expect(hasVoice(Cue.stashed), isTrue);
  });
}
