/// Filing paperwork against an item.
///
/// Ported from `src/lib/docs.ts` and `src/components/DocTiles.tsx`, with the
/// picking left to the widget and the decisions left here.
///
/// ── The kind is the button ────────────────────────────────────────────────
/// Tapping "Receipt" opens the picker already knowing what it is collecting,
/// and the file's own name becomes the title. Nothing is asked that the tap
/// and the file have not already answered.
///
/// The web app learned this the hard way: the item page had a sheet that asked
/// for the kind, then the source, then a title, then Attach — four decisions
/// to file a photograph of a receipt, two of which the person had already made
/// by pressing "Add receipt" to get there.
library;

import 'dart:typed_data';

import '../models/types.dart';

/*
  All six, always.

  Two of them used to hide behind a "Something else" link, on the theory that
  receipts, warranties and manuals are what people attach and the rest is
  clutter. In a card narrow enough to matter the link was being clipped — and
  the fix is not a shorter label. A grid of six is one glance; three plus a
  disclosure is two.
*/
const List<DocKind> docKindOrder = [
  DocKind.receipt,
  DocKind.warranty,
  DocKind.manual,
  DocKind.photo,
  DocKind.other,
];

const Map<DocKind, String> docKindLabels = {
  DocKind.receipt: 'Receipt',
  DocKind.warranty: 'Warranty',
  DocKind.manual: 'Manual',
  DocKind.photo: 'Photo',

  // "Document" rather than "Other", which is what the enum calls it. A tile
  // labelled Other is a tile nobody presses, because it describes the app's
  // filing system rather than the thing in your hand.
  DocKind.other: 'Document',
};

/// A file chosen but not yet written.
///
/// ── Why staging exists at all ─────────────────────────────────────────────
/// A document row points at an item, and on the add form the item does not
/// exist yet. The alternatives were both worse: create the item the moment the
/// sheet opens and leave a husk behind when somebody backs out, or refuse
/// attachments until after the first save, which puts the receipt one screen
/// further away than the moment it is in your hand.
///
/// So new items stage and write on save; edits write immediately, because
/// there is already something to point at.
class PendingDoc {
  const PendingDoc({
    required this.kind,
    required this.title,
    this.bytes,
    this.mime,
    this.url,
  });

  final DocKind kind;
  final String title;

  /// The file. Null for a link.
  final Uint8List? bytes;
  final String? mime;

  /// Somewhere on the web. Null for a file.
  final String? url;

  bool get isLink => url != null;

  /// What it costs to keep. Shown while staged, because six photographs of a
  /// receipt is a decision somebody may want to revisit before saving.
  int get sizeBytes => bytes?.length ?? 0;
}

/// The file's own name, tidied into a title.
///
/// Drops the path and the extension, turns separators into spaces, and
/// collapses the runs. `IMG_20240817_101233.jpg` stays as it is rather than
/// being decoded into a date — a camera filename is meaningless either way,
/// and a wrong date is worse than an ugly one.
/// The word for a kind of attachment, when nobody gave it a title.
String docWord(DocKind kind) => switch (kind) {
      DocKind.receipt => 'Receipt',
      DocKind.manual => 'Manual',
      DocKind.warranty => 'Warranty',
      DocKind.photo => 'Photo',
      DocKind.other => 'File',
    };

/// A filename somebody would recognise in their downloads, with a real
/// extension so the receiving app knows what it is holding.
///
/// Shared, because two screens hand these files out now: the chip on the item
/// view and the claim sheet. A claim whose receipt arrives called `blob.bin`
/// is a claim the desk cannot open.
String attachmentFileName(Doc doc, String mime) {
  final base = (doc.title?.trim().isNotEmpty ?? false)
      ? doc.title!.trim()
      : docWord(doc.kind);

  final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '').trim();
  final ext = switch (mime) {
    'application/pdf' => 'pdf',
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'bin',
  };

  return safe.toLowerCase().endsWith('.$ext') ? safe : '$safe.$ext';
}

String titleFromFilename(String path) {
  final name = path.split(RegExp(r'[/\\]')).last;

  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;

  final words = stem
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // A file called ".pdf", or one whose name was entirely underscores. The kind
  // is a better title than nothing, and the caller has it.
  return words;
}

/// A title for a document, falling back to what kind of thing it is.
String docTitle(DocKind kind, String fromFile) {
  final title = fromFile.trim();
  return title.isEmpty ? docKindLabels[kind]! : title;
}

/// What a picked file most likely is, by extension.
///
/// Only used when the picker does not say. Deliberately short: the mime type
/// decides whether the app tries to draw the bytes as a picture, and every
/// unknown answering "not a picture" is the safe way round.
String mimeFor(String path) {
  final name = path.toLowerCase();

  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
  if (name.endsWith('.gif')) return 'image/gif';
  if (name.endsWith('.pdf')) return 'application/pdf';

  return 'application/octet-stream';
}

/// True when the app can show these bytes as a picture.
bool isImage(String? mime) => mime != null && mime.startsWith('image/');

/// Makes a typed address out of what somebody pasted.
///
/// People paste `drive.google.com/...` without a scheme constantly, and a URL
/// with no scheme opens nothing. Returns null when there is nothing usable, so
/// the caller can refuse rather than saving a link that goes nowhere.
String? tidyUrl(String typed) {
  final text = typed.trim();
  if (text.isEmpty) return null;

  final withScheme = text.contains('://') ? text : 'https://$text';

  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return null;

  return uri.toString();
}
