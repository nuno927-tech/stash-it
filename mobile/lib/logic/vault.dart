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
///     byte   8       format version, 1 or 2
///     byte   9       key derivation, currently 1 = PBKDF2-HMAC-SHA256
///     bytes 10..13   iteration count, unsigned 32-bit, big-endian
///     bytes 14..29   salt, 16 bytes
///     bytes 30..41   nonce, 12 bytes
///
/// Version 1 then has one AES-256-GCM ciphertext with its 16-byte tag on the
/// end, and that is the whole file.
///
/// Version 2 adds one field and then chunks:
///
///     bytes 42..45   chunk size, unsigned 32-bit, big-endian
///     bytes 46..     one record per chunk, each being the AES-256-GCM
///                    ciphertext of up to `chunk size` plaintext bytes with
///                    its 16-byte tag on the end
///
/// Every chunk but the last holds exactly `chunk size` bytes, so a reader can
/// find the boundaries from the file length alone. For chunk `i`:
///
///     nonce = the header nonce, with its last four bytes XORed with i
///     authenticated data = i as an unsigned 64-bit big-endian integer,
///                          then one byte: 1 on the final chunk, else 0
///
/// ── Why chunking, and why it is not only about speed ───────────────────────
/// Version 1 encrypted the file in one call. On a 185 MB backup that meant the
/// plaintext, the ciphertext and the assembled output all in memory at once,
/// and it ran at 4 MB/s on a phone whose cipher measures 90 MB/s. Chunks are
/// encrypted and written one at a time, so the phone holds one chunk.
///
/// ── What the nonce and the authenticated data are for ──────────────────────
/// A file cut into separately authenticated pieces is a file whose pieces can
/// be REARRANGED: each one verifies perfectly on its own. Deriving the nonce
/// from the index means a moved chunk is decrypted with the wrong nonce and
/// fails, and putting the index in the authenticated data means it fails for
/// the right reason. The final-chunk flag is what stops the other half of it —
/// lopping chunks off the end, which no per-chunk check would ever notice.
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

/// What this version writes: chunked.
///
/// Written into every file so that a later format can be recognised rather
/// than misread, and so that version 1 files — which exist, on phones — are
/// still opened by the code that understands them.
const int vaultVersion = 2;

/// One block, no chunking. Still read, never written.
const int vaultVersionOneBlock = 1;

/// How much plaintext goes in each chunk.
///
/// Four megabytes is large enough that the per-call cost of reaching the
/// platform's cipher disappears against the work, and small enough that the
/// phone is never holding much. It is written into the header rather than
/// assumed, so changing this number does not orphan a single existing file.
const int vaultChunkBytes = 4 * 1024 * 1024;

/// What AES-GCM puts on the end of every chunk.
const int vaultTagBytes = 16;

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

/// A version 1 header, which is also the part every version shares.
const int vaultHeaderBytes = 8 + 1 + 1 + 4 + _saltBytes + _nonceBytes;

/// A version 2 header: the same, plus the chunk size.
const int vaultHeaderBytesChunked = vaultHeaderBytes + 4;

/// How much of a file to read before you know anything about it.
///
/// Enough for the longest header there is. Reading this much of a version 1
/// file simply picks up the first four bytes of its ciphertext, which are
/// ignored — and reading the whole file to find out what it is was the thing
/// that made this feature slow in the first place.
const int vaultPeekBytes = vaultHeaderBytesChunked;

/// Where the body starts, for a given format version.
int vaultHeaderLength(int version) =>
    version >= vaultVersion ? vaultHeaderBytesChunked : vaultHeaderBytes;

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
    this.chunkBytes = 0,
  });

  final int version;
  final int kdf;
  final int iterations;
  final Uint8List salt;

  /// In version 1 this is the nonce. In version 2 it is the base every
  /// chunk's nonce is derived from — see [chunkNonce].
  final Uint8List nonce;

  /// How much plaintext is in each chunk, or zero in a version 1 file, which
  /// is not chunked at all.
  final int chunkBytes;

  /// Where this file's body starts.
  int get headerLength => vaultHeaderLength(version);

  /// Whether this file is a series of chunks rather than one block.
  bool get isChunked => chunkBytes > 0;
}

