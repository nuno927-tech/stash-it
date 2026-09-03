/// Sharing a few records, and receiving somebody else's.
///
///   flutter test test/card_test.dart
///
/// Two things are being pinned here, and one of them is a safety property
/// rather than a feature: **a card and a backup must refuse each other**.
/// Restoring replaces the database, so a file that opened either door would
/// mean one mis-tap on a text-message attachment could erase a stranger's
/// entire stash. The tests for that are first, and they are the ones that must
/// never be relaxed to make something else pass.
///
/// The rest is about arrival. A card lands in a stash that already has data in
/// it, with its own ids, its own room names and its own idea of what "Kitchen"
/// means — every one of which is a chance to overwrite something the recipient
/// never touched.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/bundle.dart';
import 'package:stash_it/logic/bundle_write.dart';
import 'package:stash_it/logic/card.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';

/// A stand-in for the real hash. The parser only ever compares it with itself.
String fakeSha(List<int> bytes) => 'sha-${bytes.length}';

/// Builds the unzipped entry map a card would have, so no zip is needed.
Map<String, List<int>> cardEntries({
  List<Item> items = const [],
  List<Doc> docs = const [],
  List<Room> rooms = const [],
  List<Paper> papers = const [],
  List<Subscription> subs = const [],
  Map<String, List<int>> blobs = const {},
  String format = cardFormat,
}) {
  final tables = <String, Object?>{
    'items': [for (final i in items) itemToJson(i)],
    'docs': [for (final d in docs) docToJson(d)],
    'rooms': [for (final r in rooms) roomToJson(r)],
    'subscriptions': [for (final s in subs) subscriptionToJson(s)],
    'papers': [for (final p in papers) paperToJson(p)],
  };

  final entries = <String, List<int>>{
    for (final e in tables.entries)
      '${e.key}.json': utf8.encode(jsonEncode(e.value)),
    ...blobs,
  };

  entries['manifest.json'] = utf8.encode(jsonEncode({
    'format': format,
    'formatVersion':
        format == cardFormat ? cardFormatVersion : backupFormatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': 'test',
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'counts': {
      'items': items.length,
      'docs': docs.length,
      'blobs': blobs.length
    },
    'sha256': fakeSha(checksumInput(entries)),
    'encrypted': false,
  }));

  return entries;
}

Item anItem({
  String id = 'i1',
  String name = 'Dishwasher',
  String? roomId,
  String? thumbBlobId,
  DateTime? deletedAt,
}) =>
    Item(
      id: id,
      name: name,
      propertyId: 'theirs',
      roomId: roomId,
      purchaseDate: '2025-03-04',
      coverages: const [
        Coverage(
            id: 'w', label: 'Warranty', unit: CoverageUnit.years, amount: 2),
      ],
      thumbBlobId: thumbBlobId,
      deletedAt: deletedAt,
    );

Paper aPaper({String id = 'p1', String label = 'Passport'}) => Paper(
      id: id,
      propertyId: 'theirs',
      kind: PaperKind.passport,
      label: label,
      expiresOn: '2029-06-01',
    );

Subscription aSub({String id = 's1', String name = 'Netflix'}) => Subscription(
      id: id,
      propertyId: 'theirs',
      name: name,
      cadence: Cadence.monthly,
      anchorDate: '2026-01-09',
      amountCents: 999,
      currency: 'GBP',
    );

