/// The free tier's arithmetic.
///
/// The gate itself — that both insert paths ask this question — is tested in
/// repository_test.dart, and that is the half that has actually been wrong
/// before. This file covers the answers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/limits.dart';
import 'package:stash_it/models/settings.dart';

const free = Entitlements();
const paid = Entitlements(proUnlock: true);

void main() {
  setUp(() => capEnforced = true);
  tearDown(() => capEnforced = true);

  group('the line', () {
    test('is twenty', () => expect(freeItemLimit, 20));

    test('nineteen saved leaves room for one', () {
      expect(canAddItem(19, free), isTrue);
    });

    /*
      At the line, not past it. `count` is what is already stored, so the
      twentieth save happens at count 19 — an off-by-one here is the
      difference between a tier that holds twenty and one that holds
      twenty-one, and nothing else in the app would notice.
    */
    test('twenty saved is full', () => expect(canAddItem(20, free), isFalse));
    test('and so is anything beyond',
        () => expect(canAddItem(40, free), isFalse));

    test('paying removes the question', () {
      expect(canAddItem(20, paid), isTrue);
      expect(canAddItem(4000, paid), isTrue);
    });
  });

  group('remainingFree', () {
    test('counts down', () {
      expect(remainingFree(0, free), 20);
      expect(remainingFree(15, free), 5);
      expect(remainingFree(20, free), 0);
    });

    /*
      Somebody can be over the limit without having broken a rule: a restore
      from a backup brings in whatever the file holds, and the cap only guards
      new saves. Clamped to zero so no screen ever draws "-6 left".
    */
    test('never goes negative', () {
      expect(remainingFree(76, free), 0);
    });

    /*
      Null, not a large number. A caller that got 999 back would happily draw
      "999 left" for somebody who has paid — and the honest answer for them is
      that the question no longer applies.
    */
    test('is null once paid, and null with the cap off', () {
      expect(remainingFree(3, paid), isNull);

      capEnforced = false;
      expect(remainingFree(3, free), isNull);
      capEnforced = true;
    });
  });

  group('shouldMentionCap', () {
    /*
      Not at one of twenty, and not only at twenty. A counter that appears on
      the first save is a shop; one that appears only at the wall is an ambush.
      Five is where the number stops being noise and starts being warning.
    */
    test('stays quiet with room to spare', () {
      expect(shouldMentionCap(0, free), isFalse);
      expect(shouldMentionCap(14, free), isFalse);
    });

    test('speaks up inside the last five', () {
      expect(shouldMentionCap(15, free), isTrue);
      expect(shouldMentionCap(19, free), isTrue);
      expect(shouldMentionCap(20, free), isTrue);
    });

    test('and never to somebody who has paid', () {
      expect(shouldMentionCap(19, paid), isFalse);
      expect(shouldMentionCap(9999, paid), isFalse);
    });
  });
}
