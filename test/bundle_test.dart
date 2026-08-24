/// Reading a `.stashit` backup.
///
///   dart test test/bundle_test.dart
///
/// This is where the checks the type system deleted come back. Everywhere else
/// in the port a date is a `DateTime` and a lead time is an `int`, so cases
/// like `lastBackupAt: 'not a date'` and `reminderOffsetsDays: [NaN]` became
/// impossible to construct — and each time I removed one I left a note saying
/// it moved here. This file is that promise being kept.
library;

import 'dart:convert';

import 'package:stash_it/logic/bundle.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/settings.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for a real hash. Deterministic, and sensitive to both the bytes
/// and their order, which is all the parser needs it to be.
String fakeSha(List<int> bytes) {
  var h = 17;
  for (final b in bytes) {
    h = (h * 31 + b) & 0x7fffffff;
  }
  return 'sha-$h';
}

List<int> jsonBytes(Object? value) => utf8.encode(jsonEncode(value));

/// Builds an unzipped bundle, with a manifest whose checksum is already right.
Map<String, List<int>> bundle({
  Map<String, Object?> tables = const {},
  Map<String, Object?> manifestOverrides = const {},
  Map<String, List<int>> blobs = const {},
}) {
  final entries = <String, List<int>>{
    for (final e in tables.entries) '${e.key}.json': jsonBytes(e.value),
    ...blobs,
  };

  final manifest = <String, Object?>{
    'format': 'stash-it-backup',
    'formatVersion': 1,
    'schemaVersion': 4,
    'appVersion': '0.83.3',
    'exportedAt': '2026-08-17T09:00:00.000Z',
    'counts': {'items': 0, 'docs': 0, 'blobs': 0},
    'sha256': fakeSha(checksumInput(entries)),
    'encrypted': false,
    ...manifestOverrides,
  };

  return {...entries, 'manifest.json': jsonBytes(manifest)};
}

ParsedBundle parse(Map<String, List<int>> entries) =>
    parseBundle(entries, sha256Hex: fakeSha);

String failureOf(Map<String, List<int>> entries) {
  try {
    parse(entries);
    return '';
  } on BundleError catch (e) {
    return e.message;
  }
}

