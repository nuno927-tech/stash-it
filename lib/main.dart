/// Stash it, on a phone.
///
/// ── What this is, and what it is not ──────────────────────────────────────
/// The smallest thing that puts the ported logic in front of a person: open
/// the encrypted database, restore a real backup into it, and show what came
/// back. There is no design here yet and no way to add anything — the point is
/// to prove the bottom of the stack on real hardware with real data, which no
/// amount of green tests can do.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'db/open_flutter.dart';
import 'db/repository.dart';
import 'db/restore.dart';
import 'db/tables.dart';
import 'io/bundle_file.dart';
import 'logic/bundle.dart';
import 'logic/dashboard.dart';
import 'logic/timeline.dart';
import 'logic/warranty.dart';
import 'models/types.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openEncrypted();
  runApp(StashItApp(db: db));
}

class StashItApp extends StatelessWidget {
  const StashItApp({required this.db, super.key});

  final StashDatabase db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stash it',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF2B33D),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(repo: Repository(db)),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.repo, super.key});

  final Repository repo;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _status;
  bool _busy = false;

  /// Picks a `.stashit` and writes it in.
  ///
  /// Every refusal the parser can produce arrives here as a `BundleError` with
  /// a sentence already written for a person to read — see the top of
  /// logic/bundle.dart. There is nothing to translate.
  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _status = null;
    });

    try {
      /*
        ── `withData` is off, and that is not a detail ──────────────────────

        With it on, the picker reads the whole file into memory on the Java
        side and hands the bytes across the platform channel. A backup with
        seventy-six photographs in it is several megabytes, and that transfer
        killed the process outright — a native crash, with nothing Dart could
        catch and nothing on screen to explain it.

        A path costs one string. Reading the file is `dart:io`'s job and it
        does it without copying anything through a channel.
      */
      final picked = await FilePicker.platform.pickFiles();
      final files = picked?.files ?? const <PlatformFile>[];
      final path = files.isEmpty ? null : files.first.path;

      // Cancelled. Not an error, and not worth a message.
      if (path == null) return;

      final bytes = await File(path).readAsBytes();
      final bundle = parseBackupBytes(bytes);
      final result = await restoreInto(widget.repo.db, bundle);

      setState(() {
        _status = 'Restored ${result.items} items, ${result.papers} documents, '
            '${result.subscriptions} subscriptions and ${result.blobs} files '
            'from a backup written by Stash it ${bundle.manifest.appVersion}.';
      });
    } on BundleError catch (e) {
      // Every refusal the parser can produce already carries a sentence
      // written for a person to read. Nothing to translate.
      setState(() => _status = e.message);
    } catch (e) {
      /*
        Deliberately broad. A restore that fails for a reason nobody predicted
        — a file the OS will not hand over, a disk that is full — has to say
        something rather than leave the screen sitting on a spinner. The text
        is ugly on purpose: it is a bug report, not a message.
      */
      setState(() => _status = 'That did not work: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stash it'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.download),
            tooltip: 'Restore from a backup',
          ),
        ],
      ),
      body: StreamBuilder<List<Item>>(
        stream: widget.repo.watchActiveItems(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Item>[];

          return Column(
            children: [
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_status!, style: Theme.of(context).textTheme.bodyMedium),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (items.isEmpty && !_busy)
                const Expanded(child: _Empty())
              else
                Expanded(child: _Body(repo: widget.repo, items: items)),
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Nothing here yet.\n\nTap the download icon and choose a .stashit '
          'backup to bring everything across.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.repo, required this.items});

  final Repository repo;
  final List<Item> items;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Snapshot>(
      future: _Snapshot.of(repo, items),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());

        return ListView(
          children: [
            _Summary(data: data),
            const Divider(),
            for (final entry in data.timeline.take(8)) _TimelineTile(entry: entry),
            const Divider(),
            for (final item in items) _ItemTile(item: item),
          ],
        );
      },
    );
  }
}

/// Everything one screen needs, fetched once.
class _Snapshot {
  const _Snapshot(this.metrics, this.timeline);

  final Metrics metrics;
  final List<Entry> timeline;

  static Future<_Snapshot> of(Repository repo, List<Item> items) async {
    final docs = await repo.activeDocs();
    final papers = await repo.activePapers();
    final subs = await repo.activeSubscriptions();

    return _Snapshot(
      metricsFor(items, docs),
      buildTimeline(items, subs, papers),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final _Snapshot data;

  @override
  Widget build(BuildContext context) {
    final m = data.metrics;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          _Figure(label: 'covered', value: '${m.covered}'),
          _Figure(label: 'ending soon', value: '${m.endingSoon}'),
          _Figure(label: 'lapsed', value: '${m.expired}'),
          _Figure(label: 'no term', value: '${m.untracked}'),
          if (m.valueByCurrency.isNotEmpty)
            _Figure(label: 'value', value: shortMoney(m.valueByCurrency.first)),
          _Figure(label: 'needs you', value: '${flaggedCount(data.timeline)}'),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        entry.flagged ? Icons.error_outline : Icons.schedule,
        color: entry.flagged ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(entry.title),
      subtitle: Text(entry.detail),
      trailing: Text(whenLabelFor(entry)),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final state = warrantyState(item);
    final end = effectiveExpiry(item);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: switch (state) {
          WarrantyState.covered => Colors.green.shade700,
          WarrantyState.endingSoon => Colors.amber.shade700,
          WarrantyState.expired => Colors.red.shade700,
          WarrantyState.unknown => Colors.grey.shade700,
        },
        child: Text(item.name.isEmpty ? '?' : item.name[0].toUpperCase()),
      ),
      title: Text(item.name),
      subtitle: Text(
        end == null ? 'No cover recorded' : 'Cover ends ${dayMonth(end)}',
      ),
    );
  }
}
