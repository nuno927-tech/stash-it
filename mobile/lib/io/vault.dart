/// Locking and unlocking a backup with a passphrase.
///
/// ── Why this exists now and did not before ─────────────────────────────────
/// A `.stashit` is a plain zip, on purpose: somebody with a broken install can
/// open it and read their own data, which is the difference between a backup
/// and a hostage. That is a good trade for a file on your own phone.
///
/// Two things changed it. Backups now write themselves into a folder that may
/// be a cloud account, and documents can now hold a scan of a passport. Either
/// alone would be an argument; together they mean the default has to be that a
/// backup is unreadable to anyone who finds it.
///
/// ── What is used, and what was not ─────────────────────────────────────────
/// AES-256-GCM, with the key derived from the passphrase by PBKDF2-HMAC-SHA256
/// over 210,000 iterations and a fresh 16-byte salt each time. GCM because it
/// authenticates as well as encrypts: a file altered by one byte fails to open
/// rather than decrypting to rubbish, and a wrong passphrase cannot be told
/// apart from a damaged file, which is exactly right.
///
/// Nothing here is invented. The header layout is in `logic/vault.dart`, set
/// out so that a person with the passphrase and an afternoon can decrypt one of
/// these with standard tools and no copy of this app — which is the promise the
/// plain zip used to keep for free.
///
/// ── Where the passphrase lives ─────────────────────────────────────────────
/// In the platform's secure storage, beside the database key, so an automatic
/// backup can run without asking. That is a convenience and not the point: it
/// dies with the phone, exactly like the database key, which is why the app
/// insists somebody writes the passphrase down somewhere else.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logic/vault.dart';

/// The same store the database key uses, with the same options — see
/// `db/open_flutter.dart`. Different key name, same hardware backing.
const FlutterSecureStorage _store = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

const String _passphraseName = 'stash_it_backup_passphrase';

/*
  ── The key is derived once, not once per backup ────────────────────────────

  Stretching a passphrase is 210,000 rounds of HMAC-SHA256 and it is meant to
  be slow — that is the entire defence against somebody guessing. What it is
  NOT meant to be is repeated: the cost buys nothing the second time, and it was
  being paid on every single backup.

  It does not depend on the file, either. The same passphrase and the same salt
  make the same key whatever is being encrypted, so this phone derives it the
  first time it locks anything and keeps it.

  ── And this gives nothing away ─────────────────────────────────────────────

  The derived key sits in the same hardware-backed store as the passphrase it
  came from — which is strictly less secret than the passphrase itself, because
  the passphrase opens every backup ever made with it and the key opens only
  the ones made with this salt. Nothing is weakened by keeping it; something is
  weakened by keeping the passphrase, and that was already the price of an
  automatic backup that does not stop to ask.

  A file from ANOTHER phone carries its own salt in its header and is derived
  the slow way, once, which is correct and rare.
*/
const String _saltName = 'stash_it_backup_salt';
const String _keyName = 'stash_it_backup_key';

/*
  ── All of this happens on another isolate ──────────────────────────────────

  It did not, and the app froze. Stretching a passphrase is 210,000 rounds of
  HMAC-SHA256 by design — the whole point is that it is slow — and encrypting a
  backup with photographs in it is megabytes of AES on top. On the UI isolate
  that is seconds of a phone that does not scroll, does not change tab and does
  not answer, which Android reports as an app that has stopped.

  Worse, it ran on every launch and every resume while a backup was due, so it
  was not one bad moment; it was every moment.

  `exportBackup` had already learnt this and moved its zipping to `compute`.
  This is the same lesson arriving twice, and the note is here so it does not
  arrive a third time: **anything in this file is heavy by construction.**

  Moving it there cost the native cipher, which turned a frozen app into a
  responsive app that took half a minute — better, and not good. A spawned
  isolate has no platform channels, so `cryptography_flutter` was not there and
  everything fell back to the package's Dart AES and Dart PBKDF2.

  So the isolate takes a `RootIsolateToken` and turns the channels on for
  itself — the mechanism Flutter added for exactly this — and then asks for the
  native implementations by name. Both halves of the work are accelerated:
  `FlutterCryptography` overrides `aesGcm` AND `pbkdf2`, which are the two
  things this file does.

  See `nativeIfPossible`. It is wrapped in a `try` because a background
  isolate that cannot reach the platform is a slow backup, not a failed one.
*/

