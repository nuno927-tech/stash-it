/// Every cue has a voice, and no two of them are the same voice.
///
/// ── What this used to guard, and does not need to any more ────────────────
/// `_play` reached into a `Map<Cue, _Voice>` with a `!`, so a member added to
/// the enum and not to the table was a crash at the exact moment somebody
/// pressed the thing. This file walked `Cue.values` to catch that.
///
/// The table is a switch now and the compiler refuses a missing case, which is
/// a stronger guarantee for less money. What a compiler will never notice is a
/// cue quietly pointed at another cue's notes — two entries that are the same
/// two entries — so that is what is left here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/ui/feedback.dart';

void main() {
  test('every cue has a tone with something in it', () {
    for (final cue in Cue.values) {
      expect(noteCount(cue), greaterThan(0),
          reason: '$cue has no notes to play');
    }
  });

  /*
    Two cues that must not be the same cue.

    `save` is what a settings toggle gets — the app agreeing with you. Filing an
    item, a document or a subscription is the thing the app is for, and sharing
    a confirmation tone with a preference switch made the two feel equally
    consequential, which is to say it made neither feel like anything.

    Nothing here can hear them. What it can check is that somebody has not
    quietly pointed one at the other.
  */
  test('stashed is its own cue, not an alias for save', () {
    expect(Cue.stashed, isNot(Cue.save));
    expect(notesOf(Cue.stashed), isNot(notesOf(Cue.save)));
  });

  /*
    ── And the same for the newest one ────────────────────────────────────────

    `pick` was `tap` until selection mode got a cue of its own. It exists
    entirely to be different from an ordinary press, so a copy-paste that gave
    it 880Hz back would undo the whole point of it while looking correct.
  */
  test('pick does not sound like an ordinary tap', () {
    expect(notesOf(Cue.pick), isNot(notesOf(Cue.tap)));
  });

  test('no two cues share a tone', () {
    final seen = <String, Cue>{};

    for (final cue in Cue.values) {
      final signature = notesOf(cue).join(',');
      final already = seen[signature];

      expect(already, isNull,
          reason: '$cue plays the same notes as $already');
      seen[signature] = cue;
    }
  });
}
