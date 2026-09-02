/// The folder somebody chose for their backups, and what can be done to it.
///
/// ── Why a folder and not an account ────────────────────────────────────────
/// The backup is the only copy of a person's data that can survive the phone,
/// and until now the only thing standing between them and losing it was a
/// notification asking them to do something by hand.
///
/// The obvious fix is to sign in to a cloud service and upload. That would mean
/// a network permission, an account, an OAuth consent screen, and a privacy
/// policy that no longer gets to say nothing leaves the device.
///
/// Android already has the answer. The person picks one folder, once; the
/// platform hands back a grant that survives reboots; the app writes there and
/// can see nothing else. If the folder they pick happens to be one their cloud
/// app syncs — Drive, Dropbox, OneDrive, a NAS — then their backups are in the
/// cloud, without this app ever knowing what a cloud is.
///
/// So there is no list of supported services here, and there never will be.
/// The app asks the platform for a folder and writes to whatever comes back.
library;

import 'package:flutter/services.dart';

/// The same channel as the incoming card and the widget pinning: one channel to
/// the one activity, rather than three named after their errands.
const MethodChannel _channel = MethodChannel('app.stashit/incoming');

/// One file already in the folder.
class FolderEntry {
  const FolderEntry({required this.uri, required this.name, this.at});

  /// The document's own URI, which is what deleting it needs.
  final String uri;

  final String name;

  /// When the provider says it was last written. Null on providers that do not
  /// keep one — which is why pruning sorts by the date in the NAME instead.
  final DateTime? at;
}

/// Opens Android's folder picker.
///
/// Resolves the tree URI, or null when nothing was chosen — including when
/// somebody backed out, which is not a failure and should not be reported as
/// one. The grant is made persistable on the platform side before this
/// resolves, so the caller can simply save the string.
Future<String?> pickBackupFolder() => _ask<String>('pickFolder');

/// Whether Android still recognises the grant.
///
/// False after a reinstall, or after somebody revoked it in system settings.
/// Distinguishes "never chose one" from "chose one and it is gone", which are
/// different sentences on the Settings card.
Future<bool> folderStillGranted(String tree) async =>
    await _ask<bool>('folderGranted', tree) ?? false;

/// What to call the folder on screen, or null when it cannot be read.
Future<String?> folderLabel(String tree) => _ask<String>('folderLabel', tree);

/// Hands the grant back.
///
/// Called when somebody turns automatic backups off: the app should hold no
/// permission it is not using.
Future<void> forgetBackupFolder(String tree) =>
    _ask<bool>('forgetFolder', tree);

/// Copies a file into the folder, replacing anything already there by that
/// name.
///
/// Returns the name the provider actually gave it, which is not always the one
/// asked for, or null when the write failed. A path rather than bytes: a backup
/// with photographs in it is megabytes, and a method channel is the wrong pipe
/// for that when both sides can see the same disk.
Future<String?> writeToBackupFolder({
  required String tree,
  required String name,
  required String from,
}) =>
    _ask<String>('writeToFolder', {'tree': tree, 'name': name, 'from': from});

/// Everything in the folder. The caller decides which of them are ours.
Future<List<FolderEntry>> listBackupFolder(String tree) async {
  final raw = await _ask<List<Object?>>('listFolder', tree);
  if (raw == null) return const [];

  return [
    for (final row in raw.cast<Map<Object?, Object?>>())
      FolderEntry(
        uri: row['uri']! as String,
        name: row['name']! as String,
        at: row['at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['at']! as int),
      ),
  ];
}

/// Deletes one file the app wrote.
Future<bool> deleteInBackupFolder(String uri) async =>
    await _ask<bool>('deleteInFolder', uri) ?? false;

/*
  ── One shape for every call ────────────────────────────────────────────────

  Every one of these talks to a document provider in another process, which may
  be signed out, uninstalled, out of space or simply gone. None of that is
  exceptional: it is Tuesday for a cloud folder, and the caller's job is to
  report it on a line in Settings rather than to catch it.

  Null on any failure, including on a platform with no channel at all — the
  desktop test runs, and iOS if it ever exists.
*/
Future<T?> _ask<T>(String method, [Object? argument]) async {
  try {
    return await _channel.invokeMethod<T>(method, argument);
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}
