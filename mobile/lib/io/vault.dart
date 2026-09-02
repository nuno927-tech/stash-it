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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logic/vault.dart';

/// The same store the database key uses, with the same options — see
/// `db/open_flutter.dart`. Different key name, same hardware backing.
const FlutterSecureStorage _store = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

const String _passphraseName = 'stash_it_backup_passphrase';

/// AES-256-GCM. `cryptography_flutter` hands this to javax.crypto on Android,
/// which is the difference between a few seconds and a few minutes on a backup
/// with photographs in it.
final Cipher _cipher = AesGcm.with256bits();

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
Future<void> setBackupPassphrase(String passphrase) =>
    _store.write(key: _passphraseName, value: passphrase.trim());

/// Turns encryption off.
///
/// Refused elsewhere while a document scan exists — see `whyKeepTheLock`. This
/// function does as it is told; the judgement is the caller's.
Future<void> clearBackupPassphrase() => _store.delete(key: _passphraseName);

/* ------------------------------------------------------------ the locking */

/// Wraps the bytes of a backup so only the passphrase opens them.
Future<Uint8List> lockBackup(List<int> plain, String passphrase) async {
  final salt = _randomBytes(16);
  final nonce = _randomBytes(12);

  final key = await _keyFrom(passphrase, salt, vaultIterations);

  final box = await _cipher.encrypt(
    plain,
    secretKey: key,
    nonce: nonce,
  );

  final out = BytesBuilder();
  out.add(vaultHeader(salt: salt, nonce: nonce));
  out.add(box.cipherText);
  // GCM's tag, on the end where every other implementation expects it.
  out.add(box.mac.bytes);

  return out.toBytes();
}

/// Opens one, or says why it did not.
///
/// Throws [VaultProblem] with a sentence for a person. A wrong passphrase and a
/// damaged file land in the same place, because GCM cannot tell them apart —
/// and being told "wrong passphrase" about a truncated download would send
/// somebody looking in the wrong place for an hour.
Future<Uint8List> unlockBackup(List<int> sealed, String passphrase) async {
  final header = readVaultHeader(sealed);

  final body = sealed.sublist(vaultHeaderBytes);
  final split = body.length - 16;

  final key = await _keyFrom(passphrase, header.salt, header.iterations);

  try {
    final plain = await _cipher.decrypt(
      SecretBox(
        body.sublist(0, split),
        nonce: header.nonce,
        mac: Mac(body.sublist(split)),
      ),
      secretKey: key,
    );

    return Uint8List.fromList(plain);
  } on SecretBoxAuthenticationError {
    throw const VaultProblem(
      'That did not open. Either the passphrase is wrong, or the file was '
      'damaged on its way here.',
    );
  } catch (e) {
    throw VaultProblem('That backup could not be opened: $e');
  }
}

/* ----------------------------------------------------------------- plumbing */

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
