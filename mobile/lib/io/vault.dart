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
import 'dart:math';
import 'dart:typed_data';

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

  See `_nativeIfPossible`. It is wrapped in a `try` because a background
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
Future<({Uint8List salt, Uint8List key})?> _lockingKey() async {
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
  _nativeIfPossible(work.token);

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

  So it is timed. `lockBackup` and `unlockBackup` leave their phase timings
  here and the developer probe prints them. Nothing else reads it, and it is a
  string rather than numbers because its only consumer is a person reading a
  screen.
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
Uint8List _flat(List<int> bytes) =>
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

/* ------------------------------------------------------------ the locking */

/// Wraps the bytes of a backup so only the passphrase opens them.
///
/// Takes no passphrase: it uses the key this phone already derived — see
/// `_lockingKey`. The nonce is drawn here, on the main isolate, because
/// `Random.secure()` is the platform's own source and a nonce reused across two
/// files under one key is the one mistake GCM does not forgive.
Future<Uint8List> lockBackup(List<int> plain) async {
  final material = await _lockingKey();
  if (material == null) {
    throw const VaultProblem('No passphrase is set.');
  }

  final watch = Stopwatch()..start();
  final flat = _flat(plain);
  final flattened = watch.elapsedMilliseconds;

  final done = await compute(_lock, (
    plain: flat,
    salt: material.salt,
    key: material.key,
    nonce: _randomBytes(12),
    // Taken here. The isolate cannot ask for its own — the token only exists
    // on the isolate that has the engine.
    token: RootIsolateToken.instance,
  ));

  lastVaultTimings = 'lock ${(flat.length / 1024 / 1024).toStringAsFixed(1)} MB'
      '\n  flatten   $flattened ms'
      '\n${done.timings}'
      '\n  round trip ${watch.elapsedMilliseconds} ms total';

  return done.bytes;
}

/// The isolate's half of [lockBackup]. Top-level, because `compute` cannot send
/// a closure.
Future<({Uint8List bytes, String timings})> _lock(
  ({
    Uint8List plain,
    Uint8List salt,
    Uint8List key,
    Uint8List nonce,
    RootIsolateToken? token,
  }) work,
) async {
  final watch = Stopwatch()..start();

  _nativeIfPossible(work.token);
  final started = watch.elapsedMilliseconds;

  final box = await AesGcm.with256bits().encrypt(
    work.plain,
    secretKey: SecretKey(work.key),
    nonce: work.nonce,
  );
  final encrypted = watch.elapsedMilliseconds;

  /*
    Assembled by hand rather than with a `BytesBuilder`.

    The cipher hands back a `List<int>` which may or may not be boxed, and
    `BytesBuilder.add` on a boxed list of a hundred million integers is a
    hundred million reads. One allocation and two `setRange`s instead — and
    `_flat` makes sure the source is a typed list before either.
  */
  final header = vaultHeader(salt: work.salt, nonce: work.nonce);
  final cipher = _flat(box.cipherText);
  final tag = _flat(box.mac.bytes);

  final body = header.length + cipher.length;
  final out = Uint8List(body + tag.length)
    ..setRange(0, header.length, header)
    ..setRange(header.length, body, cipher)
    // GCM's tag, on the end where every other implementation expects it.
    ..setRange(body, body + tag.length, tag);

  return (
    bytes: out,
    timings: '  isolate up $started ms'
        '\n  encrypt    ${encrypted - started} ms'
        '\n  assemble   ${watch.elapsedMilliseconds - encrypted} ms',
  );
}


/// Opens one, or says why it did not.
///
/// Throws [VaultProblem] with a sentence for a person. A wrong passphrase and a
/// damaged file land in the same place, because GCM cannot tell them apart —
/// and being told "wrong passphrase" about a truncated download would send
/// somebody looking in the wrong place for an hour.
Future<Uint8List> unlockBackup(List<int> sealed, String passphrase) async {
  // Read here so a malformed file is refused with a sentence before an isolate
  // is spawned for it — see `readVaultHeader`, which throws for a person.
  final header = readVaultHeader(sealed);

  /*
    ── A file this phone made opens without the slow part ────────────────────

    The commonest restore by a distance is somebody's own backup on their own
    phone, and the key for that is already derived and kept — see
    `_lockingKey`. The salt in the header is what says so: same salt, same
    passphrase, same key.

    Anything else — another phone, an older passphrase — falls through to the
    210,000 rounds, which is correct and happens once.
  */
  final watch = Stopwatch()..start();
  final mine = await _lockingKey();
  final gotKey = watch.elapsedMilliseconds;

  final flat = _flat(sealed);
  final flattened = watch.elapsedMilliseconds;

  final done = await compute(_unlock, (
    sealed: flat,
    passphrase: passphrase,
    key: mine != null && _sameBytes(mine.salt, header.salt) ? mine.key : null,
    token: RootIsolateToken.instance,
  ));

  lastVaultTimings =
      'unlock ${(flat.length / 1024 / 1024).toStringAsFixed(1)} MB'
      '\n  find key   $gotKey ms'
      '\n  flatten    ${flattened - gotKey} ms'
      '\n${done.timings}'
      '\n  round trip ${watch.elapsedMilliseconds} ms total';

  return done.bytes;
}

/// Whether two byte strings are the same. Only ever used on salts, which are
/// not secret — a constant-time compare would be theatre here.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}

/// The isolate's half of [unlockBackup].
Future<({Uint8List bytes, String timings})> _unlock(
  ({
    Uint8List sealed,
    String passphrase,
    Uint8List? key,
    RootIsolateToken? token,
  }) work,
) async {
  final watch = Stopwatch()..start();

  _nativeIfPossible(work.token);
  final started = watch.elapsedMilliseconds;

  final header = readVaultHeader(work.sealed);

  /*
    Views, not copies.

    `sublist` allocates and copies; on a file of this size that is two more
    copies of everything for no reason. `Uint8List.sublistView` hands back a
    window onto the same bytes.
  */
  final split = work.sealed.length - 16;
  final cipher = Uint8List.sublistView(work.sealed, vaultHeaderBytes, split);
  final tag = Uint8List.sublistView(work.sealed, split);
  final sliced = watch.elapsedMilliseconds;

  // Already derived on this phone, or derived here the slow way for a file
  // that came from somewhere else.
  final key = work.key != null
      ? SecretKey(work.key!)
      : await _keyFrom(work.passphrase, header.salt, header.iterations);
  final gotKey = watch.elapsedMilliseconds;

  try {
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(cipher, nonce: header.nonce, mac: Mac(tag)),
      secretKey: key,
    );
    final decrypted = watch.elapsedMilliseconds;

    return (
      bytes: _flat(plain),
      timings: '  isolate up $started ms'
          '\n  slice      ${sliced - started} ms'
          '\n  derive     ${gotKey - sliced} ms'
          '\n  decrypt    ${decrypted - gotKey} ms'
          '\n  flatten    ${watch.elapsedMilliseconds - decrypted} ms',
    );
  } on SecretBoxAuthenticationError {
    throw const VaultProblem(
      'That did not open. Either the passphrase is wrong, or the file was '
      'damaged on its way here.',
    );
  } catch (e) {
    throw VaultProblem('That backup could not be opened: $e');
  }
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

  _nativeIfPossible(token);
  out.writeln('Cipher:   ${Cryptography.instance.runtimeType}');
  out.writeln('Channels: ${token == null ? 'no token' : 'asked for'}');

  final salt = Uint8List(16);
  final watch = Stopwatch()..start();

  final key = await _keyFrom('a passphrase to measure', salt, vaultIterations);
  await key.extractBytes();
  out.writeln('Derive:   ${watch.elapsedMilliseconds} ms '
      '($vaultIterations rounds)');

  // Two sizes, so the answer says whether the cost is per-call or per-byte —
  // which is the difference between a slow cipher and a slow channel.
  for (final mb in [1, 8]) {
    final block = Uint8List(mb * 1024 * 1024);
    watch
      ..reset()
      ..start();

    await AesGcm.with256bits().encrypt(
      block,
      secretKey: key,
      nonce: Uint8List(12),
    );

    final ms = watch.elapsedMilliseconds;
    final rate = ms == 0 ? '—' : '${(mb * 1000 / ms).toStringAsFixed(1)} MB/s';
    out.writeln('Encrypt:  $mb MB in $ms ms  ($rate)');
  }

  return out.toString().trimRight();
}

/* ----------------------------------------------------------------- plumbing */

/// Turns on the platform's own ciphers inside a background isolate.
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
void _nativeIfPossible(RootIsolateToken? token) {
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