void main() {
  /// Counts up, so a test can assert an id was replaced without knowing which.
  int n = 0;
  String ids() => 'new-${++n}';
  setUp(() => n = 0);

  group('a card and a backup refuse each other', () {
    test('the restore path rejects a card, and says where to take it', () {
      expect(
        () => parseBundle(cardEntries(items: [anItem()]), sha256Hex: fakeSha),
        throwsA(
          isA<BundleError>().having((e) => e.message, 'message',
              allOf(contains('shared card'), contains('replace'))),
        ),
      );
    });

    test('the import path rejects a backup, and says where to take it', () {
      expect(
        () => parseBundle(
          cardEntries(items: [anItem()], format: backupFormat),
          sha256Hex: fakeSha,
          format: cardFormat,
        ),
        throwsA(isA<BundleError>()
            .having((e) => e.message, 'message', contains('full backup'))),
      );
    });

    test('a card parses when it is asked for as a card', () {
      final card = parseBundle(
        cardEntries(items: [anItem()]),
        sha256Hex: fakeSha,
        format: cardFormat,
      );
      expect(card.data.items.single.name, 'Dishwasher');
    });
  });

  group('arriving in a stash that already has things in it', () {
    ParsedBundle parse(Map<String, List<int>> e) =>
        parseBundle(e, sha256Hex: fakeSha, format: cardFormat);

    test('every id is replaced, so nothing can be overwritten', () {
      /*
        The ids in a card came from another install. They are not reserved
        here, and reusing one would mean a card silently rewriting a record
        the recipient already had.
      */
      final merged = planCardMerge(
        parse(cardEntries(
            items: [anItem(id: 'i1')],
            papers: [aPaper(id: 'p1')],
            subs: [aSub(id: 's1')])),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      expect(merged.items.single.id, isNot('i1'));
      expect(merged.papers.single.id, isNot('p1'));
      expect(merged.subscriptions.single.id, isNot('s1'));
    });

    test('everything is reassigned to the recipient property', () {
      final merged = planCardMerge(
        parse(
            cardEntries(items: [anItem()], papers: [aPaper()], subs: [aSub()])),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      expect(merged.items.single.propertyId, 'mine');
      expect(merged.papers.single.propertyId, 'mine');
      expect(merged.subscriptions.single.propertyId, 'mine');
    });

    test('a room that already exists by name is reused, not duplicated', () {
      // Their "kitchen " and my "Kitchen" are one room to a person.
      final merged = planCardMerge(
        parse(cardEntries(
          items: [anItem(roomId: 'r-theirs')],
          rooms: [
            const Room(id: 'r-theirs', propertyId: 'theirs', name: 'kitchen ')
          ],
        )),
        propertyId: 'mine',
        existingRooms: const [
          Room(id: 'r-mine', propertyId: 'mine', name: 'Kitchen'),
        ],
        newId: ids,
      );

      expect(merged.newRooms, isEmpty);
      expect(merged.items.single.roomId, 'r-mine');
    });

    test('a room the recipient does not have arrives named', () {
      final merged = planCardMerge(
        parse(cardEntries(
          items: [anItem(roomId: 'r-theirs')],
          rooms: [
            const Room(id: 'r-theirs', propertyId: 'theirs', name: 'Boat')
          ],
        )),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      expect(merged.newRooms.single.name, 'Boat');
      expect(merged.newRooms.single.propertyId, 'mine');
      expect(merged.items.single.roomId, merged.newRooms.single.id);
    });

    test('documents follow their item to its new id', () {
      final merged = planCardMerge(
        parse(cardEntries(
          items: [anItem(id: 'i1')],
          docs: [const Doc(id: 'd1', itemId: 'i1', kind: DocKind.receipt)],
        )),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      expect(merged.docs.single.itemId, merged.items.single.id);
      expect(merged.docs.single.id, isNot('d1'));
    });

    test('a document whose item was not taken is dropped', () {
      // Otherwise the recipient gets a receipt attached to nothing.
      final merged = planCardMerge(
        parse(cardEntries(
          items: [anItem(id: 'i1'), anItem(id: 'i2', name: 'Kettle')],
          docs: [const Doc(id: 'd1', itemId: 'i2', kind: DocKind.receipt)],
        )),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
        keep: {'i1'},
      );

      expect(merged.items.single.name, 'Dishwasher');
      expect(merged.docs, isEmpty);
    });

    test('a scan follows its document to its new id', () {
      final merged = planCardMerge(
        parse(cardEntries(
          papers: [aPaper(id: 'p1')],
          docs: [const Doc(id: 'd1', paperId: 'p1', kind: DocKind.other)],
        )),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      expect(merged.docs.single.paperId, merged.papers.single.id);
      expect(merged.docs.single.itemId, isNull);
      expect(merged.docs.single.id, isNot('d1'));
    });

    test('a scan whose document was not taken is dropped', () {
      /*
        The one that matters most on this side.

        A scan with nowhere to go must not be filed against whatever is
        nearest — a passport page attached to somebody's dishwasher is worse
        than the scan simply not arriving.
      */
      final merged = planCardMerge(
        parse(cardEntries(
          items: [anItem(id: 'i1')],
          papers: [aPaper(id: 'p1')],
          docs: [const Doc(id: 'd1', paperId: 'p1', kind: DocKind.other)],
        )),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
        keep: {'i1'},
      );

      expect(merged.papers, isEmpty);
      expect(merged.docs, isEmpty);
    });

    test('an attachment owned by both, or by neither, is dropped', () {
      // Not writable through the named constructors, and possible in a file
      // written by something else. It resolves to nowhere — see `Doc.owner`.
      final merged = planCardMerge(
        parse(cardEntries(
          items: [anItem(id: 'i1')],
          papers: [aPaper(id: 'p1')],
          docs: [
            const Doc(id: 'd1', itemId: 'i1', paperId: 'p1'),
            const Doc(id: 'd2'),
          ],
        )),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      expect(merged.docs, isEmpty);
    });

    test('the sender bin does not travel', () {
      // A card is what somebody chose to send, not their deleted rows.
      final merged = planCardMerge(
        parse(cardEntries(items: [anItem(deletedAt: DateTime(2026, 1, 1))])),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      expect(merged.items, isEmpty);
    });

    test('blobs are rekeyed and only those actually referenced come through',
        () {
      final merged = planCardMerge(
        parse(cardEntries(
          items: [anItem(thumbBlobId: 'b1')],
          blobs: {
            'blobs/b1.webp': [1, 2, 3],
            'blobs/b9.webp': [9]
          },
        )),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      final thumb = merged.items.single.thumbBlobId;
      expect(thumb, isNotNull);
      expect(thumb, isNot('b1'));
      expect(merged.blobs.keys, [thumb]);
      expect(merged.blobs[thumb]!.bytes, [1, 2, 3]);
    });

    test('a card with no blobs leaves the references empty, not dangling', () {
      // This is the attachments-off case: the ids are still in the JSON, but
      // there are no files. A reference to a blob that is not there would draw
      // a broken thumbnail for ever.
      final merged = planCardMerge(
        parse(cardEntries(items: [anItem(thumbBlobId: 'b1')])),
        propertyId: 'mine',
        existingRooms: const [],
        newId: ids,
      );

      expect(merged.items.single.thumbBlobId, isNull);
      expect(merged.blobs, isEmpty);
    });
  });

  group('the summary, which is the half most recipients will read', () {
    test('an item reads as a sentence with a real date', () {
      final text = cardSummary(
        items: [anItem()],
        now: DateTime(2026, 8, 31),
      );
      expect(text, contains('Dishwasher'));
      expect(text, contains('covered until 4 March 2027'));
    });

    test('lapsed cover says so rather than promising a future date', () {
      final text = cardSummary(
        items: [anItem()],
        now: DateTime(2030, 1, 1),
      );
      expect(text, contains('cover ended'));
    });

    test('an item with nothing to count down says that plainly', () {
      final text = cardSummary(
        items: [Item(id: 'x', name: 'Lamp', propertyId: 'p')],
      );
      expect(text, contains('no warranty length recorded'));
    });

    test('documents and subscriptions each get a line', () {
      final text = cardSummary(
        papers: [aPaper()],
        subscriptions: [aSub()],
        now: DateTime(2026, 8, 31),
      );
      expect(text, contains('Passport — expires 1 June 2029'));
      expect(text, contains('Netflix'));
      expect(text, contains('a month'));
    });

    test('it says where it came from and that the file is optional', () {
      // Somebody without the app has to be able to act on the message alone.
      final text = cardSummary(items: [anItem()]);
      expect(text, contains('Stash it'));
      expect(text.toLowerCase(), contains('if you do not'));
    });
  });

  group('what the sender picked', () {
    test('toggling adds and removes without touching the original', () {
      const empty = CardPick();
      final one = empty.toggleItem('a');
      final two = one.toggleItem('b');
      final back = two.toggleItem('a');

      expect(empty.items, isEmpty, reason: 'CardPick must not mutate in place');
      expect(one.items, {'a'});
      expect(two.items, {'a', 'b'});
      expect(back.items, {'b'});
    });

    test('attachments are off until somebody says otherwise', () {
      expect(const CardPick().attachments, isFalse);
      expect(const CardPick().withAttachments(true).attachments, isTrue);
    });

    test('the count spans all three kinds', () {
      const pick = CardPick(
        items: {'a', 'b'},
        papers: {'c'},
        subscriptions: {'d'},
      );
      expect(pick.count, 4);
      expect(pick.isEmpty, isFalse);
    });
  });
}
