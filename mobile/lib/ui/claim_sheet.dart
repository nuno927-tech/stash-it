/// Making a claim, in one tap and one decision.
///
/// ── The moment this exists for ─────────────────────────────────────────────
/// A warranty coming to an end turns a row amber, and until now that was the
/// end of the app's involvement. The person still had to open the record, read
/// the serial off the screen, retype it into an email, go back for the
/// purchase date, go back again for the retailer, and then go hunting for the
/// receipt they photographed two years ago.
///
/// Every one of those facts is in one record already. This is the difference
/// between an app that says a warranty is expiring and an app that gets the
/// dishwasher fixed.
///
/// ── One decision, and it is about the files ────────────────────────────────
/// The words write themselves — see `logic/claim.dart`. What cannot be decided
/// for somebody is which attachments go: a receipt almost always, a twelve
/// megabyte manual the manufacturer wrote almost never, and a photograph of
/// the damage only when there is one.
///
/// So the sheet lists them with sizes and a tick each, and the receipt is
/// ticked to start with, because proof of purchase is what a claim is refused
/// for want of more than anything else.
///
/// ── Nothing is sent by this app ────────────────────────────────────────────
/// It builds a message and hands it to Android's share sheet. Which app takes
/// it, and whether it is ever sent, belongs to the person — the same choice
/// they get from every other outbound path in Stash it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/repository.dart';
import '../logic/attachments.dart';
import '../logic/claim.dart';
import '../logic/format.dart';
import '../models/types.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'theme.dart';

Future<void> showClaimSheet(
  BuildContext context, {
  required Repository repo,
  required Item item,
}) {
  feedback(Cue.expand);

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => SheetEntrance(
      child: _ClaimSheet(repo: repo, item: item),
    ),
  );
}

class _ClaimSheet extends StatefulWidget {
  const _ClaimSheet({required this.repo, required this.item});

  final Repository repo;
  final Item item;

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

/// One attachment as the sheet sees it: what it is, how big, and whether it
/// is going.
class _Choice {
  _Choice({required this.doc, required this.bytes, required this.on});

  final Doc doc;
  final int bytes;
  bool on;
}

class _ClaimSheetState extends State<_ClaimSheet> {
  List<_Choice>? _choices;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docs = await widget.repo.docsForItem(widget.item.id);

    // Sizes without the bytes — see `blobSizes`. Reading a manual to print
    // its size is the thing that would make this sheet slow to open.
    final sizes = await widget.repo.blobSizes([
      for (final d in docs)
        if (d.blobId != null) d.blobId!,
    ]);

    if (!mounted) return;

    final held = [
      // A link is not a file. It cannot be attached, and listing it with a
      // tick that does nothing is worse than leaving it out.
      for (final doc in docs)
        if (doc.deletedAt == null && doc.blobId != null)
          _Choice(
            doc: doc,
            bytes: sizes[doc.blobId!] ?? 0,
            // Proof of purchase is what a claim is refused for want of.
            on: doc.kind == DocKind.receipt,
          ),
    ]..sort((a, b) => _rank(a.doc.kind).compareTo(_rank(b.doc.kind)));

    setState(() => _choices = held);
  }

  /// Receipt first, then warranty paperwork, then everything else — the order
  /// a service desk asks for them in.
  int _rank(DocKind kind) => switch (kind) {
        DocKind.receipt => 0,
        DocKind.warranty => 1,
        DocKind.photo => 2,
        DocKind.manual => 3,
        DocKind.other => 4,
      };

  List<_Choice> get _going =>
      (_choices ?? const <_Choice>[]).where((c) => c.on).toList();

  Future<void> _send() async {
    setState(() => _sending = true);

    final written = <XFile>[];
    final names = <String>[];

    try {
      /*
        Decrypted into the cache, which Android reclaims.

        The bytes live inside an encrypted database and nothing on the phone
        can read them where they are, so they have to be written somewhere
        first. The cache is the right somewhere: a decrypted receipt should not
        sit in permanent storage because somebody thought about making a claim.
      */
      final dir = await getTemporaryDirectory();

      for (final choice in _going) {
        final blob = await widget.repo.blob(choice.doc.blobId!);
        if (blob == null) continue;

        final name = attachmentFileName(choice.doc, blob.mime);
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(blob.bytes);

        written.add(XFile(file.path));
        names.add(name);
      }

      final text = claimText(widget.item, attached: names);

      if (written.isEmpty) {
        await Share.share(text, subject: claimSubject(widget.item));
      } else {
        await Share.shareXFiles(
          written,
          text: text,
          subject: claimSubject(widget.item),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final choices = _choices;

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
                'Make a claim',
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
                'Everything below goes into a message you can send to whoever '
                'covers it. Nothing is sent from Stash it — you choose the app '
                'and you press send.',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 13,
                  height: 1.5,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 18),

              /*
                The message, shown in full rather than described.

                This is going to a stranger with the person's name, serial
                number and what they paid on it. "A summary of this item" is
                not something anybody can agree to; the actual words are.
              */
              const FieldLabel('The message'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.slate800,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: SelectableText(
                  claimText(widget.item,
                      attached: [for (final one in _going) _nameOf(one)]),
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12.5,
                    height: 1.55,
                    color: c.text,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              if (choices == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (choices.isEmpty)
                Text(
                  'Nothing is attached to this item. A photo of the receipt is '
                  'the one thing worth adding before you send it.',
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12.5,
                    height: 1.5,
                    color: c.muted,
                  ),
                )
              else ...[
                const FieldLabel('What to attach'),
                for (final choice in choices) _row(choice, c),
              ],

              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sending || choices == null ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                child: Text(
                  _sending ? 'Getting it ready…' : 'Send it',
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

  String _nameOf(_Choice choice) =>
      (choice.doc.title?.trim().isNotEmpty ?? false)
          ? choice.doc.title!.trim()
          : docWord(choice.doc.kind);

  Widget _row(_Choice choice, StashColors c) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.sm),
      onTap: () {
        feedback(Cue.tap);
        setState(() => choice.on = !choice.on);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              choice.on ? Icons.check_box : Icons.check_box_outline_blank,
              size: 21,
              color: choice.on ? c.gold : c.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _nameOf(choice),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 13.5,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              // Beside every one, because the difference between attaching a
              // receipt and attaching a manual is two orders of magnitude and
              // some mail servers refuse the second.
              readableSize(choice.bytes),
              style: TextStyle(
                fontFamily: fontMono,
                fontFeatures: tabularFigures,
                fontSize: 11.5,
                color: c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
