/// Photographing a receipt and being shown what it says.
///
/// ── The whole feature is the review step ───────────────────────────────────
/// Reading the text is the easy half and the parsing is in
/// `logic/receipt_read.dart`. What makes this safe to ship is this screen: it
/// shows every proposal beside the line it was read off, with a tick, and
/// fills in nothing that has not been looked at.
///
/// An app that silently writes a guessed purchase date onto a warranty is an
/// app that gets somebody's claim refused two years later, and neither of them
/// will ever know why.
///
/// ── The photograph is kept, whatever the reading did ───────────────────────
/// Even if it reads nothing at all, the receipt is attached to the item — that
/// is the thing a claim actually needs, and it is already in your hand. The
/// reading is a shortcut for typing, not the reason to take the picture.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../io/text_recognition.dart';
import '../logic/attachments.dart';
import '../logic/receipt_read.dart';
import '../models/types.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'pick_doc.dart';
import 'theme.dart';

/// What a scan hands to the item form.
///
/// Only the parts that were ticked. Every field optional, because a receipt
/// that gave up two of the three is still worth the one it found.
class ReceiptSeed {
  const ReceiptSeed({
    this.purchaseDate,
    this.priceText,
    this.retailer,
    this.receipt,
  });

  final String? purchaseDate;
  final String? priceText;
  final String? retailer;

  /// The photograph, staged as an attachment. Present even when nothing was
  /// read off it.
  final PendingDoc? receipt;
}

/// Takes a photograph, reads it, and asks what to keep.
///
/// Null when somebody backs out at any point, which must leave the app exactly
/// as it was.
Future<ReceiptSeed?> scanReceipt(BuildContext context) async {
  final source = await askPickSource(context, title: 'The receipt');
  if (source == null || source == PickSource.remove || !context.mounted) {
    return null;
  }

  /*
    Picked here rather than through `pickDocs`, and the reason is one field.

    `pickDocs` reads the bytes and drops the path, which is right for staging
    an attachment and useless here: ML Kit reads a FILE. So this keeps the
    path for the recogniser and the bytes for the attachment, from one pick.

    The quality settings are `pickDocs`' own — see the note there. A receipt at
    85 is indistinguishable from one at 100 and a quarter of the size, and
    these bytes go into the encrypted database and then into every backup.
  */
  final shot = await ImagePicker().pickImage(
    source:
        source == PickSource.camera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 2400,
  );

  if (shot == null || !context.mounted) return null;

  final staged = PendingDoc(
    kind: DocKind.receipt,
    title: docKindLabels[DocKind.receipt]!,
    bytes: await shot.readAsBytes(),
    mime: 'image/jpeg',
  );

  if (!context.mounted) return null;

  return showModalBottomSheet<ReceiptSeed>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => SheetEntrance(
      child: _ReviewSheet(path: shot.path, receipt: staged),
    ),
  );
}

