/// Reads a real `.stashit` file and says what it found.
///
///   dart run tool/read_backup.dart "C:\path\to\stash-it-backup-2026-08-17.stashit"
///
/// ── Why this exists ───────────────────────────────────────────────────────
/// Everything in this package so far has been checked against fixtures I
/// wrote, which means it has been checked against my own understanding of the
/// format. That is exactly the thing most likely to be wrong.
///
/// A backup exported from the app you actually use is the first input to this
/// code that nobody here invented. If it reads, the models, the decoders, the
/// checksum order and the migration chain are all right about a real file. If
/// it does not, this prints why, which is worth more than another fixture.
///
/// It reads only. Nothing is written, and nothing about your backup leaves the
/// machine.
library;

import 'dart:io';

import 'package:stash_it/io/bundle_file.dart';
import 'package:stash_it/logic/bundle.dart';
import 'package:stash_it/logic/dashboard.dart';
import 'package:stash_it/logic/papers.dart';
import 'package:stash_it/logic/subscriptions.dart';
import 'package:stash_it/logic/timeline.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/read_backup.dart <file.stashit>');
    exit(64);
  }

  final path = args.first;
  if (!File(path).existsSync()) {
    stderr.writeln('No file at: $path');
    exit(66);
  }

  final ParsedBundle bundle;
  try {
    bundle = parseBackupFile(path);
  } on BundleError catch (e) {
    stderr.writeln('Refused: ${e.message}');
    exit(65);
  }

  final m = bundle.manifest;
  final d = bundle.data;

  print('── the file ──────────────────────────────────────────');
  print('  written by      Stash it ${m.appVersion}');
  print('  exported        ${m.exportedAt ?? 'not recorded'}');
  print('  format          v${m.formatVersion}, schema v${m.schemaVersion}');
  print('  checksum        matched');

  print('');
  print('── what came back ────────────────────────────────────');
  _count('items', d.items.length, m.itemCount);
  _count('documents', d.docs.length, m.docCount);
  print('  rooms           ${d.rooms.length}');
  print('  subscriptions   ${d.subscriptions.length}');
  print('  papers          ${d.papers.length}');
  print('  properties      ${d.properties.length}  (carried through untouched)');
  print('  maintenance     ${d.maintenance.length}  (carried through untouched)');
  _count('blobs', bundle.blobs.length, m.blobCount);
  print('  settings        ${d.settings == null ? 'none' : 'restored'}');

  /*
    The bin is meant to travel, so seeing a number here is the feature working
    rather than a problem. Seeing zero on a backup you know had deleted things
    in it would be the bug.
  */
  final binned = d.items.where((i) => i.deletedAt != null).length;
  print('  of those items  $binned in the bin');

  print('');
  print('── what the logic makes of it ────────────────────────');

  final metrics = metricsFor(d.items, d.docs);
  print('  covered         ${metrics.covered}');
  print('  ending soon     ${metrics.endingSoon}');
  print('  lapsed          ${metrics.expired}');
  print('  no term set     ${metrics.untracked}');
  for (final total in metrics.valueByCurrency) {
    print('  value           ${shortMoney(total)}');
  }

  if (d.subscriptions.isNotEmpty) {
    final monthly = totalMonthlyCents(d.subscriptions) / 100;
    print('  subscriptions   \$${monthly.toStringAsFixed(2)} a month');
  }

  final line = buildTimeline(d.items, d.subscriptions, d.papers);
  print('  needs you now   ${flaggedCount(line)}');
  for (final e in line.take(5)) {
    print('    · ${e.title} — ${e.detail} (${whenLabelFor(e)})');
  }

  /*
    ── The checks worth running against real data ────────────────────────

    Every one of these is silent in the app and visible here. A dangling blob
    reference is the interesting one: it means an item points at a photo the
    zip does not contain, which would show as a broken thumbnail after a
    restore and is impossible to notice in a fixture I wrote myself.
  */
  print('');
  print('── anything that looks wrong ─────────────────────────');

  var problems = 0;

  for (final item in d.items) {
    for (final id in [item.thumbBlobId, item.photoBlobId]) {
      if (id != null && !bundle.blobs.containsKey(id)) {
        print('  ! "${item.name}" points at a missing image ($id)');
        problems++;
      }
    }
  }

  for (final paper in d.papers) {
    if (expiryOf(paper) == null) {
      print('  ! document "${paper.label}" has no readable expiry '
          '(was "${paper.expiresOn}")');
      problems++;
    }
  }

  for (final sub in d.subscriptions) {
    if (nextRenewal(sub) == null) {
      print('  ! subscription "${sub.name}" has no readable anchor date '
          '(was "${sub.anchorDate}")');
      problems++;
    }
  }

  final items = {for (final i in d.items) i.id};
  for (final doc in d.docs) {
    if (!items.contains(doc.itemId)) {
      print('  ! document "${doc.title ?? doc.id}" belongs to an item that is '
          'not in this backup (${doc.itemId})');
      problems++;
    }
  }

  print(problems == 0 ? '  nothing' : '  $problems to look at');
  print('');
}

/// Reports a count, and says so loudly when it disagrees with the manifest.
///
/// The manifest was written by the app that exported the file. A mismatch
/// means either the decoder dropped rows or the exporter miscounted, and both
/// are worth knowing before anything is written to a database.
void _count(String label, int got, int claimed) {
  final pad = label.padRight(15);
  if (got == claimed) {
    print('  $pad$got');
  } else {
    print('  $pad$got  ← the manifest says $claimed');
  }
}
