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

/// Declared on the attachment so Android has something better than a guess.
///
/// It matches the manifest's own filter — see AndroidManifest.xml — which is
/// what lets a card that arrives by mail or chat offer this app as a way to
/// open it. Left unset, share_plus infers from the extension, and an unknown
/// extension becomes `application/octet-stream`, which fewer apps accept.
const String cardMimeType = 'application/x-stash-it-card';

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

/*
  ── Two ways to send, because the phone has two ─────────────────────────────

  A card is a file, and **a text message cannot carry a file**. SMS has no
  attachment at all and MMS takes pictures and contact cards, not an
  application's own format — so Android filters every messaging app out of the
  share sheet the moment an attachment is on it. Nothing in this app can change
  that; it is what the transport is.

  What CAN go by text is the message, and the message was always written to
  stand on its own — see `cardSummary`. So there are two sends rather than one
  send that quietly fails half the time:

    `shareCard`     the file plus the words, for mail, chat apps, a drive
    `shareSummary`  the words alone, which every keyboard on earth accepts

  The alternative was one button that offers a share sheet with the messaging
  apps mysteriously missing, and no way to find out why.
*/

/// Gathers, writes and hands the file and the words to the share sheet.
Future<void> shareCard(StashDatabase db, CardPick pick) async {
  final contents = await gatherCard(db, pick);
  final bytes = writeCard(contents);

  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, cardFileName(contents.summarySource)));
  await file.writeAsBytes(bytes);

  // share_plus 10's API, the same call the backup uses — see the note in
  // settings_tab.dart about version 11.
  await Share.shareXFiles(
    [XFile(file.path, mimeType: cardMimeType)],
    text: summaryFor(contents),
    subject: 'From my Stash it',
  );
}

/// The words on their own — no attachment, so nothing is filtered out.
Future<void> shareSummary(StashDatabase db, CardPick pick) async {
  final contents = await gatherCard(db, pick);
  await Share.share(summaryFor(contents), subject: 'From my Stash it');
}

/// The message body, from the rows the card was built from.
String summaryFor(CardContents contents) => cardSummary(
      items: contents.summarySource.items,
      papers: contents.summarySource.papers,
      subscriptions: contents.summarySource.subscriptions,
    );