/* --------------------------------------------------------- the passphrase */

/// The passphrase in use, or null when backups are not encrypted.
Future<String?> backupPassphrase() async {
  try {
    return await _store.read(key: _passphraseName);
  } catch (_) {
    // A secure store that will not open is not something to crash over. The
    // caller reads null as "not set up", which leads somewhere sensible.
    return null;
  }
}

/// Whether backups are being encrypted at all.
Future<bool> backupsAreLocked() async => (await backupPassphrase()) != null;

/// Sets it, or replaces it.
///
/// Old backups already written stay readable with the OLD passphrase — nothing
/// goes back and re-encrypts them, and the app says so. Anything else would
/// mean rewriting every file in somebody's cloud folder on a whim.
///
/// The cached key goes with the old passphrase. A new one gets a new salt and
/// a new key, derived on the next backup rather than here — nobody should wait
/// on a progress-less sheet for something they can pay for later.
Future<void> setBackupPassphrase(String passphrase) async {
  await _store.write(key: _passphraseName, value: passphrase.trim());
  await _forgetDerived();
}

/// Turns encryption off.
///
/// Refused elsewhere while a document scan exists — see `whyKeepTheLock`. This
/// function does as it is told; the judgement is the caller's.
Future<void> clearBackupPassphrase() async {
  await _store.delete(key: _passphraseName);
  await _forgetDerived();
}

Future<void> _forgetDerived() async {
  await _store.delete(key: _saltName);
  await _store.delete(key: _keyName);
}

/// The salt and key this phone locks with, deriving them the first time.
///
/// Null when there is no passphrase, which is the caller's signal that backups
/// are not locked at all.
Future<({Uint8List salt, Uint8List key})?> lockingMaterial() async {
  final passphrase = await backupPassphrase();
  if (passphrase == null) return null;

  final storedSalt = await _store.read(key: _saltName);
  final storedKey = await _store.read(key: _keyName);

  if (storedSalt != null && storedKey != null) {
    return (
      salt: base64Decode(storedSalt),
      key: base64Decode(storedKey),
    );
  }

  // First time on this phone, or the first since the passphrase changed. The
  // one slow derivation, and it happens on an isolate like everything else.
  final salt = _randomBytes(16);
  final key = await compute(_derive, (
    passphrase: passphrase,
    salt: salt,
    token: RootIsolateToken.instance,
  ));

  await _store.write(key: _saltName, value: base64Encode(salt));
  await _store.write(key: _keyName, value: base64Encode(key));

  return (salt: salt, key: key);
}

/// The isolate's half of the derivation. Also used by the developer timings.
Future<Uint8List> _derive(
  ({String passphrase, Uint8List salt, RootIsolateToken? token}) work,
) async {
  nativeIfPossible(work.token);

  final key = await _keyFrom(work.passphrase, work.salt, vaultIterations);
  return Uint8List.fromList(await key.extractBytes());
}

/*
  ── Where the seconds actually went, per phase ──────────────────────────────

  The measured cipher is 90 MB/s and the derivation is 1.6 seconds, which adds
  up to about three seconds for any backup this app can produce. Locking one
  took eighty.

  So the cost is not the cryptography; it is what surrounds it — the copy into
  the isolate, the copy back, and the assembling of the result. That is exactly
  the part nobody times, because it does not look like work.

  So it is timed. The export and the import isolates leave their phase timings
  here and the developer probe prints them. Nothing else reads it, and it is a
  string rather than numbers because its only consumer is a person reading a
  screen.

  It is set on the MAIN isolate, from a string the worker RETURNS. That is not
  a detail. A top-level variable is per-isolate, so the first shape of this had
  the worker dutifully recording every phase into a copy of the variable that
  nothing could ever read, and the probe printed a total with no breakdown —
  three releases of guessing at a number that was being measured all along.

  So nothing writes this from inside an isolate. Ever.
*/
String? lastVaultTimings;

