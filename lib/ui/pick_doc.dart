/// Turning a tile tap into bytes.
///
/// Kept apart from the tiles and from the form: the tiles know what a tile
/// looks like, the form knows what to do with a document, and this knows about
/// two plugins that both return files in slightly different shapes.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../logic/attachments.dart';
import '../models/types.dart';
import 'doc_tiles.dart';
import 'feedback.dart';
import 'theme.dart';

/*
  ── Read here, not by the picker ────────────────────────────────────────────

  `withData` stays off, exactly as it is in the restore flow. With it on, the
  picker reads the whole file on the Java side and hands the bytes across the
  platform channel — which killed the process outright, natively, on a large
  file, with nothing Dart could catch.

  A receipt is small enough that it would never have hit that. A forty-page
  scanned manual is not, and the two arrive through the same tile.
*/
Future<List<PendingDoc>> pickDocs(DocKind kind, DocSource source) async {
  if (source == DocSource.camera) return _photograph(kind);

  final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
  final files = picked?.files ?? const <PlatformFile>[];

  final out = <PendingDoc>[];
  for (final file in files) {
    final path = file.path;
    if (path == null) continue;

    final bytes = await File(path).readAsBytes();
    out.add(PendingDoc(
      kind: kind,
      title: docTitle(kind, titleFromFilename(file.name)),
      bytes: bytes,
      mime: mimeFor(file.name),
    ));
  }

  return out;
}

/*
  ── One photograph at a time, and why that is not a limitation ──────────────

  `image_picker` will return several from the gallery but only one from the
  camera, because the camera app closes when the shutter fires. A warranty is
  routinely several pages, so the answer is not multi-capture — it is that
  pressing the corner again is quick, and each page arrives as its own
  document with its own name.

  `imageQuality` is deliberately set. A modern phone camera produces an eight
  megabyte photograph of a piece of A4, and these bytes go **into the encrypted
  database** rather than onto disk — so every one of them is carried in every
  backup and read back on every restore. 85 is indistinguishable on a receipt
  and roughly a fifth of the size.
*/
Future<List<PendingDoc>> _photograph(DocKind kind) async {
  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 85,
    maxWidth: 2400,
  );
  if (shot == null) return const [];

  final bytes = await shot.readAsBytes();

  return [
    PendingDoc(
      kind: kind,
      // A camera filename says nothing, so the kind is the better title —
      // "Receipt" beats "IMG_20240817_101233" on a row.
      title: docKindLabels[kind]!,
      bytes: bytes,
      mime: 'image/jpeg',
    ),
  ];
}

/// Asks for an address, and refuses one that could not be an address.
///
/// A sheet rather than a dialog, so it sits where every other question in this
/// app sits and the keyboard has somewhere to go.
Future<PendingDoc?> askForLink(BuildContext context) async {
  final c = StashColors.of(context);
  final url = TextEditingController();
  final title = TextEditingController();

  final saved = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: c.slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'On the web',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'For a receipt that lives in your email, or a manual on the '
            "maker's site. Nothing is downloaded — this is a link.",
            style: TextStyle(fontFamily: fontBody, fontSize: 13, color: c.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: url,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: TextStyle(fontFamily: fontBody, color: c.text),
            decoration: InputDecoration(
              hintText: 'example.com/my-receipt',
              filled: true,
              fillColor: c.slate600,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: title,
            style: TextStyle(fontFamily: fontBody, color: c.text),
            decoration: InputDecoration(
              hintText: 'What to call it (optional)',
              filled: true,
              fillColor: c.slate600,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: c.gold,
              foregroundColor: c.onGold,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            child: Text(
              'Link it',
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: c.onGold,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  final tidied = saved == true ? tidyUrl(url.text) : null;
  final named = title.text.trim();

  url.dispose();
  title.dispose();

  if (tidied == null) return null;

  feedback(Cue.attach);

  return PendingDoc(
    kind: DocKind.other,
    // The host, when nothing was typed. Better than "Document" on a row, and
    // it is the part somebody would recognise.
    title: named.isEmpty ? (Uri.tryParse(tidied)?.host ?? 'Link') : named,
    url: tidied,
  );
}
