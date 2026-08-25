/// One item, and the files attached to it.
///
/// ── Why this screen had to exist before anything else was added ───────────
/// A restore imported 37 documents and 76 files into the database and there
/// was nowhere in the app to see any of them. The receipts were there, the
/// manuals were there, the photographs were there, and the only way to know
/// that was to open the database with a debugger.
///
/// An app that stores a receipt you cannot look at has not stored it. This is
/// the screen that makes the storage mean something.
///
/// ── Read-only, deliberately, for now ──────────────────────────────────────
/// Nothing here adds a file. Making what already exists reachable and making it
/// possible to add more are two different jobs, and doing them together is how
/// the first one ends up half-finished behind a camera permission dialog.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:io';

import '../db/repository.dart';
import '../logic/dates.dart';
import '../logic/format.dart';
import '../logic/timeline.dart';
import '../logic/warranty.dart';
import '../models/types.dart';
import 'item_form_screen.dart';
import 'parts.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({required this.repo, required this.item, super.key});

  final Repository repo;
  final Item item;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Item _item = widget.item;
  late Future<List<Doc>> _docs = widget.repo.docsForItem(_item.id);

  Future<void> _edit() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ItemFormScreen(repo: widget.repo, existing: _item),
      ),
    );
    if (!mounted) return;

    // The item may have been deleted rather than edited, in which case there is
    // nothing left to show and staying here would be a screen about a record
    // that no longer exists.
    final fresh = await widget.repo.item(_item.id);
    if (!mounted) return;
    if (fresh == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _item = fresh;
      _docs = widget.repo.docsForItem(_item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = coverageSchedule(_item);

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          TextButton(onPressed: _edit, child: const Text('Edit')),
        ],
      ),
      body: ListView(
        children: [
          if (_item.photoBlobId != null)
            _Photo(repo: widget.repo, blobId: _item.photoBlobId!),

          const SectionTitle('The facts'),
          if (_item.roomId != null)
            FutureBuilder<List<Room>>(
              future: widget.repo.rooms(),
              builder: (context, snap) {
                final room = snap.data
                    ?.where((r) => r.id == _item.roomId)
                    .firstOrNull;
                if (room == null) return const SizedBox.shrink();
                return _fact('Where', room.name, theme);
              },
            ),
          ..._facts(theme),

          if (schedule.isNotEmpty) ...[
            const SectionTitle('Cover'),
            for (final dated in schedule) _coverage(dated, theme),
          ],

          const SectionTitle('Files'),
          FutureBuilder<List<Doc>>(
            future: _docs,
            builder: (context, snap) {
              final docs = snap.data;
              if (docs == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              }

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'No receipts or manuals attached to this one.',
                  ),
                );
              }

              return Column(
                children: [
                  for (final doc in docs) _DocTile(repo: widget.repo, doc: doc),
                ],
              );
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _facts(ThemeData theme) {
    final rows = <(String, String)>[
      if ((_item.brand ?? '').isNotEmpty) ('Brand', _item.brand!),
      if ((_item.model ?? '').isNotEmpty) ('Model', _item.model!),
      if ((_item.serial ?? '').isNotEmpty) ('Serial', _item.serial!),
      if ((_item.retailer ?? '').isNotEmpty) ('Bought from', _item.retailer!),
      if ((_item.purchaseDate ?? '').isNotEmpty)
        ('Bought', _bought(_item.purchaseDate!)),
      if (_item.purchasePriceCents != null)
        (
          'Paid',
          '${currencySymbol(_item.currency ?? 'USD')}'
              '${(_item.purchasePriceCents! / 100).toStringAsFixed(2)}',
        ),
    ];

    if (rows.isEmpty && (_item.notes ?? '').isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Just a name, so far.'),
        ),
      ];
    }

    return [
      for (final (label, value) in rows) _fact(label, value, theme),
      if ((_item.notes ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(_item.notes!, style: theme.textTheme.bodyMedium),
        ),
    ];
  }

  Widget _fact(String label, String value, ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Widget _coverage(DatedCoverage dated, ThemeData theme) {
    final left = dated.daysLeft;

    return ListTile(
      dense: true,
      title: Text(coverageLabel(dated.coverage)),
      subtitle: Text(
        switch ((dated.end, left)) {
          // Lifetime has no date and must not be given one — see the note on
          // `CoverageUnit.lifetime`.
          (null, _) => 'For life',
          (final end?, final d?) when d < 0 => 'Ended ${dayMonth(end)}',
          (final end?, _) => 'Until ${dayMonth(end)}',
        },
      ),
      trailing: left == null || left < 0
          ? null
          : Text('$left d', style: theme.textTheme.labelMedium),
    );
  }
}

