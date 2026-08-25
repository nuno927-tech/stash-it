/// Nothing is lost by saving something.
///
///   flutter test test/nothing_is_lost_test.dart
///
/// ── Why this suite exists ─────────────────────────────────────────────────
/// The same bug was found five times in three days, in five different files:
///
///   `Doc.blobId`              — a restored receipt lost its file
///   `ItemDraft.roomId`        — editing an item moved it out of its room
///   `ItemDraft.photoBlobId`   — editing an item severed its photograph
///   `ItemDraft` coverages     — editing a legacy record destroyed its warranty
///   `SubscriptionDraft.logoBlobId` — editing a subscription orphaned its logo
///
/// Every one had the same shape. A record passes through a layer that does not
/// know about one of its fields, and that layer writes the record back whole —
/// so the field it never heard of is set to null. No error, no warning, and
/// nothing on any screen to notice.
///
/// **The rule: every layer a record passes through must carry every field of
/// it, whether or not that layer has any use for the field.**
///
/// ── Why the existing tests missed all five ────────────────────────────────
/// There was already a test called "saving an untouched draft changes nothing".
/// It passed throughout. Its fixture had no room, no photograph and no legacy
/// warranty, so there was nothing there to lose.
///
/// So the fixtures below are deliberately maximal: every optional field set to
/// something distinguishable. A round-trip test is worth exactly as much as the
/// awkwardness of what you send through it.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/db/open.dart';
import 'package:stash_it/db/repository.dart';
import 'package:stash_it/db/tables.dart';
import 'package:stash_it/logic/bundle.dart';
import 'package:stash_it/logic/bundle_write.dart';
import 'package:stash_it/logic/item_form.dart';
import 'package:stash_it/logic/paper_form.dart';
import 'package:stash_it/logic/subscription_form.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';

/* ------------------------------------------------------- the fixtures */

final theWorks = Item(
  id: 'tv',
  propertyId: 'default',
  name: 'Television',
  brand: 'LG',
  model: 'OLED65',
  serial: 'LG-1234-X',
  roomId: 'living-room',
  purchaseDate: '2026-02-01',
  purchasePriceCents: 189900,
  currency: 'GBP',
  retailer: 'John Lewis',
  leadDays: 60,
  notes: 'Wall mounted',
  thumbBlobId: 'thumb-1',
  photoBlobId: 'photo-1',
  createdAt: DateTime.utc(2026, 2, 2, 9),
  coverages: const [
    Coverage(
      id: 'panel',
      label: 'Panel',
      unit: CoverageUnit.years,
      amount: 5,
      covers: 'Burn-in and dead pixels',
      startsOn: '2026-02-01',
      provider: 'LG',
      policyNumber: 'LG-99-1',
      phone: '0800 000 000',
      url: 'https://example.com/claim',
    ),
  ],
);

final thePassport = Paper(
  id: 'pp',
  propertyId: 'default',
  kind: PaperKind.passport,
  label: 'Passport',
  holder: 'Nuno',
  expiresOn: '2027-02-11',
  issuedOn: '2017-02-11',
  leadDays: 240,
  authority: 'HMPO',
  storedAt: 'Desk drawer',
  notes: 'Renew early, processing is slow',
  createdAt: DateTime.utc(2026, 1, 3, 8),
);

final theGym = Subscription(
  id: 'gym',
  propertyId: 'default',
  name: 'The gym',
  serviceId: 'puregym',
  logoBlobId: 'logo-1',
  cadence: Cadence.monthly,
  anchorDate: '2026-09-01',
  amountCents: 2499,
  currency: 'GBP',
  startedDate: '2024-06-01',
  remindDays: 3,
  notes: 'Cancel before the annual rise',
  createdAt: DateTime.utc(2026, 1, 4, 8),
);

const theReceipt = Doc(
  id: 'd1',
  itemId: 'tv',
  kind: DocKind.receipt,
  title: 'John Lewis receipt',
  blobId: 'receipt-pdf',
  url: 'https://example.com/receipt',
);

