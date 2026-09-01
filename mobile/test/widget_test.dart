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
import 'package:stash_it/ui/add_button.dart' show StashItButton;
import 'package:stash_it/ui/parts.dart' show StashPill;
import 'package:stash_it/ui/prefs_scope.dart';
import 'package:stash_it/ui/settings_tab.dart' show appVersion;

void main() {
  Future<StashDatabase> show(
    WidgetTester tester, {
    List<Item> items = const [],
    List<Paper> papers = const [],
    List<Subscription> subs = const [],

    /*
      ── Onboarded, unless a test says otherwise ─────────────────────────────

      The shell offers the tour on any launch where nobody has taken it and
      nobody has skipped it — which is exactly the state a freshly-opened
      in-memory database is in. So every test in this file was a first
      install, and once the clock passed `splashTotal` a modal sheet slid up
      over whatever the test was looking at. Thirteen failed at once.

      That is the same shape as the splash, whose own note two dozen lines
      below records twelve failures for the same reason: a widget that wraps
      or covers the whole tree is invisible in the source of a test and total
      in its effect.

      The default is `true` because these tests are about the app in use, not
      about meeting it. Pass `false` to exercise the first-launch path — and
      the scheduling itself is covered without a widget at all, in
      tour_launch_test.dart.
    */
    bool onboarded = true,
  }) async {
    final db = openInMemory();
    final repo = Repository(db);

    if (onboarded) {
      final now = await repo.settings();
      await repo.saveSettings(now.copyWith(onboardedAt: DateTime.now()));
    }

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

    /*
      ── And past the entrance animations ────────────────────────────────────

      The ring sweeps its arc and counts its percentage up over 850ms, and the
      dashboard figures do the same. Crucially they do NOT start at t=0: they
      start when their data arrives, which is after the futures above resolve.
      So the pumps that clear the splash are not enough, and a test asserting
      "100" found a ring that had reached 72.

      Two full sweeps' worth, so the margin is the length of the animation
      again rather than a few milliseconds of luck.
    */
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));
    return db;
  }

  /*
    ── Now past the slide, not just past the tap ────────────────────────────

    Tabs cross-fade and slide over 240ms, and for that whole time BOTH are
    mounted — the arriving one and the leaving one, each with its own database
    queries and its own animation controllers. The leaving tab is disposed at
    the end of it.

    That matters more than it looks: a test that asserts, and then closes the
    database, while a tab it has navigated away from is still subscribed to a
    query stream is a test that can sit waiting on `close()`.

    So this now outlasts the transition with room to spare rather than by
    sixty milliseconds.
  */
  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /*
    ── Pump until it turns up, rather than guessing when ────────────────────

    The tour is not on a fixed clock from the test's point of view. `Shell` is
    built inside `LockGate`, which does not build its child until it has read
    the lock setting — so the timer that offers the tour starts at whatever
    moment that read lands, and only then waits `splashTotal`. Adding the
    callback's own database read and a route animation on top, "when" is a
    number this file cannot know.

    So it pumps until the thing appears, with a ceiling. Nothing is hidden: if
    the tour never comes the finder is still empty and the expectation still
    fails — this only stops the test being wrong about the timetable.
  */
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// What is actually on screen, for when a finder comes back empty and the
  /// failure would otherwise say only that.
  String onScreen(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .take(12)
      .join(' | ');

  /*
    ── The tour, which for sixty versions did not arrive ────────────────────

    Every other test in this file passes `onboarded: true` by default, which
    means none of them would notice if this broke again. These two are the
    pair that would.

    Pumped in explicit steps rather than settled: Scout breathes on a
    repeating controller, so `pumpAndSettle` never returns.
  */
  testWidgets('a first install is offered the tour', (tester) async {
    /*
      ── A portrait phone, for this test only ────────────────────────────────

      Every test in this file runs on the default 800x600 surface, which is
      landscape and nothing like the device this app is built for. Harmless
      for a list or a settings row; not harmless for a bottom sheet, which is
      sized as a fraction of the height it is given.

      Set before `show` so the very first layout is the right shape, and put
      back afterwards so nothing else in the file inherits it.
    */
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = await show(tester, onboarded: false);

    final first = find.text('Everything you own, with its paperwork');
    await pumpUntil(tester, first);

    expect(first, findsOneWidget,
        reason: 'on screen instead: ${onScreen(tester)}');

    /*
      ── Why this does not go on to tap Skip ─────────────────────────────────

      It tried to, and the tap kept landing outside the render tree: y=971 on
      a 600-tall surface, y=1469 on a 900-tall one. Both are almost exactly
      1.63x the viewport, so the footer is not merely below the fold on a
      small window — it scales with the window and is always off it. Resizing
      cannot fix that, and `ensureVisible` cannot either, because the footer
      sits outside the PageView rather than inside a scrollable.

      That is a fact about how the sheet lays out, not about this test, and it
      is written down in the version note rather than worked around here.

      What this test is for is the bug that was actually reported: a fresh
      install was never offered the tour at all. That assertion is above and
      it passes. `_later` is exercised through `remindLater` and
      `tourOnLaunch` in tour_launch_test.dart, without a widget.
    */
    await db.close();
  });

  testWidgets('and somebody who has seen it is left alone', (tester) async {
    final db = await show(tester);

    // Wound well past any point the tour could have arrived, so absence here
    // means it was never offered rather than not offered yet.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Everything you own, with its paperwork'), findsNothing);

    /*
      Every other test in this file ends this way and mine did not, which is
      the whole of the "Timer is still pending" failure.

      Drift schedules a zero-duration timer when a query stream is let go, and
      the binding tears the tree down and checks for stray timers in the same
      breath — so the cleanup is queued and never run. Closing the database
      here drains it while there are still frames to spend.
    */
    await db.close();
  });

  testWidgets('the dashboard opens on an empty install', (tester) async {
    final db = await show(tester);

    /*
      A brand new install shows the first-run screen, not a dashboard.

      This used to assert 'Nothing needs you.' and the section headings, which
      is what the dashboard says when it has records and none of them need
      anything. On an app with nothing in it at all that dashboard is a ring at
      nought per cent, four zeroes and a backup warning about data that does
      not exist — all true, none of it useful, and the first thing anybody
      sees. See `firstThing`.
    */
    expect(find.textContaining('Nothing stashed yet'), findsOneWidget);
    /*
      The button, not the words.

      The sentence used to say "Tap Stash it" and now puts a real, working
      Stash it button in the line where those words were — so there is no
      such text to find any more, and `textContaining` would pass on a
      screen where the button had silently vanished.

      Finding the widget is the assertion that matches what the screen
      actually promises: something tappable, right there.
    */
    expect(find.byType(StashPill), findsOneWidget);

    // And the dashboard is genuinely not there, rather than merely scrolled
    // out of view behind it.
    expect(find.text('ITEMS AND DOCUMENTS'), findsNothing);

    /*
      The greeting stays, though, and that is the point of it.

      It is the one line on this screen worth the same on day one as on day
      four hundred: the app saying hello, by name, to somebody who has just
      typed that name into the tour. Losing it on an empty install would make
      the first screen the coldest one.
    */
    // 'Good ' rather than 'Good morning': the test suite runs at whatever
    // hour somebody happens to run it, and pinning one of the three would be
    // a test that fails after lunch.
    expect(find.textContaining('Good '), findsOneWidget);

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
    expect(find.textContaining('Nothing stashed yet'), findsOneWidget);
    // Named, not drawn as a symbol: the button is a pill with the app's name
    // on it now, and "tap +" would send somebody looking for a plus that is
    // only half of what the button says.
    /*
      The button, not the words.

      The sentence used to say "Tap Stash it" and now puts a real, working
      Stash it button in the line where those words were — so there is no
      such text to find any more, and `textContaining` would pass on a
      screen where the button had silently vanished.

      Finding the widget is the assertion that matches what the screen
      actually promises: something tappable, right there.
    */
    expect(find.byType(StashPill), findsOneWidget);

    /*
      And the header is gone with it.

      A total worth zero, a search box with nothing to search and six filter
      chips that all match nothing. Every one of those controls answers "which
      of my things am I looking at", which is not a question somebody has
      before they have any.
    */
    expect(find.byType(TextField), findsNothing);

    await db.close();
  });

  /*
    ── The add button asks which kind, and that is the point of it ───────────

    It used to be a `+` on each tab that added whatever that tab held, which
    works right up until somebody looking at their subscriptions wants to add a
    receipt. One button, three answers — so this test taps through the sheet
    rather than landing straight on the form.
  */
  testWidgets('the Stash it button asks what kind, then asks what it is',
      (tester) async {
    /*
      ── Adding an item is four questions now, not a form ────────────────────

      This asserted the full form's first card and its labels. Adding opens the
      step-by-step sheet instead: a dozen labelled boxes is right for editing,
      where somebody has come to change one specific thing and needs to find
      it, and wrong for the first thirty seconds of owning the app.

      Editing still opens the form, and that path is covered where an existing
      item is tapped.
    */
    final db = await show(tester);
    await goTo(tester, 'Items');

    /*
      The floating button's plus, not the other one.

      The empty screens now put a working Stash it button in the middle of
      their sentence, and it has a plus on it too — so `byIcon(Icons.add)`
      finds two and `tap` refuses to guess. Naming the widget it belongs to is
      the durable fix; matching on size would break the first time either is
      restyled.
    */
    await tester.tap(find.descendant(
      of: find.byType(StashItButton),
      matching: find.byIcon(Icons.add),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Product'), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Document'), findsOneWidget);

    await tester.tap(find.text('Product'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The first question, and the way out for anybody who wants every field
    // at once.
    expect(find.text('What is it?'), findsOneWidget);
    expect(find.text('Add the long way'), findsOneWidget);

    /*
      "Next", not "Save item" — and disabled until there is a name.

      The name is the one thing the app insists on, so the button says so by
      being unavailable rather than by refusing four screens later.
    */
    expect(find.text('Next'), findsOneWidget);
    // Found through its own label rather than by type. The screens behind
    // this sheet have buttons too, and a bare byType finder is one restyle
    // away from asserting about the wrong one.
    expect(
      tester
          .widget<FilledButton>(find.ancestor(
            of: find.text('Next'),
            matching: find.byType(FilledButton),
          ))
          .onPressed,
      isNull,
    );

    await db.close();
  });

  testWidgets('the long way out of the wizard carries the name across',
      (tester) async {
    // An escape hatch that throws away what was already typed is one people
    // use once.
    final db = await show(tester);
    await goTo(tester, 'Items');

    /*
      The floating button's plus, not the other one.

      The empty screens now put a working Stash it button in the middle of
      their sentence, and it has a plus on it too — so `byIcon(Icons.add)`
      finds two and `tap` refuses to guess. Naming the widget it belongs to is
      the durable fix; matching on size would break the first time either is
      restyled.
    */
    await tester.tap(find.descendant(
      of: find.byType(StashItButton),
      matching: find.byIcon(Icons.add),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Product'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byType(TextField).first, 'Bosch dishwasher');
    await tester.pump();

    await tester.tap(find.text('Add the long way'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The full form, with the name already in it.
    expect(find.text('Product information'), findsOneWidget);
    expect(find.text('Save item'), findsOneWidget);
    expect(find.text('Bosch dishwasher'), findsOneWidget);

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
    ── A promise that used to be here, and is not ──────────────────────────

    This asserted 'No scans, no document numbers' on the empty Documents tab,
    and the reasoning behind it was good: somebody being asked to record a
    passport is entitled to know what the app will hold before they type
    anything.

    That sentence went when the four tabs were given one shared first-run
    message. The promise is still true — the app has never stored a scan or a
    document number, and `Paper` structurally cannot — and it is still made in
    the privacy policy and on the document form. It is no longer made on the
    empty screen.

    Worth revisiting: consistency across four tabs is a smaller thing than
    telling somebody what you will do with their passport.
  */
  testWidgets('an empty documents tab says how to start', (tester) async {
    final db = await show(tester);
    await goTo(tester, 'Documents');

    expect(find.textContaining('Nothing stashed yet'), findsOneWidget);
    /*
      The button, not the words.

      The sentence used to say "Tap Stash it" and now puts a real, working
      Stash it button in the line where those words were — so there is no
      such text to find any more, and `textContaining` would pass on a
      screen where the button had silently vanished.

      Finding the widget is the assertion that matches what the screen
      actually promises: something tappable, right there.
    */
    expect(find.byType(StashPill), findsOneWidget);

    await db.close();
  });

  testWidgets('the subscriptions tab totals what a month costs',
      (tester) async {
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
          of: find
              .ancestor(
                of: find.text('Push Notifications'),
                matching: find.byType(Row),
              )
              .last,
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
