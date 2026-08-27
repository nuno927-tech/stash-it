/// The bin, which is the screen that makes the delete dialog honest.
///
/// ── Why this exists at all ────────────────────────────────────────────────
/// Every delete in this app shows a dialog promising "it goes to the bin for 30
/// days, so you can change your mind". Until this screen there was no bin to go
/// to: records were soft-deleted, counted down and swept, and the only
/// observable part of that was that they vanished. **A recovery window nobody
/// can reach is a thirty-day delay, not a safety net** — the sentence at the top
/// of logic/bin.dart, written about the web app and true here until now.
///
/// ── One list, not three ───────────────────────────────────────────────────
/// Everywhere else the app is organised by what a record is. Here it is
/// organised by what is about to go, because that is the only question this
/// screen answers. See `sortBin`.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/bin.dart';
import '../logic/limits.dart';
import 'confirm_delete.dart';
import 'parts.dart';
import 'theme.dart';
import 'scout.dart';

/// Opens the bin over whatever you were looking at.
///
/// A helper rather than a `MaterialPageRoute` at each call site: it is a sheet
/// now, and three screens each remembering to say `isScrollControlled` and
/// `useRootNavigator` is three chances for one of them to look different.
Future<void> showBin(BuildContext context, Repository repo) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => BinScreen(repo: repo),
  );
}

class BinScreen extends StatefulWidget {
  const BinScreen({required this.repo, super.key});

  final Repository repo;