void main() {
  group('refusing a file', () {
    test('something that is not a backup at all', () {
      expect(failureOf({'manifest.json': jsonBytes({'format': 'something else'})}),
          contains('not a Stash it backup'));
      expect(failureOf({}), contains('not a Stash it backup'));
    });

    test('an encrypted one says so rather than failing obscurely', () {
      final f = failureOf(bundle(manifestOverrides: {'encrypted': true}));
      expect(f, contains('encrypted'));
      expect(f, contains('not built yet'));
    });

    test('a newer format version', () {
      expect(failureOf(bundle(manifestOverrides: {'formatVersion': 2})),
          contains('newer than this app understands'));
    });

    /*
      Refused rather than read on a best-effort basis. Reading it would mean
      silently discarding every field this build has never heard of, and then
      writing the result back over the database — which turns "restore my
      backup" into "delete the parts of my data this version is too old to know
      about". Refusing is recoverable; that is not.
    */
    test('and a newer schema, with the reason', () {
      final f = failureOf(bundle(manifestOverrides: {'schemaVersion': 99}));
      expect(f, contains('Update the app first'));
      expect(f, contains('would lose data'));
    });

    test('a damaged one is caught by its checksum', () {
      expect(failureOf(bundle(manifestOverrides: {'sha256': 'sha-wrong'})),
          contains('do not match its checksum'));
    });

    test('and so is a truncated table', () {
      final entries = bundle(tables: {
        'items': [
          {'id': 'a', 'name': 'Kettle', 'propertyId': 'p'},
        ],
      });
      entries['items.json'] = jsonBytes(const []); // edited after signing
      expect(failureOf(entries), contains('checksum'));
    });

    test('a schema this build has no path from', () {
      expect(failureOf(bundle(manifestOverrides: {'schemaVersion': 0})),
          contains("can't be upgraded"));
    });

    test('unreadable JSON names the file', () {
      final entries = bundle();
      entries['items.json'] = utf8.encode('{not json');
      // The checksum is computed over the same broken bytes, so it passes —
      // and the JSON failure is what the person actually needs to be told.
      entries['manifest.json'] = jsonBytes({
        'format': 'stash-it-backup',
        'formatVersion': 1,
        'schemaVersion': 4,
        'sha256': fakeSha(checksumInput(entries)),
        'encrypted': false,
      });
      expect(failureOf(entries), contains('items.json'));
    });
  });

  group('the checksum', () {
    /*
      The order is fixed and new tables go on the end. A bundle written before
      a table existed has no file for it, and a missing entry contributes zero
      bytes — so appending leaves every older backup's checksum exactly as it
      was. Inserting anywhere else would invalidate every backup ever written.
    */
    test('a missing table contributes nothing', () {
      expect(checksumInput({}), isEmpty);
    });

    test('the order is items, docs, properties, rooms, maintenance, settings,'
        ' subscriptions, papers', () {
      expect(tableOrder, [
        'items',
        'docs',
        'properties',
        'rooms',
        'maintenance',
        'settings',
        'subscriptions',
        'papers',
      ]);
    });

    test('and it is the concatenation, in that order', () {
      final input = checksumInput({
        'papers.json': [3],
        'items.json': [1],
        'docs.json': [2],
      });
      expect(input, [1, 2, 3]);
    });

    test('blobs are not in it', () {
      expect(checksumInput({'blobs/abc.webp': [9, 9, 9]}), isEmpty);
    });
  });

  group('reading the records', () {
    ParsedBundle full() => parse(bundle(tables: {
          'items': [
            {
              'id': 'kettle',
              'name': 'Kettle',
              'propertyId': 'p1',
              'purchaseDate': '2026-01-15',
              'purchasePriceCents': 4999,
              'currency': 'GBP',
              'leadDays': 90,
              'thumbBlobId': 'b1',
              'createdAt': '2026-01-16T10:00:00.000Z',
              'warranty': {'months': 24, 'unit': 'months', 'amount': 24},
            },
            {
              'id': 'binned',
              'name': 'Old lamp',
              'propertyId': 'p1',
              'deletedAt': '2026-08-01T10:00:00.000Z',
            },
          ],
          'papers': [
            {
              'id': 'dl',
              'propertyId': 'p1',
              'kind': 'licence',
              'label': 'Driving license',
              'holder': 'Nuno',
              'expiresOn': '2027-05-01',
            },
          ],
          'subscriptions': [
            {
              'id': 'nflx',
              'propertyId': 'p1',
              'name': 'Netflix',
              'cadence': 'monthly',
              'anchorDate': '2026-08-22',
              'amountCents': 1549,
              'currency': 'USD',
              'remindDays': 3,
            },
          ],
          'docs': [
            {'id': 'd1', 'itemId': 'kettle', 'kind': 'receipt', 'title': 'Receipt'},
          ],
          'rooms': [
            {'id': 'r1', 'propertyId': 'p1', 'name': 'Kitchen', 'sortOrder': 1, 'isSeed': true},
          ],
        }));

    test('an item comes back whole', () {
      final kettle = full().data.items.first;
      expect(kettle.name, 'Kettle');
      expect(kettle.purchaseDate, '2026-01-15');
      expect(kettle.purchasePriceCents, 4999);
      expect(kettle.currency, 'GBP');
      expect(kettle.leadDays, 90);
      expect(kettle.warranty!.months, 24);
      expect(kettle.warranty!.unit, WarrantyUnit.months);
      expect(kettle.createdAt, isNotNull);
    });

    /*
      Soft-deleted rows travel. A restore has to be able to undo an accidental
      delete, so the bin comes with everything else.
    */
    test('the bin travels with the rest', () {
      final binned = full().data.items.firstWhere((i) => i.id == 'binned');
      expect(binned.deletedAt, isNotNull);
    });

    /*
      `licence` is the frozen key, spelled British, written into every document
      ever saved. The label people read is American. This is the assertion that
      makes the freeze mean something.
    */
    test('the frozen licence key still finds its kind', () {
      final dl = full().data.papers.single;
      expect(dl.kind, PaperKind.licence);
      expect(dl.label, 'Driving license');
      expect(dl.holder, 'Nuno');
    });

    test('a subscription comes back whole', () {
      final s = full().data.subscriptions.single;
      expect(s.cadence, Cadence.monthly);
      expect(s.anchorDate, '2026-08-22');
      expect(s.amountCents, 1549);
      expect(s.remindDays, 3);
    });

    test('and a document knows what kind it is', () {
      expect(full().data.docs.single.kind, DocKind.receipt);
    });

    test('and a room its order', () {
      final r = full().data.rooms.single;
      expect(r.name, 'Kitchen');
      expect(r.sortOrder, 1);
      expect(r.isSeed, isTrue);
    });

    test('the manifest is read too', () {
      final m = full().manifest;
      expect(m.schemaVersion, 4);
      expect(m.appVersion, '0.83.3');
      expect(m.exportedAt, isNotNull);
      expect(m.encrypted, isFalse);
    });
  });

  group('the checks the type system deleted', () {
    Settings? settingsWith(String key, Object? value) => parse(bundle(tables: {
          'settings': {key: value},
        })).data.settings;

    /*
      THE ONE FROM nudges_test.dart. `lastBackupAt: 'not a date'` was a real
      test in the web suite, removed here because a `DateTime?` cannot hold
      prose — and every line of a backup file can.
    */
    test('an unparseable timestamp reads as never', () {
      expect(settingsWith('lastBackupAt', 'not a date')!.lastBackupAt, isNull);
    });

    test('but a real one is kept', () {
      expect(
        settingsWith('lastBackupAt', '2026-08-01T09:00:00.000Z')!.lastBackupAt,
        isNotNull,
      );
    });

    /*
      THE ONE FROM endingSoonDays. `reminderOffsetsDays: [NaN]` cannot exist in
      a `List<int>`; it can absolutely arrive in JSON.
    */
    test('a reminder list drops what is not a whole number', () {
      final parsed = parse(bundle(tables: {
        'settings': {
          'reminderOffsetsDays': [30, 'seven', 14.0, 2.5, null],
        },
      }));
      expect(parsed.data.settings!.reminderOffsetsDays, [30, 14]);
    });

    test('and an empty one falls back rather than leaving nothing to read', () {
      final parsed = parse(bundle(tables: {
        'settings': {'reminderOffsetsDays': <Object?>[]},
      }));
      expect(parsed.data.settings!.reminderOffsetsDays, [30]);
    });

    test('a whole number written as a decimal is still a number', () {
      expect(intOf(30.0), 30);
      expect(intOf(30), 30);
      expect(intOf('30'), 30);
    });

    test('but a fractional one is not', () {
      expect(intOf(30.5), isNull);
      expect(intOf(double.nan), isNull);
      expect(intOf(double.infinity), isNull);
      expect(intOf('thirty'), isNull);
      expect(intOf(null), isNull);
    });

    test('an empty string is the same as absent', () {
      expect(stringOf(''), isNull);
      expect(stringOf('   '), isNull);
      expect(stringOf(' Kettle '), 'Kettle');
      expect(stringOf(7), isNull);
    });

    /*
      A half-typed date is worse than a missing one: it is the input to every
      countdown in the app. 2026-02-31 has the right shape and does not exist,
      and `DateTime.parse` would quietly roll it into March.
    */
    test('a date that does not exist is dropped, not rolled forward', () {
      expect(isoDateOf('2026-02-31'), isNull);
      expect(isoDateOf('2026-02-28'), '2026-02-28');
    });

    test('and so is anything that is not exactly a calendar date', () {
      expect(isoDateOf('2026-8-1'), isNull);
      expect(isoDateOf('2026-08-01T09:00:00Z'), isNull);
      expect(isoDateOf('soon'), isNull);
    });

    test('an item with a broken purchase date keeps everything else', () {
      final parsed = parse(bundle(tables: {
        'items': [
          {'id': 'a', 'name': 'Kettle', 'propertyId': 'p', 'purchaseDate': '31/02/2026'},
        ],
      }));
      final kettle = parsed.data.items.single;
      expect(kettle.name, 'Kettle');
      expect(kettle.purchaseDate, isNull);
    });

    /*
      A newer build can name a kind this one has never heard of. The record is
      still worth keeping and the field can be corrected in a form, so an
      unknown value is the normal case rather than the error case.
    */
    test('an unknown kind falls back rather than throwing', () {
      final parsed = parse(bundle(tables: {
        'papers': [
          {'id': 'x', 'propertyId': 'p', 'kind': 'fishing-permit', 'label': 'Permit'},
        ],
        'docs': [
          {'id': 'd', 'itemId': 'x', 'kind': 'hologram'},
        ],
      }));
      expect(parsed.data.papers.single.kind, PaperKind.other);
      expect(parsed.data.papers.single.label, 'Permit');
      expect(parsed.data.docs.single.kind, DocKind.other);
    });

    test('and case does not decide it', () {
      expect(enumOf('MONTHLY', Cadence.values, Cadence.weekly), Cadence.monthly);
      expect(enumOf(null, Cadence.values, Cadence.weekly), Cadence.weekly);
    });

    test('a row that is not an object is skipped, not crashed on', () {
      final parsed = parse(bundle(tables: {
        'items': ['nonsense', 42, null],
      }));
      expect(parsed.data.items, isEmpty);
    });

    test('and a table that is not a list is treated as absent', () {
      final parsed = parse(bundle(tables: {'items': 'oops'}));
      expect(parsed.data.items, isEmpty);
    });
  });

  group('what must not come back', () {
    /*
      ENTITLEMENTS ARE NOT READ. Not read and discarded — not read. A backup
      file must not be a way to hand someone a paid unlock, and the surest way
      to guarantee that is for the field never to be looked at.
    */
    test('a paid unlock in the file buys nothing', () {
      final parsed = parse(bundle(tables: {
        'settings': {
          'entitlements': {'proUnlock': true, 'reportUnlock': true},
          'currency': 'GBP',
        },
      }));
      expect(parsed.data.settings!.entitlements.proUnlock, isFalse);
      expect(parsed.data.settings!.entitlements.reportUnlock, isFalse);
      // The rest of the row still restores.
      expect(parsed.data.settings!.currency, 'GBP');
    });

    /*
      A biometric credential and a push endpoint are facts about one handset.
      Restoring either onto a new phone leaves it waiting on something that was
      never set up for it — a lock screen no authenticator can satisfy, or
      reminders addressed to a device in a drawer.
    */
    test('a lock credential does not travel', () {
      final parsed = parse(bundle(tables: {
        'settings': {'biometricLock': true, 'lockCredentialId': 'abc123'},
      }));
      expect(parsed.data.settings!.biometricLock, isNull);
    });
  });

  group('what is carried through untouched', () {
    /*
      `Property` and `MaintenanceEntry` have no model in the port yet. Decoding
      them into nothing would be pointless; dropping them would be data loss,
      and silent data loss during a restore is the worst bug this file could
      have.
    */
    test('tables with no model yet are preserved verbatim', () {
      final parsed = parse(bundle(tables: {
        'properties': [
          {'id': 'p1', 'name': 'Home', 'somethingNew': 42},
        ],
        'maintenance': [
          {'id': 'm1', 'itemId': 'kettle', 'summary': 'Descaled'},
        ],
      }));

      expect(parsed.data.properties.single['name'], 'Home');
      expect(parsed.data.properties.single['somethingNew'], 42);
      expect(parsed.data.maintenance.single['summary'], 'Descaled');
    });
  });

  group('the blobs', () {
    test('are keyed by id, with the mime from the extension', () {
      final parsed = parse(bundle(blobs: {
        'blobs/abc123.webp': [1, 2, 3],
        'blobs/def456.pdf': [4, 5],
      }));

      expect(parsed.blobs['abc123']!.mime, 'image/webp');
      expect(parsed.blobs['abc123']!.bytes, [1, 2, 3]);
      expect(parsed.blobs['def456']!.mime, 'application/pdf');
    });

    test('an unknown extension is not guessed at', () {
      final parsed = parse(bundle(blobs: {
        'blobs/xyz.wat': [1],
      }));
      expect(parsed.blobs['xyz']!.mime, 'application/octet-stream');
    });

    test('and nothing outside blobs/ is treated as one', () {
      final parsed = parse(bundle(blobs: {
        'readme.txt': [1],
      }));
      expect(parsed.blobs, isEmpty);
    });
  });

  group('migration', () {
    /*
      Every step is a no-op, and that is the finding rather than an oversight.

      v1 → v2 dropped `category` from Item: the decoder simply has no such
      field, so it was discarded the moment the row was read. v2 → v3 and
      v3 → v4 each added a table, and a bundle written before one existed has
      no file for it — which `_rows` already turned into an empty list.

      The TypeScript also restamped every record's `schemaVersion` on each
      step. The Dart models carry no such field: a decoded record is by
      definition current, because the decoder is this build's. The version
      lives on the file, not on the row.
    */
    test('a v1 bundle reads, and the dropped field is simply not there', () {
      final entries = bundle(
        tables: {
          'items': [
            {'id': 'a', 'name': 'Kettle', 'propertyId': 'p', 'category': 'kitchen'},
          ],
        },
        manifestOverrides: {'schemaVersion': 1},
      );
      final parsed = parse(entries);
      expect(parsed.data.items.single.name, 'Kettle');
    });

    test('a v3 bundle with no papers table reads as no papers', () {
      final parsed = parse(bundle(
        tables: {
          'items': [
            {'id': 'a', 'name': 'Kettle', 'propertyId': 'p'},
          ],
        },
        manifestOverrides: {'schemaVersion': 3},
      ));
      expect(parsed.data.papers, isEmpty);
      expect(parsed.data.items, hasLength(1));
    });

    test('and migrating from the current version does nothing', () {
      const data = BundleData();
      expect(identical(migrateBundle(data, schemaVersion), data), isTrue);
    });
  });
}
