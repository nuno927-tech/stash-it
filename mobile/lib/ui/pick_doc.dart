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
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'theme.dart';

enum PickSource { camera, files, remove }

/*
  ── Asked after the tap, not aimed at before it ─────────────────────────────

  Both the item's photograph and the six attachment tiles used to be split
  controls: a body that opened the file picker and a fifteen-pixel corner that
  opened the camera. Seven of them on one form, fourteen tap targets, and no
  way to tell from looking which half of a tile you were about to hit.

  One target each now, and this asks afterwards. That is also the honest order
  — the decision is "file a receipt", and where the bytes come from is a detail
  of that.

  `image_picker` rather than trusting the file picker's own "take a photo": it
  exists on some devices and goes straight to the gallery on others, which
  loses the camera entirely on exactly the phones where photographing a receipt
  is the only way it would ever get filed.
*/
Future<PickSource?> askPickSource(
  BuildContext context, {
  required String title,

  /// Offered only when there is something to take away. A greyed-out row is a
  /// row you still have to read.
  bool canRemove = false,
  String removeLabel = 'Remove it',
  String removeNote = 'Everything else is kept',
}) {
  final c = StashColors.of(context);

  Widget row(IconData icon, String label, String note, PickSource value, Color ink) {
    return InkWell(
      onTap: () {
        feedback(Cue.tap);
        Navigator.of(context).pop(value);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: ink),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(fontFamily: fontBody, fontSize: 12.5, color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  return showModalBottomSheet<PickSource>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: c.slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: fontDisplay,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
          ),
          row(Icons.photo_camera_outlined, 'Take a photo', 'Opens the camera',
              PickSource.camera, c.text),
          Container(height: 1, color: c.line),
          row(Icons.folder_outlined, 'Choose a file', 'Something already on this phone',
              PickSource.files, c.text),
          if (canRemove) ...[
            Container(height: 1, color: c.line),
            row(Icons.delete_outline, removeLabel, removeNote, PickSource.remove, c.ember),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/*
  ── Read here, not by the picker ────────────────────────────────────────────

  `withData` stays off, exactly as it is in the restore flow. With it on, the
  picker reads the whole file on the Java side and hands the bytes across the
  platform channel — which killed the process outright, natively, on a large
  file, with nothing Dart could catch.

  A receipt is small enough that it would never have hit that. A forty-page
  scanned manual is not, and the two arrive through the same tile.
*/
Future<List<PendingDoc>> pickDocs(DocKind kind, PickSource source) async {
  if (source == PickSource.camera) return _photograph(kind);

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
            decoration: sunkenInput(hint: 'example.com/my-receipt', fill: c.slate600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: title,
            style: TextStyle(fontFamily: fontBody, color: c.text),
            decoration: sunkenInput(hint: 'What to call it (optional)', fill: c.slate600),
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