  @override
  State<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends State<BinScreen> {
  late Future<List<BinEntry>> _entries = _load();
  String? _status;
  bool _busy = false;

  Future<List<BinEntry>> _load() async {
    final items = await widget.repo.deletedItems();
    final papers = await widget.repo.deletedPapers();
    final subs = await widget.repo.deletedSubscriptions();

    return sortBin([
      for (final i in items)
        BinEntry(
          id: i.id,
          kind: BinKind.item,
          name: i.name,
          deletedAt: i.deletedAt,
        ),
      for (final p in papers)
        BinEntry(
          id: p.id,
          kind: BinKind.paper,
          // The holder, because four passports are four identical rows and the
          // whole point of this screen is knowing which one you are restoring.
          name: (p.holder?.trim().isNotEmpty ?? false)
              ? '${p.label} — ${p.holder!.trim()}'
              : p.label,
          deletedAt: p.deletedAt,
        ),
      for (final s in subs)
        BinEntry(
          id: s.id,
          kind: BinKind.subscription,
          name: s.name,
          deletedAt: s.deletedAt,
        ),
    ]);
  }

  void _refresh() => setState(() {
        _entries = _load();
      });

  Future<void> _restore(BinEntry entry) async {
    setState(() {
      _busy = true;
      _status = null;
    });

    try {
      switch (entry.kind) {
        case BinKind.item:
          await widget.repo.restoreItem(entry.id);
        case BinKind.paper:
          await widget.repo.restorePaper(entry.id);
        case BinKind.subscription:
          await widget.repo.restoreSubscription(entry.id);
      }
      if (mounted) setState(() => _status = '${entry.name} is back.');
    } on CapReached catch (e) {
      // Nothing is lost when it refuses — the record stays here and its own
      // countdown is the only thing that can remove it. The message says so.
      if (mounted) setState(() => _status = e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  /// Erasing one, early.
  ///
  /// The confirmation says "cannot be undone" and means it: this is the one
  /// place in the app where something actually leaves the database at a
  /// person's request rather than on a timer.
  Future<void> _purge(BinEntry entry) async {
    final sure = await confirmDelete(context, name: entry.name, permanent: true);
    if (!sure) return;

    switch (entry.kind) {
      case BinKind.item:
        await widget.repo.purgeItemNow(entry.id);
      case BinKind.paper:
        await widget.repo.purgePaperNow(entry.id);
      case BinKind.subscription:
        await widget.repo.purgeSubscriptionNow(entry.id);
    }

    if (mounted) {
      setState(() => _status = '${entry.name} is gone.');
      _refresh();
    }
  }

  Future<void> _empty(int count) async {
    // The same sheet as every other delete in the app — ears up, "Keep it"
    // loud, "Delete" quiet with its consequence spelled out. `permanent`,
    // because this is the one action with no bin behind it: it IS the bin.
    final sure = await confirmDelete(
      context,
      name: 'everything in the bin (${binCount(count)})',
      permanent: true,
    );
    if (!sure) return;

    final gone = await widget.repo.emptyBin();
    if (mounted) {
      setState(() => _status = '${binCount(gone)} erased.');
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── A sheet, not a screen ────────────────────────────────────────────────

      The bin is somewhere you go once, urgently, having just deleted the wrong
      passport — and then you leave. A full screen with a back arrow treats it
      as a place; a sheet treats it as a question, which is what it is.

      Two thirds, matching every other sheet in the app, so the list you came
      from stays visible above it.
    */
    return FractionallySizedBox(
      heightFactor: 0.66,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
              child: Text(
                'Bin',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  letterSpacing: -0.6,
                  color: c.text,
                ),
              ),
            ),
            Expanded(child: _list(context, c)),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, StashColors c) {
    return FutureBuilder<List<BinEntry>>(
        future: _entries,
        builder: (context, snap) {
          final entries = snap.data;
          if (entries == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (entries.isEmpty) {
            return const Blank(
              'Nothing here.\n\n'
              'Anything you delete waits $purgeAfterDays days before it is '
              'erased, so you have time to change your mind.',
              /*
                Feet up, not curled up.

                Resting is "nothing needs you", which the dashboard already
                says. An empty bin is a different kind of nothing — there is
                not even anything that MIGHT have needed you — and lounge is
                the only pose in the roster that means genuinely off duty.
              */
              pose: ScoutPose.lounge,
              poseHeight: 160,
            );
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  binSummary(entries),
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Erased $purgeAfterDays days after you deleted it. Until '
                  'then it is still in your backups.',
                  style: TextStyle(fontFamily: fontBody, fontSize: 12, color: c.muted),
                ),
              ),

              if (_status != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    _status!,
                    style: TextStyle(fontFamily: fontBody, fontSize: 13, color: c.text),
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),

              for (final entry in entries) _row(entry, c),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OutlinedButton.icon(
                  onPressed: () => _empty(entries.length),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Empty the bin'),
                  style: OutlinedButton.styleFrom(foregroundColor: c.ember),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        });
  }

  /// The same shape as a row on the Items list: a circled glyph, the name, a
  /// second line, and the number that matters on the right.
  ///
  /// Deliberately the same, because it is the same collection. A bin whose rows
  /// look nothing like the list they came from reads as a different app's
  /// screen, and the whole reassurance being offered is "your things are still
  /// here".
  Widget _row(BinEntry entry, StashColors c) {
    final gone = entry.deletedAt;
    final left = gone == null ? purgeAfterDays : daysLeft(gone);
    final urgent = left <= 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      decoration: BoxDecoration(
        // `line`, not `slate700` — the sheet's own background IS slate700, so
        // the rule between rows was drawn in exactly the colour behind it and
        // there was no line at all.
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          // Circled in the countdown's own colour, the same way the Documents
          // list circles anything that wants something from you.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: urgent ? c.ember : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              switch (entry.kind) {
                BinKind.item => Icons.inventory_2_outlined,
                BinKind.paper => Icons.description_outlined,
                BinKind.subscription => Icons.autorenew,
              },
              size: 18,
              color: urgent ? c.ember : c.muted,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysLeftLabel(left),
                  style: TextStyle(
                    fontFamily: fontBody,
                    fontSize: 11.5,
                    // The last few days are worth a colour. Everything above
                    // that is just a number, and colouring all of it would make
                    // none of it mean anything.
                    color: urgent ? c.ember : c.muted,
                  ),
                ),
              ],
            ),
          ),

          TextButton(
            onPressed: _busy ? null : () => _restore(entry),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Restore',
              style: TextStyle(
                fontFamily: fontBody,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.gold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Delete for good',
            visualDensity: VisualDensity.compact,
            onPressed: _busy ? null : () => _purge(entry),
            icon: Icon(Icons.delete_forever_outlined, size: 20, color: c.muted),
          ),
        ],
      ),
    );
  }
}
