/// Photographs, out of the encrypted database and onto a row.
///
/// ── Why this needs a cache at all ─────────────────────────────────────────
/// The bytes live inside the database rather than on disk — a consequence of
/// encrypting it, since a file next to an encrypted database is a plaintext
/// file. So there is no path for `Image.file` to open, and every thumbnail is a
/// query.
///
/// A list of forty items scrolling would run forty queries per frame without
/// this, and each one would rebuild an `Image` from raw bytes. The cache is
/// keyed by blob id, holds decoded providers, and is never invalidated: a blob
/// is written once and erased with its item, so a stale entry would have to
/// name something that no longer exists.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../models/types.dart';
import 'warranty_ring.dart';

final Map<String, ImageProvider?> _cache = {};

/// The decoded picture for a blob, cached. Public because the dashboard draws
/// photographs without a ring around them.
Future<ImageProvider?> thumbFor(Repository repo, String? blobId) => _load(repo, blobId);

Future<ImageProvider?> _load(Repository repo, String? blobId) async {
  if (blobId == null) return null;
  if (_cache.containsKey(blobId)) return _cache[blobId];

  final blob = await repo.blob(blobId);
  final provider = blob == null ? null : MemoryImage(blob.bytes);
  _cache[blobId] = provider;
  return provider;
}

/// The item's ring with its photograph inside, fetched as needed.
///
/// The ring is drawn before the photograph arrives rather than after. It is the
/// part carrying the information, the query takes a few milliseconds, and a row
/// that pops into existence complete is a row that shifts the ones under it.
class ItemArtLive extends StatelessWidget {
  const ItemArtLive({
    required this.repo,
    required this.item,
    this.size = 44,
    this.stroke = 2.8,
    this.fallback,
    super.key,
  });

  final Repository repo;
  final Item item;
  final double size;
  final double stroke;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    // The thumbnail if there is one, the full photograph if there is not.
    // A restored backup carries both; an item added on the phone may only ever
    // have had the one.
    final id = item.thumbBlobId ?? item.photoBlobId;

    return FutureBuilder<ImageProvider?>(
      future: _load(repo, id),
      builder: (context, snap) => ItemArt(
        item: item,
        thumb: snap.data,
        size: size,
        stroke: stroke,
        fallback: fallback,
      ),
    );
  }
}
