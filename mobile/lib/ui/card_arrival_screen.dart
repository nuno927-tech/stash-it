/// What somebody sees when a card arrives.
///
/// ── This screen exists because the alternative is silent ──────────────────
/// A card could simply be merged on open. It must not be. The file came from
/// outside — a message, an email, a shared folder — and the person tapping it
/// has no idea what is in it until this screen tells them. Adding six items
/// and a subscription to somebody's records without showing them first is the
/// same move a restore makes, and the whole design of this format is that a
/// card cannot do that.
///
/// So: everything is listed, everything is a checkbox, nothing is written
/// until Add is pressed.
library;

import 'package:flutter/material.dart';

import '../db/card_export.dart';
import '../db/repository.dart';
import '../logic/bundle.dart';
import '../logic/card.dart';
import '../logic/limits.dart';
import '../models/types.dart';
import 'feedback.dart';
import 'form_sheet_parts.dart';
import 'scout.dart';
import 'theme.dart';

/// Opens the arrival sheet. Returns how many were added, or null.
///
/// ── A sheet, at the same height as everything else ────────────────────────
/// This was a pushed screen with an app bar, which made receiving a card the
/// only thing in the app that took you somewhere. It is the same shape of
/// moment as looking at an item or sending one — a thing to read, decide on,
/// and leave — so it is the same shape of surface.
Future<int?> showCardArrival(
  BuildContext context, {
  required Repository repo,
  required ParsedBundle card,
}) {
  feedback(Cue.expand);

  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate900,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) =>
        SheetEntrance(child: CardArrivalScreen(repo: repo, card: card)),
  );
}

class CardArrivalScreen extends StatefulWidget {
  const CardArrivalScreen({required this.repo, required this.card, super.key});

  final Repository repo;
  final ParsedBundle card;

  @override
  State<CardArrivalScreen> createState() => _CardArrivalScreenState();
}

class _CardArrivalScreenState extends State<CardArrivalScreen> {
  /// Everything is ticked to begin with. Somebody who was sent three things
  /// wants three things; making them tick each one is a toll on the common
  /// case to serve the rare one.
  late final Set<String> _keep = {
    for (final i in widget.card.data.items)
      if (i.deletedAt == null) i.id,
    for (final p in widget.card.data.papers)
      if (p.deletedAt == null) p.id,
    for (final s in widget.card.data.subscriptions)
      if (s.deletedAt == null) s.id,
  };

  bool _busy = false;
  String? _said;

  /// How much room is left under the free cap, or null when there is no cap.
  int? _room;

  @override
  void initState() {
    super.initState();
    _readRoom();
  }

  Future<void> _readRoom() async {
    final settings = await widget.repo.settings();
    final used = await widget.repo.cappedCount();
    if (!mounted) return;
    // Null for somebody who has paid — the question no longer applies, and
    // `remainingFree` says so by returning null rather than a big number.
    setState(() => _room = remainingFree(used, settings.entitlements));
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      final rooms = await widget.repo.rooms();

      final merge = planCardMerge(
        widget.card,
        propertyId: widget.repo.propertyId,
        existingRooms: rooms,
        newId: newId,
        keep: _keep,
      );

      await applyCardMerge(widget.repo.db, merge);
      feedback(Cue.save);

      if (!mounted) return;
      Navigator.of(context).pop(merge.count);
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
    final data = widget.card.data;

    final items = data.items.where((i) => i.deletedAt == null).toList();
    final papers = data.papers.where((p) => p.deletedAt == null).toList();
    final subs = data.subscriptions.where((s) => s.deletedAt == null).toList();
    final total = items.length + papers.length + subs.length;

    /*
      The cap is checked against what is TICKED, not against what is in the
      file. Somebody two short of the limit who was sent five things can still
      take two of them, and the screen should let them choose which rather
      than refusing the lot.
    */
    final over = _room != null && _keep.length > _room!;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: sheetTop(context),
      minChildSize: 0.4,
      maxChildSize: sheetTop(context),
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                /*
                  ── Scout carries the message, and it reads down ──────────

                  He was a small figure beside a paragraph, which made the
                  paragraph the subject and him a decoration. Centred and at
                  size he is the first thing seen, the sentence underneath
                  explains, and the list follows — one column, top to bottom,
                  rather than a picture and some text sharing a line.
                */
                Center(
                  child: Scout(
                    pose: ScoutPose.folder,
                    height: 168,
                    motion: const [ScoutMotion.breathe],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    'Somebody sent you '
                    '${total == 1 ? 'something' : '$total things'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w800,
                      fontSize: 23,
                      height: 1.15,
                      letterSpacing: -0.5,
                      color: c.text,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Nothing is added until you say so. Untick anything you '
                    'do not want.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 13,
                      color: c.muted,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (items.isNotEmpty) ...[
                  const _Head('Items'),
                  for (final item in items)
                    _Line(
                      title: item.name,
                      detail: _itemDetail(item),
                      on: _keep.contains(item.id),
                      onTap: () => _flip(item.id),
                    ),
                ],
                if (papers.isNotEmpty) ...[
                  const _Head('Documents'),
                  for (final paper in papers)
                    _Line(
                      title: paper.label,
                      detail: paper.expiresOn.isEmpty
                          ? 'No expiry recorded'
                          : 'Expires ${paper.expiresOn}',
                      on: _keep.contains(paper.id),
                      onTap: () => _flip(paper.id),
                    ),
                ],
                if (subs.isNotEmpty) ...[
                  const _Head('Subscriptions'),
                  for (final sub in subs)
                    _Line(
                      title: sub.name,
                      detail: monthlyLabel(sub),
                      on: _keep.contains(sub.id),
                      onTap: () => _flip(sub.id),
                    ),
                ],

                /*
            Said plainly, with the number, rather than as a refusal at the end.
            Discovering the limit after pressing Add — having already decided
            you wanted these — is the worst moment to hear about it.
          */
                if (over)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Text(
                      'You have room for ${_room! < 0 ? 0 : _room!} more on the free '
                      'version, and ${_keep.length} are ticked. Untick a few, or go '
                      'Pro for unlimited.',
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 12.5,
                        height: 1.45,
                        color: c.ember,
                      ),
                    ),
                  ),
                if (_said != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Text(_said!, style: hintStyle(c)),
                  ),
              ],
            ),
          ),

          // Pinned under the list, so a long card scrolls behind a button
          // that never leaves — the footer shape the view sheets use.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: c.slate900,
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _busy || _keep.isEmpty || over ? null : _add,
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  disabledBackgroundColor: c.slate600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                child: Text(
                  _keep.isEmpty
                      ? 'Nothing ticked'
                      : 'Add ${_keep.length} to my stash',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: _busy || _keep.isEmpty || over ? c.muted : c.onGold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _flip(String id) {
    feedback(Cue.tap);
    setState(() => _keep.contains(id) ? _keep.remove(id) : _keep.add(id));
  }

  String _itemDetail(Item item) {
    final bits = [
      if (item.brand != null && item.brand!.isNotEmpty) item.brand!,
      if (item.purchaseDate != null && item.purchaseDate!.isNotEmpty)
        'bought ${item.purchaseDate}',
    ];
    return bits.isEmpty ? 'No other details' : bits.join(' · ');
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: fontBody,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: StashColors.of(context).muted,
          ),
        ),
      );
}

class _Line extends StatelessWidget {
  const _Line({
    required this.title,
    required this.detail,
    required this.on,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.slate700)),
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.check_circle : Icons.circle_outlined,
              size: 21,
              color: on ? c.gold : c.slate600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: on ? c.text : c.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      color: c.muted,
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
