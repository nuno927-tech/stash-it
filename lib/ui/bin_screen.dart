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
import 'parts.dart';

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
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${entry.name} for good?'),
        content: const Text(
          'This one cannot be undone. It is removed from the database now, '
          'along with any photographs or files attached to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete for good'),
          ),
        ],
      ),
    );
    if (sure != true) return;

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
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Empty the bin?'),
        content: Text(
          '${binCount(count)} removed from the database now, rather than when '
          'their countdowns run out. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Leave it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Empty it'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    final gone = await widget.repo.emptyBin();
    if (mounted) {
      setState(() => _status = '${binCount(gone)} erased.');
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bin')),
      body: FutureBuilder<List<BinEntry>>(
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
            );
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  binSummary(entries),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Erased $purgeAfterDays days after you deleted it. Until '
                  'then it is still in your backups.',
                  style: theme.textTheme.bodySmall,
                ),
              ),

              if (_status != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(_status!, style: theme.textTheme.bodyMedium),
                ),
              if (_busy) const LinearProgressIndicator(),

              for (final entry in entries) _row(entry, theme),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _empty(entries.length),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Empty the bin'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BinEntry entry, ThemeData theme) {
    final gone = entry.deletedAt;
    final left = gone == null ? purgeAfterDays : daysLeft(gone);

    return ListTile(
      leading: Icon(switch (entry.kind) {
        BinKind.item => Icons.inventory_2_outlined,
        BinKind.paper => Icons.description_outlined,
        BinKind.subscription => Icons.autorenew,
      }),
      title: Text(entry.name),
      subtitle: Text(
        daysLeftLabel(left),
        style: TextStyle(
          // The last few days are worth a colour. Everything above that is
          // just a number, and colouring all of it would make none of it mean
          // anything.
          color: left <= 3 ? theme.colorScheme.error : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _restore(entry),
            child: const Text('Restore'),
          ),
          IconButton(
            tooltip: 'Delete for good',
            onPressed: _busy ? null : () => _purge(entry),
            icon: const Icon(Icons.delete_forever_outlined),
          ),
        ],
      ),
    );
  }
}
