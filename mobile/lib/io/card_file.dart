/// Turning a card into a file, and a file back into a card.
///
/// The two things `logic/card.dart` refuses to do — zip and hash — in the same
/// place `io/bundle_file.dart` does them for backups, and by calling the same
/// functions. A card is a backup's format with a different name on the
/// manifest, which is deliberate: one zip writer, one checksum, one parser,
/// and a single flag deciding which door a file is allowed through.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/card_export.dart';
import '../db/tables.dart';
import '../logic/bundle.dart';
import '../logic/card.dart';
import 'bundle_file.dart';

/// `.stashcard`, and the extension matters as much as the manifest.
///
/// Android decides what to offer to open a file largely by its name. Sharing
/// a card as `.stashit` would put it in front of the restore flow, and a
/// restore replaces the database — see the note beside `cardFormat`.
const String cardExtension = 'stashcard';

/// `kettle.stashcard`, or `3-things.stashcard`.
///
/// Named after what is inside rather than after a timestamp, because this file
/// arrives in somebody's messages beside a photo of a dog and needs to say
/// what it is at a glance.
String cardFileName(CardSource source) {
  final all = [
    ...source.items.map((i) => i.name),
    ...source.papers.map((p) => p.label),
    ...source.subscriptions.map((s) => s.name),
  ];

  if (all.length == 1) {
    final slug = all.single
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isNotEmpty) return '$slug.$cardExtension';
  }
  return '${all.length}-things.$cardExtension';
}

/// Builds the bytes for a card. Same writer as a backup, different manifest.
List<int> writeCard(CardContents contents) => writeBundle(
      tables: contents.tables,
      blobs: contents.blobs,
      manifestOverrides: {
        'format': cardFormat,
        'formatVersion': cardFormatVersion,
        'counts': {
          'items': (contents.tables['items'] as List?)?.length ?? 0,
          'docs': (contents.tables['docs'] as List?)?.length ?? 0,
          'blobs': contents.blobs.length,
        },
      },
    );

/// Reads a card. Passing [cardFormat] is what makes this refuse a backup.
ParsedBundle parseCardBytes(List<int> bytes) => parseBundle(
      unzipBundle(bytes),
      sha256Hex: sha256Hex,
      format: cardFormat,
    );

/// Gathers, writes and hands the whole thing to the share sheet.
///
/// The summary text goes as the message body and the file as the attachment,
/// which is the whole point of the format decision: a recipient without the
/// app reads the message and is done, and one with it taps the file.
Future<void> shareCard(StashDatabase db, CardPick pick) async {
  final contents = await gatherCard(db, pick);
  final bytes = writeCard(contents);

  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, cardFileName(contents.summarySource)));
  await file.writeAsBytes(bytes);

  final text = cardSummary(
    items: contents.summarySource.items,
    papers: contents.summarySource.papers,
    subscriptions: contents.summarySource.subscriptions,
  );

  // share_plus 10's API, the same call the backup uses — see the note in
  // settings_tab.dart about version 11.
  await Share.shareXFiles(
    [XFile(file.path)],
    text: text,
    subject: 'From my Stash it',
  );
}