/// Reads a receipt already staged as an attachment.
///
/// The other way in: somebody attached a receipt in the ordinary way and the
/// app offers to read it. The bytes are written to a scratch file because the
/// recogniser takes a path and staged attachments are bytes.
Future<ReceiptSeed?> readStagedReceipt(
  BuildContext context,
  PendingDoc staged,
) async {
  final bytes = staged.bytes;
  if (bytes == null) return null;

  final dir = await getTemporaryDirectory();
  final scratch = File('${dir.path}/reading-receipt.jpg');
  await scratch.writeAsBytes(bytes);

  if (!context.mounted) return null;

  return showModalBottomSheet<ReceiptSeed>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    // Null: the attachment is already staged by the caller, so handing it back
    // would file the same receipt twice.
    builder: (context) => SheetEntrance(
      child: _ReviewSheet(path: scratch.path, receipt: null),
    ),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.path, required this.receipt});

  final String path;
  final PendingDoc? receipt;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  ReceiptReading? _read;
  bool _busy = true;

  bool _useDate = true;
  bool _usePrice = true;
  bool _useShop = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final lines = await appTextReader.linesIn(widget.path);
    if (!mounted) return;

    setState(() {
      _read = readReceipt(lines);
      _busy = false;
    });
  }

  void _done() {
    final got = _read;
    feedback(Cue.save);

    Navigator.of(context).pop(ReceiptSeed(
      purchaseDate: _useDate ? got?.date?.value : null,
      priceText: _usePrice && got?.totalCents != null
          ? (got!.totalCents!.value / 100).toStringAsFixed(2)
          : null,
      retailer: _useShop ? got?.retailer?.value : null,
      receipt: widget.receipt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final got = _read;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _busy ? 'Reading it…' : 'What it says',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 25,
                  letterSpacing: -0.7,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _busy
                    ? 'On this phone. The photograph is not sent anywhere.'
                    : 'Untick anything it got wrong — you can edit all of it '
                        'on the next screen either way.',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 13,
                  height: 1.5,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 20),

              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (got == null || got.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.slate800,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Text(
                    /*
                      Not an error, and worded so it does not read as one.

                      A crumpled receipt in bad light is the ordinary case, not
                      a failure — and the photograph is kept regardless, which
                      is the part that matters for a claim.
                    */
                    widget.receipt == null
                        ? 'Could not make anything out. Fill it in as usual.'
                        : 'Could not make anything out — the photo is still '
                            'attached. Fill the rest in as usual.',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 13,
                      height: 1.5,
                      color: c.text,
                    ),
                  ),
                )
              else ...[
                if (got.date case final read?)
                  _Line(
                    label: 'Bought',
                    shows: read.value,
                    read: read,
                    on: _useDate,
                    onTap: () => setState(() => _useDate = !_useDate),
                    c: c,
                  ),
                if (got.totalCents case final read?)
                  _Line(
                    label: 'Paid',
                    // No currency symbol. The receipt did not say which
                    // currency it was in and this app is used in several — a
                    // dollar sign on a euro total is the app inventing
                    // something on a screen whose whole point is that it does
                    // not. The form's own currency picker owns that question.
                    shows: (read.value / 100).toStringAsFixed(2),
                    read: read,
                    on: _usePrice,
                    onTap: () => setState(() => _usePrice = !_usePrice),
                    c: c,
                  ),
                if (got.retailer case final read?)
                  _Line(
                    label: 'From',
                    shows: read.value,
                    read: read,
                    on: _useShop,
                    onTap: () => setState(() => _useShop = !_useShop),
                    c: c,
                  ),
              ],

              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _done,
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                child: Text(
                  'Use these',
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
      ),
    );
  }
}

/// One proposal, its tick, and the line it was read off.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.shows,
    required this.read,
    required this.on,
    required this.onTap,
    required this.c,
  });

  final String label;
  final String shows;

  // `Object` rather than a bare `ReadField`: the three readings are a date, a
  // total and a shop, and this row only ever shows the line each was read off.
  final ReadField<Object> read;
  final bool on;
  final VoidCallback onTap;
  final StashColors c;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: () {
        feedback(Cue.tap);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              on ? Icons.check_box : Icons.check_box_outline_blank,
              size: 21,
              color: on ? c.gold : c.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '$label  ',
                        style: TextStyle(
                          fontFamily: fontBody,
                          fontSize: 12,
                          color: c.muted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          shows,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: fontBody,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  /*
                    The line it came from, always — not only when the reading
                    is unsure.

                    Somebody checking a proposal against the paper in their
                    hand is checking the READING, and a confident wrong answer
                    with nothing to compare it to is the one that gets
                    accepted. It costs one small line.
                  */
                  Text(
                    read.sureness == Sureness.likely
                        ? 'best guess, from: ${read.saw}'
                        : 'from: ${read.saw}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontMono,
                      fontSize: 10.5,
                      color: read.sureness == Sureness.likely
                          ? c.honey
                          : c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
