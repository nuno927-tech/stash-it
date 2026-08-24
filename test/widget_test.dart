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
    expect(find.text('Nothing saved yet.'), findsOneWidget);
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
    testWidgets('shows how much of the free tier is used', (tester) async {
      final db = await show(tester, items: [
        const Item(id: '', propertyId: 'default', name: 'Kettle'),
      ]);

      await goTo(tester, 'Settings');
      expect(find.text('1 of 25 saved'), findsOneWidget);

      await db.close();
    });

    /*
      The backup writer does not exist yet, and the row says so rather than
      being absent. A missing row lets somebody assume the feature is
      somewhere they have not looked — and with an encrypted database whose
      key cannot leave the phone, that assumption is expensive.
    */
    testWidgets('and admits the backup writer is missing', (tester) async {
      final db = await show(tester);
      await goTo(tester, 'Settings');

      expect(find.text('Back up now'), findsOneWidget);
      expect(find.textContaining('Not built yet'), findsWidgets);

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