/// Why a file cannot be opened, in words for a person.
class VaultProblem implements Exception {
  const VaultProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Builds the bytes that go in front of the ciphertext.
/// Passing `chunkBytes: null` writes the old one-block header, which is what
/// the format tests use to prove that version 1 files still open. Nothing in
/// the app writes one any more.
Uint8List vaultHeader({
  required Uint8List salt,
  required Uint8List nonce,
  int iterations = vaultIterations,
  int kdf = kdfPbkdf2Sha256,
  int? chunkBytes = vaultChunkBytes,
}) {
  if (salt.length != _saltBytes) {
    throw const VaultProblem('The salt is the wrong length.');
  }
  if (nonce.length != _nonceBytes) {
    throw const VaultProblem('The nonce is the wrong length.');
  }

  if (chunkBytes != null && (chunkBytes < 65536 || chunkBytes > 67108864)) {
    throw const VaultProblem('That chunk size is not a sensible one.');
  }

  final out = BytesBuilder();
  out.add(vaultMagic);
  out.addByte(chunkBytes == null ? vaultVersionOneBlock : vaultVersion);
  out.addByte(kdf);
  out.add(_fourBytes(iterations));
  out.add(salt);
  out.add(nonce);
  if (chunkBytes != null) out.add(_fourBytes(chunkBytes));

  return out.toBytes();
}

Uint8List _fourBytes(int n) => Uint8List.fromList([
      (n >> 24) & 0xff,
      (n >> 16) & 0xff,
      (n >> 8) & 0xff,
      n & 0xff,
    ]);

int _readFour(List<int> b, int at) =>
    (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

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

  /*
    ── This checks the HEADER, not the file ──────────────────────────────────

    It used to demand the header plus a tag's worth of body, which read as a
    reasonable "is this a whole file" check and was not one: the caller hands
    this the first few dozen bytes of the file and nothing else, because
    reading the whole thing to find out what it is was exactly the cost this
    feature could not afford. So the check fired on every well-formed backup
    and no locked file could be restored at all.

    A short file is still refused — by `checkVaultLength`, where the length is
    actually known.
  */
  if (bytes.length < vaultHeaderBytes) {
    throw const VaultProblem(
      'That file is too short to be a backup. It may not have finished '
      'downloading.',
    );
  }

  final version = bytes[8];
  if (version != vaultVersion && version != vaultVersionOneBlock) {
    throw VaultProblem(
      'That backup was written by a newer version of Stash it (format '
      '$version). Update the app and try again.',
    );
  }

  if (bytes.length < vaultHeaderLength(version)) {
    throw const VaultProblem(
      'That file is too short to be a backup. It may not have finished '
      'downloading.',
    );
  }

  final kdf = bytes[9];
  if (kdf != kdfPbkdf2Sha256) {
    throw VaultProblem(
      'That backup uses a key method this version does not know ($kdf).',
    );
  }

  final iterations = _readFour(bytes, 10);

  /*
    A sanity range, not a preference.

    A count of zero would mean no stretching at all, and a count of a billion
    would hang the phone for an hour — both of them are what a corrupted or
    hostile header looks like, and neither should be attempted.
  */
  if (iterations < 1000 || iterations > 10000000) {
    throw const VaultProblem('That backup\'s header does not make sense.');
  }

  final chunkBytes =
      version == vaultVersionOneBlock ? 0 : _readFour(bytes, vaultHeaderBytes);

  // The same range the writer enforces. A corrupt field here would otherwise
  // become an allocation of whatever number happened to be in the file.
  if (chunkBytes != 0 && (chunkBytes < 65536 || chunkBytes > 67108864)) {
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
    chunkBytes: chunkBytes,
  );
}

/* --------------------------------------------------------------- the body */

/// Refuses a file that cannot hold what its header promises.
///
/// Separate from [readVaultHeader] because it needs something that function
/// does not have: how long the file actually is.
void checkVaultLength(int fileLength, VaultHeader header) {
  if (fileLength < header.headerLength + vaultTagBytes) {
    throw const VaultProblem(
      'That file is too short to be a backup. It may not have finished '
      'downloading.',
    );
  }
}

/// How many chunks a plaintext of this length becomes.
///
/// Never zero. An empty plaintext is one empty chunk, so that every file has a
/// final chunk carrying the flag that says so — the check that makes lopping
/// the end off a backup detectable.
int chunkCount(int plainLength, int chunkBytes) =>
    plainLength <= 0 ? 1 : (plainLength + chunkBytes - 1) ~/ chunkBytes;

/// How many chunks are in a sealed file of this length, and how long the last
/// one's plaintext is.
///
/// The boundaries are implied rather than stored: every chunk but the last
/// holds exactly `chunkBytes`, so the arithmetic is forced. Anything that does
/// not divide is a damaged file and says so.
({int count, int lastPlain}) chunksInFile(int fileLength, VaultHeader header) {
  final body = fileLength - header.headerLength;
  final unit = header.chunkBytes + vaultTagBytes;

  if (body < vaultTagBytes) {
    throw const VaultProblem(
      'That file is too short to be a backup. It may not have finished '
      'downloading.',
    );
  }

  final whole = body ~/ unit;
  final rest = body % unit;

  if (rest == 0) return (count: whole, lastPlain: header.chunkBytes);

  if (rest < vaultTagBytes) {
    throw const VaultProblem(
      'That backup is damaged: it ends in the middle of a chunk.',
    );
  }

  return (count: whole + 1, lastPlain: rest - vaultTagBytes);
}

/// The nonce for one chunk.
///
/// The header's nonce with its last four bytes XORed with the index, which
/// makes every chunk in a file distinct and — because the base is random per
/// file — every chunk across every file distinct too.
///
/// A nonce reused across two chunks under one key is the one mistake AES-GCM
/// does not survive, which is why this is here, in the pure file, with a test.
Uint8List chunkNonce(Uint8List base, int index) {
  if (base.length != _nonceBytes) {
    throw const VaultProblem('The nonce is the wrong length.');
  }

  final out = Uint8List.fromList(base);
  final tail = ByteData.sublistView(out, _nonceBytes - 4);
  tail.setUint32(0, tail.getUint32(0) ^ (index & 0xffffffff));

  return out;
}

/// What each chunk is authenticated against: its index, and whether it is the
/// last one.
///
/// Not secret and not encrypted — GCM covers it with the tag, which is the
/// whole point. A chunk moved to another position fails, and a file with its
/// tail cut off fails because the chunk that now ends it never claimed to.
Uint8List chunkAad(int index, {required bool last}) {
  final out = Uint8List(9);
  ByteData.sublistView(out).setUint64(0, index);
  out[8] = last ? 1 : 0;

  return out;
}

/// Why the lock cannot be turned off, or null when it can.
///
/// ── The one setting this app refuses to let somebody make worse ───────────
/// Everything else here is a preference. This is not: a document scan is a
/// photograph of a passport, a licence, an insurance certificate — the exact
/// pages somebody impersonates you with — and an unlocked backup is a plain
/// zip sitting in a cloud folder.
///
/// Before scans existed, an unlocked backup risked a list of appliances and
/// what they cost. That is a real loss and a survivable one. This is not the
/// same bet, and offering the same switch for both would be the app pretending
/// it is.
///
/// So the lock goes on when the first scan is taken and stays on while any
/// remain. Deleting the scans turns it back into a choice, which is the honest
/// way out: the setting follows what the phone is actually carrying.
///
/// Pure, and takes a count rather than a database, so the rule is one line to
/// read and one line to test.
String? whyKeepTheLock(int scansHeld) => scansHeld == 0
    ? null
    : 'Your backups hold '
        '${scansHeld == 1 ? 'a scanned document' : '$scansHeld scanned documents'}. '
        'Delete the scans first if you want backups unlocked.';

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
