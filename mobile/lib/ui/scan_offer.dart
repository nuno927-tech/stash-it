/// Offering to photograph a document, once it has been saved.
///
/// ── Why after the save and not during it ───────────────────────────────────
/// The document wizard asks three questions, one to a screen, and a fourth
/// screen for an optional photograph would make the quick path longer for
/// everybody in order to serve the times anybody takes one. The tour's rule
/// applies to a wizard too: every screen added has to displace one.
///
/// So the offer comes after, the way `showStashThePaper` follows an item save
/// — at the moment the document is in your hand and the record it belongs to
/// already exists. Declining costs one tap and leaves a perfectly good record
/// behind; the document view offers it again whenever.
///
/// ── Only when there is nothing attached yet ────────────────────────────────
/// Somebody who used the long form and already added a scan does not need to
/// be asked, and an offer that arrives after you have done the thing reads as
/// an app that was not paying attention.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../models/types.dart';
import 'feedback.dart';
import 'pick_doc.dart';
import 'scan_gate.dart';
import 'scout.dart';
import 'theme.dart';

/// Asks, and writes whatever comes back against [paperId].
Future<void> offerToScan(
  BuildContext context, {
  required Repository repo,
  required String paperId,
  required String label,
}) async {
  final already = await repo.docsForPaper(paperId);
  if (already.isNotEmpty || !context.mounted) return;

  final c = StashColors.of(context);
  feedback(Cue.expand);

  final wants = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: c.slate800,
      title: Row(
        children: [
          const Scout(pose: ScoutPose.clipboard, height: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Photograph it too?',
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        // What the scan is FOR. A renewal office asks for the page, not for
        // the date you typed in — that is the reason to keep one, and it is
        // more use than "you can add a photo".
        'A renewal usually asks for the page itself. Keep a photo of $label '
        'and it is here when they do.',
        style: TextStyle(
          fontFamily: fontBody,
          fontSize: 13.5,
          height: 1.5,
          color: c.muted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: cued(() => Navigator.of(context).pop(false)),
          child: Text(
            'Not now',
            style: TextStyle(fontFamily: fontBody, color: c.muted),
          ),
        ),
        TextButton(
          onPressed: cued(() => Navigator.of(context).pop(true)),
          child: Text(
            'Take a photo',
            style: TextStyle(fontFamily: fontBody, color: c.gold),
          ),
        ),
      ],
    ),
  );

  if (wants != true || !context.mounted) return;

  // The backups get sealed before the camera opens, never after — see
  // `allowScan`.
  if (!await allowScan(context) || !context.mounted) return;

  final source = await askPickSource(context, title: 'The document');
  if (source == null || source == PickSource.remove) return;

  final picked = await pickDocs(DocKind.other, source);
  if (picked.isEmpty) return;

  /*
    Written straight through rather than staged.

    Staging exists because a NEW record has no id to point at. This one has
    been saved already, so there is nothing to wait for — see the note on
    `PendingDoc`.
  */
  for (final scan in picked) {
    String? blobId;

    if (scan.bytes != null) {
      blobId = newId();
      await repo.putBlob(
        blobId,
        scan.bytes!,
        scan.mime ?? 'application/octet-stream',
      );
    }

    await repo.createDoc(Doc.onPaper(
      id: '',
      paper: paperId,
      kind: scan.kind,
      title: scan.title,
      blobId: blobId,
      url: scan.url,
    ));
  }
}
