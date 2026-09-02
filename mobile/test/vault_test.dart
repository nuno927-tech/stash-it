/// The shape of a locked backup.
///
///   flutter test test/vault_test.dart
///
/// ── Why the header is worth a file of tests ────────────────────────────────
/// Everything that can go quietly wrong with encryption is in the header. A
/// magic byte read one position out, a salt truncated, an iteration count that
/// silently defaults — none of those crash. They produce a file that will not
/// open, and the day somebody finds out is the day they have lost their phone
/// and are trying to get their life back.
///
/// The encryption itself is not tested here. It needs a plugin, and the parts
/// of it that could be wrong in an interesting way are the parts below.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/vault.dart';

Uint8List sixteen(int fill) => Uint8List.fromList(List.filled(16, fill));
Uint8List twelve(int fill) => Uint8List.fromList(List.filled(12, fill));

void main() {
  group('telling one kind of file from another', () {
    test('a locked backup is recognised', () {
      final header = vaultHeader(salt: sixteen(1), nonce: twelve(2));
      expect(looksEncrypted(header), isTrue);
    });

    test('a plain zip is not', () {
      /*
        THE COMPATIBILITY TEST. Every backup this app has ever written is a
        zip, and every one of them has to go on opening for ever. A zip starts
        "PK", which is why the magic was chosen not to.
      */
      expect(looksEncrypted(ascii.encode('PKand so on')), isFalse);
    });

    test('nor is something too short to tell', () {
      expect(looksEncrypted(const []), isFalse);
      expect(looksEncrypted(ascii.encode('STASH')), isFalse);
    });

    test('nor something that merely starts the same way', () {
      expect(looksEncrypted(ascii.encode('STASHVAULT')), isFalse);
    });
  });

  group('the header goes out and comes back', () {
    test('everything written is read back the same', () {
      final salt = Uint8List.fromList(List.generate(16, (i) => i * 7 % 256));
      final nonce = Uint8List.fromList(List.generate(12, (i) => 200 - i));

      final read = readVaultHeader([
        ...vaultHeader(salt: salt, nonce: nonce),
        ...List.filled(16, 0), // a tag's worth, so it is long enough to parse
      ]);

      expect(read.version, vaultVersion);
      expect(read.kdf, kdfPbkdf2Sha256);
      expect(read.iterations, vaultIterations);
      expect(read.salt, salt);
      expect(read.nonce, nonce);
    });

    test('the iteration count survives, because a later one will raise it', () {
      // Written into the file rather than assumed, so raising the number in a
      // future version does not orphan every backup somebody already has.
      final read = readVaultHeader([
        ...vaultHeader(salt: sixteen(0), nonce: twelve(0), iterations: 654321),
        ...List.filled(16, 0),
      ]);

      expect(read.iterations, 654321);
    });

    test('the header is exactly as long as it says it is', () {
      expect(vaultHeader(salt: sixteen(0), nonce: twelve(0)),
          hasLength(vaultHeaderBytesChunked));
      expect(vaultHeader(salt: sixteen(0), nonce: twelve(0), chunkBytes: null),
          hasLength(vaultHeaderBytes));
    });

    test('the chunk size survives, for the same reason the count does', () {
      final read = readVaultHeader(
        vaultHeader(salt: sixteen(0), nonce: twelve(0), chunkBytes: 1 << 20),
      );

      expect(read.chunkBytes, 1 << 20);
      expect(read.isChunked, isTrue);
      expect(read.headerLength, vaultHeaderBytesChunked);
    });

    test('a version 1 header still reads, because those files exist', () {
      // The one thing this feature cannot survive is a backup that stops
      // opening. Every format after the first has to keep reading the first.
      final read = readVaultHeader(
        vaultHeader(salt: sixteen(3), nonce: twelve(4), chunkBytes: null),
      );

      expect(read.version, vaultVersionOneBlock);
      expect(read.chunkBytes, 0);
      expect(read.isChunked, isFalse);
      expect(read.headerLength, vaultHeaderBytes);
      expect(read.salt, sixteen(3));
      expect(read.nonce, twelve(4));
    });
  });

  group('what it refuses', () {
    test('a file that is not one of ours', () {
      expect(
        () => readVaultHeader(ascii.encode('PK not a vault at all')),
        throwsA(isA<VaultProblem>()),
      );
    });

    test('a file cut short', () {
      /*
        The commonest damage there is. A mail client truncates, a cloud folder
        syncs half of it, a copy is interrupted — and the front of the file is
        perfectly well-formed, which is what makes this worth a check rather
        than a crash three steps later.

        Checked against the LENGTH, not against how many bytes the reader
        happened to be given. `readVaultHeader` used to refuse anything shorter
        than a header plus a tag, which sounds like the same rule and is not:
        the caller hands it the front of the file and nothing else, so the rule
        fired on every well-formed backup and no locked file could be restored.
      */
      final header = readVaultHeader(
        vaultHeader(salt: sixteen(0), nonce: twelve(0)),
      );

      expect(
        () => checkVaultLength(header.headerLength + 4, header),
        throwsA(isA<VaultProblem>()),
      );
    });

    test('a header on its own is a header, not a short file', () {
      // The bug above, pinned: this is exactly what `openBackupFile` passes.
      expect(
        () => readVaultHeader(vaultHeader(salt: sixteen(0), nonce: twelve(0))),
        returnsNormally,
      );
    });

    test('a chunk size that could not be right', () {
      final bytes = [...vaultHeader(salt: sixteen(0), nonce: twelve(0))];
      bytes[vaultHeaderBytes] = 0xff; // four gigabytes a chunk

      expect(() => readVaultHeader(bytes), throwsA(isA<VaultProblem>()));
    });

    test('a file that ends in the middle of a chunk', () {
      final header = readVaultHeader(
        vaultHeader(salt: sixteen(0), nonce: twelve(0)),
      );

      // A whole chunk, then eight bytes of a tag that needs sixteen.
      final length =
          header.headerLength + (header.chunkBytes + vaultTagBytes) + 8;

      expect(() => chunksInFile(length, header), throwsA(isA<VaultProblem>()));
    });

    test('a format from the future, by name', () {
      final bytes = [
        ...vaultHeader(salt: sixteen(0), nonce: twelve(0)),
        ...List.filled(16, 0),
      ];
      bytes[8] = 99;

      // Named, so somebody with a backup they cannot open is told to update
      // the app rather than told their file is broken.
      expect(
        () => readVaultHeader(bytes),
        throwsA(
          isA<VaultProblem>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('a key method it does not know', () {
      final bytes = [
        ...vaultHeader(salt: sixteen(0), nonce: twelve(0)),
        ...List.filled(16, 0),
      ];
      bytes[9] = 42;

      expect(() => readVaultHeader(bytes), throwsA(isA<VaultProblem>()));
    });

    test('an iteration count that would hang the phone, or do nothing', () {
      for (final silly in [0, 999, 100000000]) {
        final bytes = [
          ...vaultHeader(salt: sixteen(0), nonce: twelve(0), iterations: silly),
          ...List.filled(16, 0),
        ];

        expect(
          () => readVaultHeader(bytes),
          throwsA(isA<VaultProblem>()),
          reason: '$silly should not be attempted',
        );
      }
    });

    test('a salt or nonce of the wrong length, on the way out', () {
      expect(
        () => vaultHeader(salt: Uint8List(8), nonce: twelve(0)),
        throwsA(isA<VaultProblem>()),
      );
      expect(
        () => vaultHeader(salt: sixteen(0), nonce: Uint8List(16)),
        throwsA(isA<VaultProblem>()),
      );
    });
  });

  group('what counts as a passphrase', () {
    test('nothing is not one', () {
      expect(whyNotAPassphrase(''), isNotNull);
      expect(whyNotAPassphrase('    '), isNotNull);
    });

    test('short is not one, however clever', () {
      // The rule is length and only length. "One capital, one number, one
      // symbol" produces Passw0rd! and nothing else.
      expect(whyNotAPassphrase('Tr0ub4dor&3'), isNotNull);
    });

    test('four ordinary words is one', () {
      expect(whyNotAPassphrase('correct horse battery staple'), isNull);
    });

    test('exactly twelve is enough', () {
      expect(whyNotAPassphrase('a' * 12), isNull);
      expect(whyNotAPassphrase('a' * 11), isNotNull);
    });

    test('the spaces around it do not count', () {
      expect(whyNotAPassphrase('  ${'a' * 11}  '), isNotNull);
    });
  });

  group('the chunks', () {
    final header = readVaultHeader(
      vaultHeader(salt: sixteen(0), nonce: twelve(9)),
    );

    test('every chunk gets a different nonce', () {
      final seen = <String>{};

      for (var i = 0; i < 2000; i++) {
        expect(seen.add(chunkNonce(header.nonce, i).join(',')), isTrue,
            reason: 'chunk \$i reused a nonce');
      }
    });

    test('the nonce is still twelve bytes, and still the same base', () {
      final one = chunkNonce(header.nonce, 1);

      expect(one, hasLength(12));
      // Only the last four bytes move.
      expect(one.sublist(0, 8), header.nonce.sublist(0, 8));
    });

    test('chunk zero is the base nonce untouched', () {
      expect(chunkNonce(header.nonce, 0), header.nonce);
    });

    test('the authenticated data names the position and the end', () {
      expect(chunkAad(0, last: false), chunkAad(0, last: false));
      expect(chunkAad(1, last: false), isNot(chunkAad(2, last: false)));

      // The one that stops a backup being lopped off at a chunk boundary:
      // the same chunk means something different when it is the last.
      expect(chunkAad(4, last: true), isNot(chunkAad(4, last: false)));
    });

    test('an empty plaintext is still one chunk', () {
      // So that there is always a final chunk carrying the flag that says so.
      expect(chunkCount(0, vaultChunkBytes), 1);
    });

    test('the count is what you would count', () {
      expect(chunkCount(1, 100), 1);
      expect(chunkCount(100, 100), 1);
      expect(chunkCount(101, 100), 2);
      expect(chunkCount(200, 100), 2);
      expect(chunkCount(201, 100), 3);
    });

    test('what was written is what is read back', () {
      /*
        The arithmetic that finds the chunk boundaries is not stored in the
        file — it is implied by the length, which means an off-by-one here is a
        backup that will not open. So it is checked against the writer's own
        count at every awkward size.
      */
      for (final plain in [
        0,
        1,
        header.chunkBytes - 1,
        header.chunkBytes,
        header.chunkBytes + 1,
        header.chunkBytes * 3,
        header.chunkBytes * 3 + 77,
      ]) {
        final count = chunkCount(plain, header.chunkBytes);
        final onDisk = header.headerLength + plain + count * vaultTagBytes;
        final shape = chunksInFile(onDisk, header);

        expect(shape.count, count, reason: '\$plain bytes');
        expect(
          (shape.count - 1) * header.chunkBytes + shape.lastPlain,
          plain == 0 ? 0 : plain,
          reason: '\$plain bytes came back a different length',
        );
      }
    });
  });
}
