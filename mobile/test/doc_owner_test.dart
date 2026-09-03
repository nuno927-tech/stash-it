/// Who an attachment belongs to, and when the lock stops being optional.
///
///   flutter test test/doc_owner_test.dart
///
/// ── Two nullable ids, and the rule that keeps them honest ─────────────────
/// An attachment hangs off an item or off a document, never both and never
/// neither. Nothing in SQLite enforces that, so `Doc.owner` does — and every
/// screen that draws attachments goes through it rather than reading the
/// columns, which is what makes a malformed row skippable rather than fatal.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/vault.dart';
import 'package:stash_it/models/types.dart';

void main() {
  group('who it belongs to', () {
    test('an item, when only itemId is set', () {
      final doc = Doc.onItem(id: 'd1', item: 'bosch');

      expect(doc.owner, isA<ItemOwner>());
      expect(doc.owner!.id, 'bosch');
      expect(doc.paperId, isNull);
    });

    test('a document, when only paperId is set', () {
      final doc = Doc.onPaper(id: 'd1', paper: 'passport');

      expect(doc.owner, isA<PaperOwner>());
      expect(doc.owner!.id, 'passport');
      expect(doc.itemId, isNull);
    });

    test('nothing, when both are set', () {
      // Impossible through the named constructors and possible through a
      // backup written by something else. It resolves to nowhere rather than
      // to whichever column is read first.
      const doc = Doc(id: 'd1', itemId: 'bosch', paperId: 'passport');

      expect(doc.owner, isNull);
    });

    test('nothing, when neither is set', () {
      /*
        The case that used to be spelled `itemId: ''`.

        A backup row with no owner was read as belonging to an item whose id
        is the empty string — invisible, unreachable, and counted. Null is the
        honest answer and the lists skip it.
      */
      const doc = Doc(id: 'd1');

      expect(doc.owner, isNull);
    });

    test('the kind of owner is switchable without a default', () {
      // A sealed pair, so a third kind of record fails to compile here rather
      // than silently filing its scans nowhere.
      String where(Doc doc) => switch (doc.owner) {
            ItemOwner(:final id) => 'item $id',
            PaperOwner(:final id) => 'paper $id',
            null => 'nowhere',
          };

      expect(where(Doc.onItem(id: 'a', item: 'x')), 'item x');
      expect(where(Doc.onPaper(id: 'b', paper: 'y')), 'paper y');
      expect(where(const Doc(id: 'c')), 'nowhere');
    });
  });

  group('when the lock stops being a choice', () {
    test('no scans, no reason to keep it', () {
      expect(whyKeepTheLock(0), isNull);
    });

    test('one scan is enough', () {
      /*
        Before scans existed, an unlocked backup risked a list of appliances
        and what they cost. A passport scan is not the same bet, and one is
        as compromising as ten.
      */
      final why = whyKeepTheLock(1);

      expect(why, isNotNull);
      expect(why, contains('a scanned document'));
    });

    test('several are counted, and pluralised', () {
      expect(whyKeepTheLock(4), contains('4 scanned documents'));
      expect(whyKeepTheLock(4), isNot(contains('a scanned')));
    });

    test('it says the way out, not just the refusal', () {
      // A refusal with no route is a dead end. Deleting the scans turns the
      // setting back into a choice, and the sentence has to say so.
      expect(whyKeepTheLock(2), contains('Delete the scans'));
    });
  });
}
