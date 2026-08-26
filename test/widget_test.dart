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
import 'package:stash_it/ui/prefs_scope.dart';
import 'package:stash_it/ui/settings_tab.dart' show appVersion;

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

    /*
      The preferences are loaded before the widget is pumped, the same way
      `main` does it — the theme has to be settled before the first frame or
      every launch is a flash of the wrong palette. Loading them here also
      means the tests exercise the real path rather than a default the app
      never actually uses.
    */
    final prefs = PrefsController(repo);
    await prefs.load();

    await tester.pumpWidget(StashItApp(repo: repo, prefs: prefs));
    await tester.pump();

    /*
      ── Past the splash ──────────────────────────────────────────────────────

      `Splash` holds the screen for 1.1 seconds and then fades out over 0.4 —
      so until this clock has been wound forward there is a full-screen title
      card over the app and every finder in this file comes back empty. Twelve
      tests failed at once when it was added, which is what a widget wrapping
      the whole tree looks like from in here.

      Wound, not settled: Scout breathes on a repeating controller, so
      `pumpAndSettle` would spin until it timed out.
    */
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));

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

    /*
      The number and its sign are two `Text`s now, not one string.

      They are set at 52px and 19px on a shared baseline, because "100" is the
      figure and "%" is its unit — one string could not do that. So the finder
      asks for the part that carries the meaning.
    */
    expect(find.text('100'), findsOneWidget);
    expect(find.text('still in date'), findsOneWidget);

    /*
      ── Said twice, worded differently, and that is the point ──────────────

      This has been asserted as one, then as two, and is one again — which
      looks like churn and is actually the design settling.

      The ring is the SUMMARY and the row beneath it is the BREAKDOWN: one
      percentage against four counts that add up to the collection. Both are
      about the same thing, so both say so — but the ring says "still in date"
      and the column says "in date", and that difference is what stops the pair
      reading as the same fact printed twice.

      So: exactly one of each. Two identical strings would mean the wording had
      drifted back together.
    */
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
    // Named, not drawn as a symbol: the button is a pill with the app's name
    // on it now, and "tap +" would send somebody looking for a plus that is
    // only half of what the button says.
    expect(find.textContaining('Tap Stash it to put something in'), findsOneWidget);

    await db.close();
  });

  /*
    ── The add button asks which kind, and that is the point of it ───────────

    It used to be a `+` on each tab that added whatever that tab held, which
    works right up until somebody looking at their subscriptions wants to add a
    receipt. One button, three answers — so this test taps through the sheet
    rather than landing straight on the form.
  */
  testWidgets('the Stash it button asks what kind, then opens the form',
      (tester) async {
    final db = await show(tester);
    await goTo(tester, 'Items');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Product'), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);

    await tester.tap(find.text('Product'));
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

    // The month's total is above the fold; the list is not.
    expect(find.text(r'$15.49'), findsWidgets);

    /*
      ── Scrolled to, because a ListView does not build what is off screen ────

      This screen grew a four-tile grid, a month calendar and a "next up" line
      above the list, which on a 600-pixel test viewport puts the first row
      below the fold — and `find.text` genuinely cannot see a child that was
      never built.

      The same trap the settings suite hit twice as rows were added above the
      version. Asking the list to bring the row into view is the version that
      survives the next thing added above it.
    */
    await tester.scrollUntilVisible(
      find.text('Netflix'),
      200,
      /*
        Named, because there are three scrollables on this screen now: the
        list, the calendar's grid and the chart. `scrollUntilVisible` defaults
        to "the one Scrollable" and threw `Too many elements` on the second.

        `.first` is the outer list — an ancestor is visited before its
        descendants — and it is the only one that actually scrolls; the
        calendar's grid is shrink-wrapped with `NeverScrollableScrollPhysics`
        and still counts as one.
      */
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Netflix'), findsOneWidget);

    await db.close();
  });

  group('settings', () {
    /*
      ── The settings list resolves before anything can be found in it ────────

      The screen reads the settings row from the database, so its first frame is
      a spinner and there is no `Scrollable` in the tree at all. Three tests
      failed on that — one with "No element" from `scrollUntilVisible` looking
      for a list that did not exist yet.

      Pumped rather than settled, because Scout breathes on a repeating
      controller and `pumpAndSettle` would spin until it timed out.
    */
    Future<void> openSettings(WidgetTester tester) async {
      await goTo(tester, 'Settings');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    /*
      There are several scrollables on this screen now, and the outer list is
      the only one that scrolls. An ancestor is visited before its descendants,
      so `.first` is it.
    */
    Future<void> reach(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
    }

    /*
      The subtitle, which is the screen saying what it is for.

      This used to assert "1 saved" — a count of the collection that sat at the
      top of Settings while the item cap existed. The cap is off and the count
      moved to the Items screen, where the collection actually is.
    */
    testWidgets('says what it is for', (tester) async {
      final db = await show(tester, items: [
        const Item(id: '', propertyId: 'default', name: 'Kettle'),
      ]);

      await openSettings(tester);
      expect(find.text('How Stash it behaves.'), findsOneWidget);

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
      await openSettings(tester);

      await reach(tester, find.text('Back up now'));
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Import from a backup'), findsOneWidget);

      await db.close();
    });

    /*
      ── On, and on because nobody has said otherwise ──────────────────────

      This asserted the opposite for months, with a note explaining that a
      switch reading "on" while nothing is scheduled tells somebody they are
      covered when they are not.

      That reasoning was sound and the conclusion was wrong. **The app's whole
      reason to exist is telling you a date before it passes**, and a warning
      switched off by default is a warning nobody has — the person who most
      needs it is the one least likely to go looking for it.

      The honesty problem is answered where it arises instead: the permission is
      requested on first launch, and `syncReminders` re-checks it on every
      launch, so the switch cannot go on claiming a schedule the system has
      since revoked.

      A fresh database has null in `notifyEnabled`, and null is not a decision —
      only an explicit false counts as one.
    */
    testWidgets('push notifications start on', (tester) async {
      final db = await show(tester);
      await openSettings(tester);

      await reach(tester, find.text('Push Notifications'));

      final control = tester.widget<Switch>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Push Notifications'),
            matching: find.byType(Row),
          ).last,
          matching: find.byType(Switch),
        ),
      );
      expect(control.value, isTrue);

      await db.close();
    });

    /*
      ── Two hidden gestures, two audiences ──────────────────────────────────

      Scout opens his own album. The version card at the foot of the page opens
      the developer tools. They used to be one gesture, which put a switch that
      lifts the item cap behind the same ten taps as a joke — somebody messing
      about would have found a debug panel they now have to wonder about.

      The album gesture moved off the "Settings" heading and onto Scout. A
      heading is the one thing on a screen nobody suspects of doing anything,
      so the only people who ever found it were told about it; poking the
      animal is a thing people already try. There is no visible countdown on
      this one — the reply is a haptic tick per tap, which a test cannot see,
      so what is pinned here is the tenth tap and the fact that the developer
      tools stay shut.
    */
    testWidgets('ten taps on Scout opens the album, and nothing else',
        (tester) async {
      final db = await show(tester);
      await openSettings(tester);

      final scout = find.byKey(const Key('scout-easter-egg'));
      expect(scout, findsOneWidget);

      for (var i = 0; i < 9; i++) {
        await tester.tap(scout);
        await tester.pump();
      }
      expect(find.text("You found Scout's album"), findsNothing);

      await tester.tap(scout);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text("You found Scout's album"), findsOneWidget);
      expect(find.text('How Scout got the job'), findsOneWidget);

      // And the developer tools stayed shut. This is the half of the split
      // worth pinning: the reward must not also hand over the debug switch.
      expect(find.text('Developer'), findsNothing);

      await db.close();
    });

    testWidgets('the developer tools stay hidden until ten taps on the version',
        (tester) async {
      final db = await show(tester);
      await openSettings(tester);

      expect(find.text('Developer'), findsNothing);

      /*
        ── The version card, at the foot of the page ─────────────────────────

        A version number is a poor easter egg — people tap it by accident while
        reading it — and a good place for something that should only be reached
        deliberately, because anybody who wants it knows to come here.
      */
      final version = find.text('v$appVersion');
      await reach(tester, version);

      for (var i = 0; i < 8; i++) {
        await tester.tap(version);
        await tester.pump();
      }
      expect(find.textContaining('2 more taps'), findsOneWidget);

      await tester.tap(version);
      await tester.pump();
      await tester.tap(version);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await reach(tester, find.text('Developer'));
      expect(find.text('Developer'), findsOneWidget);

      // Leave it as it was found — the unlock is library state and outlives
      // this test otherwise.
      await reach(tester, find.text('Hide developer tools'));
      await tester.tap(find.text('Hide developer tools'));
      await tester.pump();

      await db.close();
    });
  });
}