void main() {
  late StashDatabase db;
  late Repository repo;

  setUp(() {
    db = openInMemory();
    repo = Repository(db);
  });
  tearDown(() => db.close());

  /* ─────────────────────────────────────────────────────────────────────
     THE FORMS. This is where four of the five bugs lived.

     A draft is the narrowest layer in the app — it only holds what the form
     shows — which makes it the one most likely to drop something, and the one
     where dropping something is a delete rather than a display bug.
     ───────────────────────────────────────────────────────────────────── */

  group('opening a form and saving it unchanged', () {
    test('keeps every field of an item', () {
      final back = toItem(
        draftOf(theWorks),
        propertyId: 'default',
        createdAt: theWorks.createdAt,
      );

      expect(back.name, theWorks.name);
      expect(back.brand, theWorks.brand);
      expect(back.model, theWorks.model);
      expect(back.serial, theWorks.serial);
      expect(back.roomId, theWorks.roomId);
      expect(back.purchaseDate, theWorks.purchaseDate);
      expect(back.purchasePriceCents, theWorks.purchasePriceCents);
      expect(back.currency, theWorks.currency);
      expect(back.retailer, theWorks.retailer);
      expect(back.leadDays, theWorks.leadDays);
      expect(back.notes, theWorks.notes);
      expect(back.thumbBlobId, theWorks.thumbBlobId);
      expect(back.photoBlobId, theWorks.photoBlobId);
      expect(back.createdAt, theWorks.createdAt);
    });

    test('and every field of its cover, including the ones not on the form', () {
      final policy = toItem(draftOf(theWorks), propertyId: 'default')
          .coverages
          .single;
      final was = theWorks.coverages.single;

      expect(policy.id, was.id);
      expect(policy.label, was.label);
      expect(policy.unit, was.unit);
      expect(policy.amount, was.amount);
      expect(policy.covers, was.covers);
      expect(policy.startsOn, was.startsOn);
      expect(policy.provider, was.provider);
      expect(policy.policyNumber, was.policyNumber);
      expect(policy.phone, was.phone);
      expect(policy.url, was.url);
    });

    test('keeps every field of a document', () {
      final back = toPaper(draftOfPaper(thePassport), propertyId: 'default');

      expect(back.kind, thePassport.kind);
      expect(back.label, thePassport.label);
      expect(back.holder, thePassport.holder);
      expect(back.expiresOn, thePassport.expiresOn);
      expect(back.issuedOn, thePassport.issuedOn);
      expect(back.leadDays, thePassport.leadDays);
      expect(back.authority, thePassport.authority);
      expect(back.storedAt, thePassport.storedAt);
      expect(back.notes, thePassport.notes);
      expect(back.createdAt, thePassport.createdAt);
    });

    test('keeps every field of a subscription', () {
      final back =
          toSubscription(draftOfSubscription(theGym), propertyId: 'default');

      expect(back.name, theGym.name);
      expect(back.serviceId, theGym.serviceId);
      expect(back.logoBlobId, theGym.logoBlobId, reason: 'the logo, orphaned before');
      expect(back.cadence, theGym.cadence);
      expect(back.anchorDate, theGym.anchorDate);
      expect(back.amountCents, theGym.amountCents);
      expect(back.currency, theGym.currency);
      expect(back.startedDate, theGym.startedDate);
      expect(back.remindDays, theGym.remindDays);
      expect(back.notes, theGym.notes);
      expect(back.createdAt, theGym.createdAt);
    });
  });

  /* ─────────────────────────────────────────────────────────────────────
     THE DATABASE. `saveItem`, `savePaper` and `saveSubscription` all use
     `.replace()`, which writes the whole row — so a field the mapper forgets
     is not left alone, it is set to null.
     ───────────────────────────────────────────────────────────────────── */

  group('saving to the database and reading it back', () {
    /*
      ── Instants, not clock faces ─────────────────────────────────────────

      SQLite has no date type, so Drift stores a `DateTime` as a unix timestamp
      and reads it back in the phone's local zone. A field written as
      09:00 UTC comes back as 04:00-05:00 — the same moment, described from
      where the phone is standing.

      So these compare instants rather than values. `expect(a, b)` on two
      `DateTime`s compares the UTC flag as well, and would fail here on a
      difference that is not a loss. The suite is about fields being dropped;
      asserting the representation instead would mean this file failing for
      anyone who ran it in a different time zone from mine.
    */
    Matcher sameMoment(DateTime? d) =>
        d == null ? isNull : predicate<DateTime?>((v) => v?.isAtSameMomentAs(d) ?? false);

    test('keeps every field of an item', () async {
      await repo.createItem(theWorks);
      await repo.saveItem(theWorks);

      final back = (await repo.activeItems()).single;
      expect(back.roomId, 'living-room');
      expect(back.photoBlobId, 'photo-1');
      expect(back.thumbBlobId, 'thumb-1');
      expect(back.coverages.single.phone, '0800 000 000');
      expect(back.createdAt, sameMoment(theWorks.createdAt));
    });

    test('keeps every field of a document', () async {
      await repo.createPaper(thePassport);
      await repo.savePaper(thePassport);

      final back = (await repo.activePapers()).single;
      expect(back.issuedOn, '2017-02-11');
      expect(back.authority, 'HMPO');
      expect(back.storedAt, 'Desk drawer');
      expect(back.createdAt, sameMoment(thePassport.createdAt));
    });

    test('keeps every field of a subscription', () async {
      await repo.createSubscription(theGym);
      await repo.saveSubscription(theGym);

      final back = (await repo.activeSubscriptions()).single;
      expect(back.serviceId, 'puregym');
      expect(back.logoBlobId, 'logo-1');
      expect(back.startedDate, '2024-06-01');
      expect(back.createdAt, sameMoment(theGym.createdAt));
    });

    test('keeps both halves of a document attachment', () async {
      await repo.createItem(theWorks);
      await repo.putBlob('receipt-pdf', Uint8List.fromList([1]), 'application/pdf');
      await repo.createDoc(theReceipt);

      final back = (await repo.docsForItem('tv')).single;
      expect(back.blobId, 'receipt-pdf');
      expect(back.url, 'https://example.com/receipt');
      expect(back.kind, DocKind.receipt);
      expect(back.title, 'John Lewis receipt');
    });
  });

  /* ─────────────────────────────────────────────────────────────────────
     THE BACKUP. `bundle_write.dart` is the mirror of `bundle.dart` field for
     field, and the only way either can be wrong is by disagreeing with the
     other — including by agreeing to say nothing about a field.
     ───────────────────────────────────────────────────────────────────── */

  group('through a backup file and back', () {
    test('an item keeps everything', () {
      final back = readItem(itemToJson(theWorks).cast<String, dynamic>());

      expect(back.roomId, theWorks.roomId);
      expect(back.photoBlobId, theWorks.photoBlobId);
      expect(back.thumbBlobId, theWorks.thumbBlobId);
      expect(back.createdAt, theWorks.createdAt);
      expect(back.coverages.single.url, 'https://example.com/claim');
    });

    test('a document keeps its file', () {
      final back = readDoc(docToJson(theReceipt).cast<String, dynamic>());
      expect(back.blobId, 'receipt-pdf');
      expect(back.url, 'https://example.com/receipt');
    });

    test('a paper keeps everything', () {
      final back = readPaper(paperToJson(thePassport).cast<String, dynamic>());
      expect(back.issuedOn, thePassport.issuedOn);
      expect(back.authority, thePassport.authority);
      expect(back.storedAt, thePassport.storedAt);
      expect(back.createdAt, thePassport.createdAt);
    });

    test('a subscription keeps everything', () {
      final back =
          readSubscription(subscriptionToJson(theGym).cast<String, dynamic>());
      expect(back.serviceId, theGym.serviceId);
      expect(back.logoBlobId, theGym.logoBlobId);
      expect(back.startedDate, theGym.startedDate);
      expect(back.createdAt, theGym.createdAt);
    });
  });
}
