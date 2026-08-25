/// The screens, against a real in-memory database.
///
///   flutter test test/widget_test.dart
///
/// `main()` opens an encrypted database through the platform keystore, which
/// does not exist in a test harness — so the app is never booted here. What is
/// worth checking is that each tab renders, because a null-safety mistake or a
/// bad `switch` in a builder shows up nowhere else until it is on a phone.
///
/// ── Two harness rules this file has to obey ───────────────────────────────
/// **No `pumpAndSettle`.** Every tab shows a spinner while its query runs, and
/// a spinner is an animation that never settles — `pumpAndSettle` waits for
/// frames to stop and they never do.
///
/// **The database is closed inside the test, not in `tearDown`.** The harness
/// asserts that no timer outlives the widget tree, and it runs that check at
/// the end of the test body, before `tearDown`. An open database is a pending
/// timer, and the failure names neither.
library;

// For `Icons` in the test that taps the add button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/db/open.dart';
import 'package:stash_it/db/repository.dart';
import 'package:stash_it/db/tables.dart';
import 'package:stash_it/main.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';
import 'package:stash_it/models/types.dart';

void main() {
  Future<StashDatabase> show(
    WidgetTester tester, {
    List<Item> items = const [],
    List<Paper> papers = const [],
    List<Subscription> subs = const [],
  }) async {
    final db = openInMemory();
    final repo = Repository(db);

    for (final i in items) {
      await repo.createItem(i);
    }
    for (final p in papers) {
      await repo.createPaper(p);
    }
    for (final s in subs) {
      await repo.createSubscription(s);
    }

    await tester.pumpWidget(StashItApp(db: db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    return db;
  }

  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the dashboard opens on an empty install', (tester) async {
    final db = await show(tester);

    // Nothing to do is a state worth saying out loud, not a blank screen.
    expect(find.text('Nothing needs you.'), findsOneWidget);
    expect(find.text('Items and documents'), findsOneWidget);

    await db.close();
  });

  testWidgets('and counts what is in date', (tester) async {
    final db = await show(tester, items: [
      const Item(
        id: '',
        propertyId: 'default',
        name: 'Fridge',
        purchaseDate: '2026-07-01',
        warranty: Warranty(months: 60, unit: WarrantyUnit.months, amount: 60),
      ),
    ]);

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('in date'), findsOneWidget);

    await db.close();
  });

  testWidgets('the items tab lists what is saved', (tester) async {
    final db = await show(tester, items: [
      const Item(id: '', propertyId: 'default', name: 'Bosch Dishwasher'),
    ]);

    await goTo(tester, 'Items');
    expect(find.text('Bosch Dishwasher'), findsOneWidget);
    // No term recorded, so the tile has to say so rather than sit blank.
    expect(find.text('No warranty length recorded'), findsOneWidget);

    await db.close();
  });

  testWidgets('an empty items tab says nothing is saved', (tester) async {
    final db = await show(tester);
    await goTo(tester, 'Items');

    // `textContaining`, because the empty state also says how to fix itself —
    // an empty screen that does not tell you what to do next is a dead end.
    expect(find.textContaining('Nothing saved yet'), findsOneWidget);
    expect(find.textContaining('Tap + to put something in'), findsOneWidget);

    await db.close();
  });

  testWidgets('and the add button opens the form', (tester) async {
    final db = await show(tester);
    await goTo(tester, 'Items');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Add something'), findsOneWidget);
    // Name is the only field the app insists on, so it is the one that opens
    // focused — see `whyNotSaveable`.
    expect(find.text('Call it'), findsOneWidget);

    await db.close();
  });

  testWidgets('the documents tab names the holder', (tester) async {
    final db = await show(tester, papers: [
      const Paper(
        id: '',
        propertyId: 'default',
        kind: PaperKind.passport,
        label: 'Passport',
        holder: 'Nuno',
        expiresOn: '2030-02-11',
      ),
    ]);

    await goTo(tester, 'Documents');
    expect(find.text('Passport — Nuno'), findsOneWidget);

    await db.close();
  });

  /*
    The empty documents tab is the one screen that has to make a promise
    before anyone has put anything in. Somebody being asked to record a
    passport is entitled to know what the app will hold first.
  */
  testWidgets('and an empty one promises no scans and no numbers', (tester) async {
    final db = await show(tester);
    await goTo(tester, 'Documents');

    expect(find.textContaining('No scans, no document numbers'), findsOneWidget);

    await db.close();
  });

  testWidgets('the subscriptions tab totals what a month costs', (tester) async {
    final db = await show(tester, subs: [
      const Subscription(
        id: '',
        propertyId: 'default',
        name: 'Netflix',
        cadence: Cadence.monthly,
        anchorDate: '2026-09-22',
        amountCents: 1549,
        currency: 'USD',
      ),
    ]);

    await goTo(tester, 'Subs');
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text(r'$15.49'), findsWidgets);

    await db.close();
  });

  group('settings', () {
    /*
      A count, not a quota. The cap is off — see `capEnforced` — and a screen
      advertising a limit nothing enforces would have people rationing
      themselves against a number that does not exist.
    */
    testWidgets('shows how much is saved', (tester) async {
      final db = await show(tester, items: [
        const Item(id: '', propertyId: 'default', name: 'Kettle'),
      ]);

      await goTo(tester, 'Settings');
      expect(find.text('1 saved'), findsOneWidget);

      await db.close();
    });

    /*
      Both halves of the backup story are on the screen, and this test exists
      because for a while only one of them was. With an encrypted database
      whose key cannot leave the phone, an export nobody can find is the same
      as no export at all.
    */
    testWidgets('and offers both halves of the backup', (tester) async {
      final db = await show(tester);
      await goTo(tester, 'Settings');

      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Restore from a backup'), findsOneWidget);

      await db.close();
    });

    /*
      ── Off, and off because nobody has been asked ────────────────────────

      A fresh database has null in `notifyEnabled`, and the switch has to read
      that as off. The failure this guards against is the opposite one — a
      default that renders as on while nothing is scheduled and no permission
      has been granted, which is a screen telling somebody they are covered
      when they are not.

      The count line is deliberately absent here: it only appears once the
      switch is on, because "0 reminders set" under an off switch is noise.
    */
    testWidgets('reminders start off, and say nothing about a schedule',
        (tester) async {
      final db = await show(tester);
      await goTo(tester, 'Settings');

      await tester.scrollUntilVisible(find.text('Notify me'), 200);
      await tester.pump();

      final switchTile = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text('Notify me'),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(switchTile.value, isFalse);
      expect(find.textContaining('reminders set'), findsNothing);

      await db.close();
    });

    testWidgets('the developer tools stay hidden until ten taps', (tester) async {
      final db = await show(tester);
      await goTo(tester, 'Settings');

      expect(find.text('Developer'), findsNothing);

      /*
        Everything below is scrolled to before it is touched.

        A ListView does not build children that are off screen, so `find.text`
        genuinely cannot see them — and this screen keeps growing, which broke
        this test twice as rows were added above the version. Asking the list
        to bring a thing into view is the version that survives the next row.
      */
      Future<void> reach(String text) async {
        await tester.scrollUntilVisible(find.text(text), 200);
        await tester.pump();
      }

      // Silence until the tapping is obviously deliberate, then a countdown.
      await reach('Stash it');
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.text('Stash it'));
        await tester.pump();
      }
      expect(find.textContaining('2 more taps'), findsOneWidget);

      await tester.tap(find.text('Stash it'));
      await tester.pump();
      await tester.tap(find.text('Stash it'));
      await tester.pump();

      await reach('Developer');
      expect(find.text('Developer'), findsOneWidget);

      // Leave it as it was found — the unlock is library state and outlives
      // this test otherwise.
      await reach('Hide developer tools');
      await tester.tap(find.text('Hide developer tools'));
      await tester.pump();

      await db.close();
    });
  });
}