/// The item's photograph, straight out of the database.
///
/// The bytes are in the encrypted database rather than on disk — a consequence
/// of the encryption decision, since a file next to an encrypted database is a
/// plaintext file. So there is no path to hand `Image.file`, and this reads
/// them once and holds them.
class _Photo extends StatelessWidget {
  const _Photo({required this.repo, required this.blobId});

  final Repository repo;
  final String blobId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: repo.blob(blobId).then((b) => b?.bytes),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return const SizedBox.shrink();

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity),
        );
      },
    );
  }
}

class _DocTile extends StatefulWidget {
  const _DocTile({required this.repo, required this.doc});

  final Repository repo;
  final Doc doc;

  @override
  State<_DocTile> createState() => _DocTileState();
}

class _DocTileState extends State<_DocTile> {
  bool _busy = false;

  /// Out of the database, into a temporary file, into the share sheet.
  ///
  /// ── Why sharing rather than opening ───────────────────────────────────
  /// The bytes live inside an encrypted database, so nothing on the phone can
  /// open them where they are. They have to be written somewhere first, and
  /// once they are written the share sheet is the honest offer: it lists every
  /// app that can handle the file, including the PDF viewer, and it does not
  /// pretend the file has stayed private.
  ///
  /// The copy goes to the cache directory, which Android reclaims. A decrypted
  /// receipt should not be left in the app's permanent storage because somebody
  /// glanced at it once.
  Future<void> _openIt() async {
    final blobId = widget.doc.blobId;
    if (blobId == null) return;

    setState(() => _busy = true);
    try {
      final blob = await widget.repo.blob(blobId);
      if (blob == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The file for this one is missing from the database.',
              ),
            ),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final name = _fileName(widget.doc, blob.mime);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(blob.bytes);

      await Share.shareXFiles([XFile(file.path)], subject: name);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final missing = doc.blobId == null && doc.url == null;

    return ListTile(
      leading: Icon(switch (doc.kind) {
        DocKind.receipt => Icons.receipt_long_outlined,
        DocKind.warranty => Icons.verified_outlined,
        DocKind.manual => Icons.menu_book_outlined,
        DocKind.photo => Icons.photo_outlined,
        DocKind.other => Icons.attach_file,
      }),
      title: Text(doc.title?.trim().isNotEmpty == true
          ? doc.title!.trim()
          : _kindLabel[doc.kind]!),
      subtitle: Text(
        missing
            // Honest rather than reassuring. This is what a document restored
            // by the broken importer looks like, and saying "no file" is how
            // somebody knows to restore again rather than assuming it is gone.
            ? 'No file attached'
            : doc.isLocal
                ? _kindLabel[doc.kind]!
                : 'A link',
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.open_in_new),
      onTap: missing || _busy ? null : _openIt,
    );
  }
}

const Map<DocKind, String> _kindLabel = {
  DocKind.receipt: 'Receipt',
  DocKind.warranty: 'Warranty',
  DocKind.manual: 'Manual',
  DocKind.photo: 'Photo',
  DocKind.other: 'File',
};

/// "Aug 9, 2024".
///
/// With the year, unlike `dayMonth` everywhere else. Every other date in the
/// app is inside a countdown and therefore near; a purchase date is the one
/// that is routinely years old, and "Aug 9" alone invites the wrong one.
String _bought(String iso) {
  final d = parseDate(iso);
  return d == null ? iso : '${dayMonth(d)}, ${d.year}';
}

/// A name somebody would recognise in a share sheet.
///
/// "receipt.pdf" beats the blob's id, which is a timestamp and some entropy.
String _fileName(Doc doc, String mime) {
  final base = (doc.title?.trim().isNotEmpty ?? false)
      ? doc.title!.trim()
      : _kindLabel[doc.kind]!;

  final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '').trim();
  final ext = switch (mime) {
    'application/pdf' => 'pdf',
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'bin',
  };

  return safe.toLowerCase().endsWith('.$ext') ? safe : '$safe.$ext';
}
