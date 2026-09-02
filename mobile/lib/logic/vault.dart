/// The shape of an encrypted backup, without any cryptography in it.
///
/// ── Why the header is its own file ─────────────────────────────────────────
/// Everything about this feature that can go quietly wrong is in the header:
/// the magic that decides whether a file is encrypted at all, the salt that has
/// to be the same one that made the key, the iteration count a future version
/// will want to raise. Get any of those subtly wrong and the failure is not a
/// crash — it is a backup that will not open, discovered on the day somebody
/// needs it.
///
/// So the layout is written here, in pure Dart, with a test. `io/vault.dart`
/// does the actual encrypting and cannot be tested without a plugin.
///
/// ── A backup you can still open without this app ───────────────────────────
/// The app's whole argument for a plain zip was that somebody with a broken
/// install can open the file and read their own data. Encryption takes that
/// away, and the only honest replacement is a format written down plainly
/// enough that a person with the passphrase and an afternoon can decrypt it
/// with standard tools. That is what this file is for as much as the parsing.
///
///     bytes  0..7    "STASHVLT"
///     byte   8       format version, currently 1
///     byte   9       key derivation, currently 1 = PBKDF2-HMAC-SHA256
///     bytes 10..13   iteration count, unsigned 32-bit, big-endian
///     bytes 14..29   salt, 16 bytes
///     bytes 30..41   nonce, 12 bytes
///     bytes 42..     AES-256-GCM ciphertext with its 16-byte tag on the end
///
/// The plaintext inside is exactly the `.stashit` zip an unencrypted backup
/// would have been, byte for byte.
library;

import 'dart:convert';
import 'dart:typed_data';

/// What every encrypted backup starts with.
///
/// Eight bytes, chosen to be unmistakable: a zip starts `PK`, so no unencrypted
/// backup this app has ever written can be confused for one of these, and no
/// encrypted one can be handed to the unzipper by accident.
final Uint8List vaultMagic = Uint8List.fromList(ascii.encode('STASHVLT'));

/// The only format so far. Written into every file so that a later one can be
/// recognised rather than misread.
const int vaultVersion = 1;

/// PBKDF2 with HMAC-SHA256.
///
/// Argon2id is the better password hash and this is not it — deliberately.
/// Argon2 in pure Dart is slow enough on a phone to be felt, and the platform
/// acceleration this app has covers AES and SHA, not Argon2. A high PBKDF2
/// count is the honest trade: weaker against custom hardware, and actually fast
/// enough that people leave the feature on.
///
/// The id is in the header so a future version can raise its hand.
const int kdfPbkdf2Sha256 = 1;

/// OWASP's 2023 floor for PBKDF2-HMAC-SHA256, and about a second on a phone.
///
/// Stored in the file rather than assumed, so raising it later does not orphan
/// every backup somebody already has.
const int vaultIterations = 210000;

const int _saltBytes = 16;
const int _nonceBytes = 12;

/// Where the ciphertext starts. Everything before it is the header above.
const int vaultHeaderBytes = 8 + 1 + 1 + 4 + _saltBytes + _nonceBytes;

/// Whether these bytes are an encrypted backup.
///
/// Read before anything else on every restore. A plain `.stashit` from any
/// earlier version answers false and goes down the path it always did, which is
/// what keeps every backup ever made openable.
bool looksEncrypted(List<int> bytes) {
  if (bytes.length < vaultMagic.length) return false;

  for (var i = 0; i < vaultMagic.length; i++) {
    if (bytes[i] != vaultMagic[i]) return false;
  }

  return true;
}

/// A header, read back off a file.
class VaultHeader {
  const VaultHeader({
    required this.version,
    required this.kdf,
    required this.iterations,
    required this.salt,
    required this.nonce,
  });

  final int version;
  final int kdf;
  final int iterations;
  final Uint8List salt;
  final Uint8List nonce;
}

/// Why a file cannot be opened, in words for a person.
class VaultProblem implements Exception {
  const VaultProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Builds the bytes that go in front of the ciphertext.
Uint8List vaultHeader({
  required Uint8List salt,
  required Uint8List nonce,
  int iterations = vaultIterations,
  int kdf = kdfPbkdf2Sha256,
}) {
  if (salt.length != _saltBytes) {
    throw const VaultProblem('The salt is the wrong length.');
  }
  if (nonce.length != _nonceBytes) {
    throw const VaultProblem('The nonce is the wrong length.');
  }

  final out = BytesBuilder();
  out.add(vaultMagic);
  out.addByte(vaultVersion);
  out.addByte(kdf);
  out.add([
    (iterations >> 24) & 0xff,
    (iterations >> 16) & 0xff,
    (iterations >> 8) & 0xff,
    iterations & 0xff,
  ]);
  out.add(salt);
  out.add(nonce);

  return out.toBytes();
}

/// Reads one back, or says why it cannot.
///
/// ── Everything here is a refusal with a sentence ───────────────────────────
/// This is the second place in the app where an untrusted file arrives — see
/// `parseBundle` for the first — and the same rule applies: a file can have
/// been truncated by a mail client, half-synced by a cloud folder, or written
/// by a version that did not exist yet. None of those is a crash.
VaultHeader readVaultHeader(List<int> bytes) {
  if (!looksEncrypted(bytes)) {
    throw const VaultProblem('That is not an encrypted Stash it backup.');
  }

  if (bytes.length < vaultHeaderBytes + 16) {
    // Header plus at least a GCM tag. Anything shorter cannot be a whole file
    // however well-formed the front of it looks.
    throw const VaultProblem(
      'That file is too short to be a backup. It may not have finished '
      'downloading.',
    );
  }

  final version = bytes[8];
  if (version != vaultVersion) {
    throw VaultProblem(
      'That backup was written by a newer version of Stash it (format '
      '$version). Update the app and try again.',
    );
  }

  final kdf = bytes[9];
  if (kdf != kdfPbkdf2Sha256) {
    throw VaultProblem(
      'That backup uses a key method this version does not know ($kdf).',
    );
  }

  final iterations =
      (bytes[10] << 24) | (bytes[11] << 16) | (bytes[12] << 8) | bytes[13];

  /*
    A sanity range, not a preference.

    A count of zero would mean no stretching at all, and a count of a billion
    would hang the phone for an hour — both of them are what a corrupted or
    hostile header looks like, and neither should be attempted.
  */
  if (iterations < 1000 || iterations > 10000000) {
    throw const VaultProblem('That backup\'s header does not make sense.');
  }

  return VaultHeader(
    version: version,
    kdf: kdf,
    iterations: iterations,
    salt: Uint8List.fromList(bytes.sublist(14, 14 + _saltBytes)),
    nonce: Uint8List.fromList(
      bytes.sublist(14 + _saltBytes, vaultHeaderBytes),
    ),
  );
}

/// Whether a passphrase is good enough to be worth setting.
///
/// ── One rule, and it is length ─────────────────────────────────────────────
/// Not "one capital, one number, one symbol". Those rules produce `Passw0rd!`
/// and nothing else, and they are the reason people write passwords on cards.
/// Length is the only requirement that reliably buys entropy from a human, and
/// the app says so rather than making somebody guess what it wants.
///
/// Twelve, because this passphrase guards a file that may sit in somebody's
/// cloud account for years and cannot be rate-limited by anybody.
String? whyNotAPassphrase(String candidate) {
  final trimmed = candidate.trim();

  if (trimmed.isEmpty) return 'Type something first.';
  if (trimmed.length < 12) {
    return 'Twelve characters or more. Three or four unrelated words beats '
        'anything short and clever.';
  }

  return null;
}