/// Bytes as a `Uint8List`, copying only when they are not already one.
///
/// ── The difference this makes is not small ─────────────────────────────────
/// A `List<int>` can be a list of BOXED integers — an object per byte. Handing
/// one of those to an isolate, or adding it to a `BytesBuilder`, is a hundred
/// million allocations rather than a memcpy, and it is invisible: the types
/// are identical, the code reads the same, and one of them takes a minute.
///
/// Everything crossing an isolate boundary in this file goes through here.
Uint8List flatBytes(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

/* ------------------------------------------------------------ the locking */

/// Seals bytes into a file, a chunk at a time, on the isolate already running.
///
/// ── One chunk in memory, not the whole backup ──────────────────────────────
/// The version that encrypted in a single call held the plaintext, the
/// ciphertext and the assembled output at once. On a 185 MB backup that is
/// most of a phone's heap, and it ran at 4 MB/s on a phone whose cipher
/// measures 90 — the cipher was never the slow part; carrying the file around
/// was. Each chunk here is encrypted and written before the next is touched.
///
/// ── No `compute` in here ───────────────────────────────────────────────────
/// There used to be a wrapper that spawned an isolate for this alone, and it
/// was the wrong shape: the whole backup was copied in and the whole sealed
/// file copied back, on top of the copies the zipping already cost. The export
/// runs in ONE isolate now and calls this inside it — see
/// `exportSealedBackupToFile`, which explains what those copies were costing.
Future<({int bytes, String timings})> sealToFile(
  ({
    Uint8List plain,
    Uint8List salt,
    Uint8List key,
    Uint8List nonce,
    String path,
    RootIsolateToken? token,
  }) work,
) async {
  final watch = Stopwatch()..start();

  nativeIfPossible(work.token);
  final started = watch.elapsedMicroseconds;

  final gcm = AesGcm.with256bits();
  final secret = SecretKey(work.key);
  final total = chunkCount(work.plain.length, vaultChunkBytes);

  final file = await File(work.path).open(mode: FileMode.write);
  var wrote = 0;
  var enciphering = 0;
  var writing = 0;

  try {
    final header = vaultHeader(salt: work.salt, nonce: work.nonce);
    await file.writeFrom(header);
    wrote += header.length;

    for (var i = 0; i < total; i++) {
      final from = i * vaultChunkBytes;
      final to = min(from + vaultChunkBytes, work.plain.length);

      /*
        A view, not a copy. `sublist` would allocate another four megabytes on
        every pass and hand the collector 46 of them to clean up on a backup
        this size.
      */
      final slice = Uint8List.sublistView(work.plain, from, to);

      final at = watch.elapsedMicroseconds;
      final box = await gcm.encrypt(
        slice,
        secretKey: secret,
        nonce: chunkNonce(work.nonce, i),
        aad: chunkAad(i, last: i == total - 1),
      );
      final sealed = watch.elapsedMicroseconds;
      enciphering += sealed - at;

      await file.writeFrom(flatBytes(box.cipherText));
      await file.writeFrom(flatBytes(box.mac.bytes));
      writing += watch.elapsedMicroseconds - sealed;

      wrote += box.cipherText.length + box.mac.bytes.length;
    }

    await file.flush();
  } finally {
    await file.close();
  }

  final mb = work.plain.length / 1024 / 1024;
  final seconds = enciphering / 1000000;

  return (
    bytes: wrote,
    timings: '  cipher     ${Cryptography.instance.runtimeType}'
        '\n  isolate up ${started ~/ 1000} ms'
        '\n  encrypt    ${enciphering ~/ 1000} ms in $total chunks'
        ' (${seconds == 0 ? '—' : '${(mb / seconds).toStringAsFixed(1)} MB/s'})'
        '\n  write      ${writing ~/ 1000} ms',
  );
}

/// Opens a sealed file, a chunk at a time, on the isolate already running.
///
/// Throws [VaultProblem] with a sentence for a person. A wrong passphrase and a
/// damaged file land in the same place, because GCM cannot tell them apart —
/// and being told "wrong passphrase" about a truncated download would send
/// somebody looking in the wrong place for an hour.
///
/// No `compute` in here, for the same reason as [sealToFile].
Future<({Uint8List bytes, String timings})> openFromFile(
  ({
    String path,
    String passphrase,
    Uint8List? key,
    RootIsolateToken? token,
  }) work,
) async {
  final watch = Stopwatch()..start();

  nativeIfPossible(work.token);
  final started = watch.elapsedMicroseconds;

  final file = await File(work.path).open();

  try {
    final length = await file.length();
    final header = readVaultHeader(await file.read(vaultPeekBytes));
    checkVaultLength(length, header);

    // Already derived on this phone, or derived here the slow way for a file
    // that came from somewhere else.
    final key = work.key != null
        ? SecretKey(work.key!)
        : await _keyFrom(work.passphrase, header.salt, header.iterations);
    final gotKey = watch.elapsedMicroseconds;

    await file.setPosition(header.headerLength);

    final done = header.isChunked
        ? await _openChunks(file, header, key, length)
        : await _openOneBlock(file, header, key, length);
    final opened = watch.elapsedMicroseconds;

    final mb = done.bytes.length / 1024 / 1024;
    final seconds = (opened - gotKey) / 1000000;

    return (
      bytes: done.bytes,
      timings: '  cipher     ${Cryptography.instance.runtimeType}'
          // Named, because a version 1 file is opened in one call and a
          // version 2 file in chunks, and thirty seconds against five is
          // entirely explained by which one arrived. A breakdown that does not
          // say which path it timed sends somebody looking for a bug that is
          // not there — it cost a build here.
          '\n  format     ${header.version}'
          '${header.isChunked ? ', in ${header.chunkBytes ~/ 1024 ~/ 1024} MB chunks' : ', one block'}'
          '\n  isolate up ${started ~/ 1000} ms'
          '\n  derive     ${(gotKey - started) ~/ 1000} ms'
          '\n  open       ${(opened - gotKey) ~/ 1000} ms'
          ' (${seconds == 0 ? '—' : '${(mb / seconds).toStringAsFixed(1)} MB/s'})'
          '\n${done.note}',
    );
  } on SecretBoxAuthenticationError {
    throw const VaultProblem(
      'That did not open. Either the passphrase is wrong, or the file was '
      'damaged on its way here.',
    );
  } on VaultProblem {
    rethrow;
  } catch (e) {
    throw VaultProblem('That backup could not be opened: $e');
  } finally {
    await file.close();
  }
}

/// Version 2: read, decrypt and append one chunk at a time.
///
/// ── Split three ways, because the total was blaming the wrong thing ────────
/// Opening a 185 MB backup ran at 7.8 MB/s while the same phone, the same
/// isolate and the same library decrypted a test block at 190. The difference
/// between the two: the test throws the plaintext away and this has to keep
/// it. So the reading, the deciphering and the copying are timed apart, and
/// what the cipher hands back is named — a `List<int>` of boxed integers costs
/// an object per byte to copy, and it looks identical in the source.
Future<({Uint8List bytes, String note})> _openChunks(
  RandomAccessFile file,
  VaultHeader header,
  SecretKey key,
  int length,
) async {
  final gcm = AesGcm.with256bits();
  final shape = chunksInFile(length, header);

  /*
    One allocation, filled in place.

    The length of the plaintext is known before a byte is decrypted — that is
    what the chunk arithmetic gives us — so there is no reason to collect the
    pieces and then concatenate them, which on a 185 MB backup is another
    185 MB allocated and copied for nothing.
  */
  final out = Uint8List((shape.count - 1) * header.chunkBytes + shape.lastPlain);
  var at = 0;

  final watch = Stopwatch()..start();
  var reading = 0;
  var deciphering = 0;
  var copying = 0;
  var handedBack = '';

  for (var i = 0; i < shape.count; i++) {
    final last = i == shape.count - 1;
    final plainLength = last ? shape.lastPlain : header.chunkBytes;

    final was = watch.elapsedMicroseconds;
    final record = await file.read(plainLength + vaultTagBytes);
    reading += watch.elapsedMicroseconds - was;

    if (record.length != plainLength + vaultTagBytes) {
      throw const VaultProblem(
        'That backup is damaged: it ends in the middle of a chunk.',
      );
    }

    final read = watch.elapsedMicroseconds;
    final piece = await gcm.decrypt(
      SecretBox(
        Uint8List.sublistView(record, 0, plainLength),
        nonce: chunkNonce(header.nonce, i),
        mac: Mac(Uint8List.sublistView(record, plainLength)),
      ),
      secretKey: key,
      aad: chunkAad(i, last: last),
    );
    final open = watch.elapsedMicroseconds;
    deciphering += open - read;

    if (i == 0) handedBack = piece.runtimeType.toString();

    out.setRange(at, at + piece.length, piece);
    at += piece.length;
    copying += watch.elapsedMicroseconds - open;
  }

  return (
    bytes: out,
    note: '  read       ${reading ~/ 1000} ms'
        '\n  decipher   ${deciphering ~/ 1000} ms'
        '\n  copy out   ${copying ~/ 1000} ms'
        '\n  hands back $handedBack',
  );
}

/// Version 1: one block, the way it was written before chunking.
///
/// Kept because these files exist on people's phones and in their cloud
/// folders, and a backup that stops opening is the only failure this whole
/// feature cannot come back from.
Future<({Uint8List bytes, String note})> _openOneBlock(
  RandomAccessFile file,
  VaultHeader header,
  SecretKey key,
  int length,
) async {
  final body = await file.read(length - header.headerLength);
  final split = body.length - vaultTagBytes;

  final plain = await AesGcm.with256bits().decrypt(
    SecretBox(
      Uint8List.sublistView(body, 0, split),
      nonce: header.nonce,
      mac: Mac(Uint8List.sublistView(body, split)),
    ),
    secretKey: key,
  );

  return (
    bytes: flatBytes(plain),
    note: '  hands back ${plain.runtimeType}',
  );
}

/* ------------------------------------------------------------- the timings */

/// What the crypto actually costs on THIS phone.
///
/// ── Why the app can measure itself ─────────────────────────────────────────
/// Three releases were spent guessing where fifteen seconds went — the UI
/// isolate, then the missing native cipher, then the derivation — and each
/// guess cost a build, a test and a round trip. None of them were measurements.
///
/// This is the measurement. It reports which implementation is in use and how
/// long each half takes, so the next decision is made from numbers.
///
/// Behind the developer tools, and it encrypts a block of zeroes rather than
/// anybody's data.
Future<String> cryptoTimings() => compute(_time, RootIsolateToken.instance);

Future<String> _time(RootIsolateToken? token) async {
  final out = StringBuffer();

  nativeIfPossible(token);
  out.writeln('Cipher:   ${Cryptography.instance.runtimeType}');
  out.writeln('Channels: ${token == null ? 'no token' : 'asked for'}');

  final salt = Uint8List(16);
  final watch = Stopwatch()..start();

  final key = await _keyFrom('a passphrase to measure', salt, vaultIterations);
  await key.extractBytes();
  out.writeln('Derive:   ${watch.elapsedMilliseconds} ms '
      '($vaultIterations rounds)');

  /*
    ── Both directions, and with and without the extra data ──────────────────

    Sealing a 185 MB backup runs at about 80 MB/s and opening the same file
    runs at 7.8. Same phone, same isolate, same `FlutterCryptography` — so the
    asymmetry is in the library rather than in this app, and the question is
    which call falls back to the Dart implementation.

    The suspect is the authenticated data each chunk carries: a plugin that
    implements it natively on the way out and not on the way back would look
    exactly like this. Four numbers settle it, and four numbers is cheaper than
    another guess.
  */
  final gcm = AesGcm.with256bits();
  final block = Uint8List(8 * 1024 * 1024);
  final nonce = Uint8List(12);

  for (final extra in [Uint8List(0), chunkAad(1, last: false)]) {
    final label = extra.isEmpty ? 'plain     ' : 'with extra';

    watch
      ..reset()
      ..start();
    final box = await gcm.encrypt(
      block,
      secretKey: key,
      nonce: nonce,
      aad: extra,
    );
    final sealed = watch.elapsedMilliseconds;

    watch
      ..reset()
      ..start();
    final back = await gcm.decrypt(
      SecretBox(box.cipherText, nonce: nonce, mac: box.mac),
      secretKey: key,
      aad: extra,
    );
    final opened = watch.elapsedMilliseconds;

    /*
      ── The plaintext is USED, and that is the point ──────────────────────────

      This measurement said 190 MB/s while a real restore ran at 7.8, and the
      difference was that this threw the result away. A cipher that hands back
      a list of boxed integers is instant to call and ruinous to read, and a
      benchmark that never reads it reports the first half only.

      So the plaintext is copied into a buffer here exactly as the restore
      copies it into the backup it is rebuilding.
    */
    final into = Uint8List(back.length);
    into.setRange(0, back.length, back);
    final used = watch.elapsedMilliseconds;

    out.writeln('8 MB $label  encrypt ${_rate(sealed)}'
        '   decrypt ${_rate(opened)}'
        '   copy out ${_rate(used - opened)}'
        '   as ${back.runtimeType}');
  }

  return out.toString().trimRight();
}

/// Eight megabytes in this many milliseconds, said both ways.
String _rate(int ms) =>
    ms == 0 ? '0 ms (—)' : '$ms ms (${(8000 / ms).toStringAsFixed(1)} MB/s)';

/* ----------------------------------------------------------------- plumbing */

/// Turns on the platform's own ciphers inside a background isolate.
///
/// Public, because the one isolate that does the whole export has to call it
/// before anything else.
///
/// ── Two steps, and the first is the one people forget ──────────────────────
/// A spawned isolate has no binary messenger, so every plugin in it is dead
/// until `BackgroundIsolateBinaryMessenger.ensureInitialized` is handed a token
/// from the isolate that does have one. Only then is there a channel for
/// `cryptography_flutter` to talk over — and even then the package's own
/// registration ran on the root isolate, so `Cryptography.instance` here is
/// still the pure Dart one until it is set.
///
/// Never throws. A background isolate that cannot reach the platform falls back
/// to Dart implementations that are correct and slower, which is a slow backup
/// rather than a failed one — and worth having on any device where this does
/// not work for a reason nobody predicted.
void nativeIfPossible(RootIsolateToken? token) {
  if (token == null) return;

  try {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    Cryptography.instance = FlutterCryptography.defaultInstance;
  } catch (_) {
    // Dart it is.
  }
}

/// The passphrase, stretched into a 256-bit key.
///
/// The salt comes from the file being opened rather than from anywhere else,
/// which is the whole reason it is written into the header: the same passphrase
/// makes a different key for every backup, so two files cannot be compared to
/// learn anything, and a stolen key opens one file rather than all of them.
Future<SecretKey> _keyFrom(String passphrase, List<int> salt, int rounds) {
  final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: rounds,
    bits: 256,
  );

  return kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(passphrase.trim())),
    nonce: salt,
  );
}

/// A nonce for one file. Public because the one export isolate draws its own.
Uint8List freshNonce() => _randomBytes(12);

/// From the platform's cryptographic source.
///
/// `Random.secure()` throws rather than quietly falling back to a predictable
/// generator when none is available, which is the behaviour worth having when
/// the output is a salt and a nonce.
Uint8List _randomBytes(int count) {
  final rng = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(count, (_) => rng.nextInt(256)),
  );
}
