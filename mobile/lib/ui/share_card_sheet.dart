/// The last screen before something leaves the phone.
///
/// ── Why there is a sheet rather than a straight share button ──────────────
/// Everything else in this app stays on the handset. This is the one action
/// that puts records into a channel the app does not control — a message, an
/// email, a chat — and once sent they cannot be recalled.
///
/// So there is a pause, and it does two jobs. It shows the exact words that
/// will travel, because that text is what most recipients will actually read
/// and it should not be a surprise. And it holds the attachments switch, off
/// by default, because a receipt is a photograph of a piece of paper that
/// often carries the last four digits of a card and sometimes a home address —
/// see the note on `CardPick.attachments`.
library;

import 'package:flutter/material.dart';

import '../db/card_export.dart';
import '../db/repository.dart';
import '../io/card_file.dart';
import '../logic/card.dart';
import 'feedback.dart';
import 'theme.dart';

/// Opens the sheet. Returns true once something has actually been sent.
Future<bool> shareCardSheet(
  BuildContext context, {
  required Repository repo,
  required CardPick pick,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ShareSheet(repo: repo, pick: pick),
  );
  return sent ?? false;
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.repo, required this.pick});

  final Repository repo;
  final CardPick pick;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late CardPick _pick = widget.pick;
  bool _busy = false;
  String? _said;

  /// The message text, rebuilt whenever the picks change.
  String? _preview;

  @override
  void initState() {
    super.initState();
    _readPreview();
  }

  /*
    The preview is built by the same function that will build the real message,
    from the same rows, rather than being an approximation written for the
    sheet. A preview that can differ from what is sent is worse than no preview
    — it is a promise the app does not keep.
  */
  Future<void> _readPreview() async {
    final contents = await gatherCard(widget.repo.db, _pick);
    if (!mounted) return;
    setState(() => _preview = cardSummary(
          items: contents.summarySource.items,
          papers: contents.summarySource.papers,
          subscriptions: contents.summarySource.subscriptions,
        ));
  }

  /*
    ── Two sends, because a text message cannot carry a file ────────────────

    Attach anything and Android drops every messaging app from the share sheet
    — SMS has no attachment and MMS does not take an app's own format. That is
    the transport, not a setting.

    So the card and the words are separate offers. See the note in
    `io/card_file.dart`; the words were always written to stand alone.
  */
  Future<void> _send({required bool withCard}) async {
    setState(() => _busy = true);
    try {
      if (withCard) {
        await shareCard(widget.repo.db, _pick);
      } else {
        await shareSummary(widget.repo.db, _pick);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _said = 'That did not work: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);
    final n = _pick.count;

    return Container(
      decoration: BoxDecoration(
        color: c.slate800,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.slate600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                n == 1 ? 'Send this' : 'Send these $n',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.4,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'They get this message. If they have Stash it, the attached '
                'card adds it to their stash in one tap.',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 12.5,
                  height: 1.45,
                  color: c.muted,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 190),
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: c.slate900,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: c.line),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _preview ?? 'Reading…',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 12.5,
                      height: 1.5,
                      color: c.text,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                feedback(Cue.tap);
                setState(
                    () => _pick = _pick.withAttachments(!_pick.attachments));
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Include photos and receipts',
                            style: TextStyle(
                              fontFamily: fontBody,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // Says the actual risk rather than "may contain
                            // personal information", which is a phrase people
                            // have learned to read past.
                            'Receipts often show card digits and addresses.',
                            style: TextStyle(
                              fontFamily: fontBody,
                              fontSize: 11.5,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _pick.attachments,
                      activeThumbColor: c.gold,
                      onChanged: (on) {
                        feedback(Cue.tap);
                        setState(() => _pick = _pick.withAttachments(on));
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_said != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Text(_said!, style: hintStyle(c)),
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton(
                onPressed: _busy || _preview == null
                    ? null
                    : () => _send(withCard: true),
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  disabledBackgroundColor: c.slate600,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                child: Text(
                  _busy ? 'Preparing…' : 'Send with the card',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: _busy || _preview == null ? c.muted : c.onGold,
                  ),
                ),
              ),
            ),

            /*
              The quieter of the two, but the one that reaches a phone number.
              Named for what the recipient gets rather than for what is left
              out — "without the attachment" describes the mechanism, and the
              person choosing is thinking about who they are sending to.
            */
            TextButton(
              onPressed: _busy || _preview == null
                  ? null
                  : () => _send(withCard: false),
              child: Text(
                'Send as a text message',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _busy || _preview == null ? c.muted : c.gold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
