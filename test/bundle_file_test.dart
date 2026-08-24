/// The real zip and the real hash.
///
///   dart test test/bundle_file_test.dart
///
/// `bundle_test.dart` proves the parser using maps and a fake hash, which is
/// the right way to test the judgement in it. This proves the twenty lines
/// either side: that an actual zip, hashed with actual SHA-256, comes back out
/// the way it went in.
///
/// It is the only suite in the package with dependencies, and the only one
/// that would fail if `dart pub get` had not been run.
library;

import 'dart:convert';

import 'package:stash_it/io/bundle_file.dart';
import 'package:stash_it/logic/bundle.dart';
import 'package:stash_it/models/paper.dart';
import 'package:flutter_test/flutter_test.dart';

/// The smallest readable bundle, for the tests that only need one to exist.
List<int> simpleFile() => writeBundle(tables: {
      'items': [
        {'id': 'a', 'name': 'Kettle', 'propertyId': 'p'},
      ],
    });

void main() {
  group('the hash', () {
    // The one property that matters: the same bytes give the same digest, and
    // a byte's worth of difference gives a different one. If this is not true
    // the checksum is decoration.
    test('is stable', () {
      expect(sha256Hex(utf8.encode('stash it')), sha256Hex(utf8.encode('stash it')));
    });

    test('and changes when the bytes do', () {
      expect(sha256Hex(const [1, 2, 3]), isNot(sha256Hex(const [1, 2, 4])));
    });

    test('of nothing is the known empty digest', () {
      // Fixed by the standard, so this catches a library that is doing
      // something other than SHA-256 under the name.
      expect(
        sha256Hex(const []),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });
  });

  group('a round trip', () {
    List<int> file() => writeBundle(
          tables: {
            'items': [
              {
                'id': 'kettle',
                'name': 'Kettle',
                'propertyId': 'p1',
                'purchaseDate': '2026-01-15',
                'purchasePriceCents': 4999,
                'currency': 'GBP',
                'thumbBlobId': 'b1',
                'warranty': {'months': 24, 'unit': 'months', 'amount': 24},
              },
            ],
            'papers': [
              {
                'id': 'dl',
                'propertyId': 'p1',
                'kind': 'licence',
                'label': 'Driving license',
                'expiresOn': '2027-05-01',
              },
            ],
          },
          blobs: {
            'blobs/b1.webp': [82, 73, 70, 70],
          },
        );

    test('survives being zipped and read back', () {
      final parsed = parseBackupBytes(file());
      expect(parsed.data.items.single.name, 'Kettle');
      expect(parsed.data.items.single.purchasePriceCents, 4999);
      expect(parsed.data.papers.single.kind, PaperKind.licence);
    });

    test('and the bytes of a blob come back exactly', () {
      final parsed = parseBackupBytes(file());
      expect(parsed.blobs['b1']!.bytes, [82, 73, 70, 70]);
      expect(parsed.blobs['b1']!.mime, 'image/webp');
    });

    test('the manifest counts what is actually in it', () {
      final parsed = parseBackupBytes(file());
      expect(parsed.manifest.itemCount, 1);
      expect(parsed.manifest.blobCount, 1);
      expect(parsed.manifest.exportedAt, isNotNull);
    });

    /*
      The checksum has to survive a real zip, not just a map. Compression,
      entry ordering and the central directory all sit between the bytes being
      hashed and the bytes being read back — and if any of them changed the
      payload, every backup would read as damaged.
    */
    test('a real checksum over real compressed entries still matches', () {
      // No exception is the assertion: parseBundle refuses on a mismatch.
      expect(() => parseBackupBytes(file()), returnsNormally);
    });
  });

  group('refusing a file', () {
    test('something that is not a zip at all', () {
      expect(
        () => parseBackupBytes(utf8.encode('this is a text file')),
        throwsA(isA<BundleError>().having(
          (e) => e.message,
          'message',
          contains('not a readable backup'),
        )),
      );
    });

    test('a truncated one', () {
      final half = simpleFile().sublist(0, 40);
      expect(() => parseBackupBytes(half), throwsA(isA<BundleError>()));
    });

    test('a zip that is not a backup', () {
      final notOurs = writeBundle(manifestOverrides: {'format': 'something else'});
      expect(
        () => parseBackupBytes(notOurs),
        throwsA(isA<BundleError>().having(
          (e) => e.message,
          'message',
          contains('not a Stash it backup'),
        )),
      );
    });

    test('and one whose payload was edited after it was written', () {
      final tampered = writeBundle(
        tables: {
          'items': [
            {'id': 'a', 'name': 'Kettle', 'propertyId': 'p'},
          ],
        },
        manifestOverrides: {'sha256': 'not the right digest'},
      );
      expect(
        () => parseBackupBytes(tampered),
        throwsA(isA<BundleError>().having(
          (e) => e.message,
          'message',
          contains('checksum'),
        )),
      );
    });
  });
}
