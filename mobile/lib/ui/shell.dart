/// The five tabs, the bar under them, and the swipe between them.
///
/// ── The order is not cosmetic ─────────────────────────────────────────────
/// It comes from `Tab` in logic/swipe.dart, which is the same list the swipe
/// gesture steps through. They were once two lists: Subscriptions was added to
/// the bar and not to the order, so swiping left from Items landed on Settings
/// — it skipped the tab sitting between them and nothing on screen explained
/// why. One list, one order.
library;

// Material exports a `Tab` widget — the thing that sits in a `TabBar`. Ours is
// the enum in logic/swipe.dart, which is the app's five destinations. Material
// is the one hidden, because this app has no TabBar and every mention of `Tab`
// in these files means a destination.
import 'dart:async';

import 'package:flutter/material.dart' hide Tab;

import '../db/repository.dart';
import '../logic/deep_link.dart';
import '../logic/swipe.dart';
import '../notify/pending_link.dart';
import 'add_button.dart';
import 'item_detail_screen.dart';
import 'paper_form_sheet.dart';
import 'sub_form_sheet.dart';
import 'feedback.dart';
import 'home_tab.dart';
import 'items_tab.dart';
import 'nav_icons.dart';
import 'papers_tab.dart';
import '../logic/tour.dart';
import 'parts.dart';
import 'pro_badge.dart';
import 'settings_tab.dart';
import 'splash.dart';
import 'subs_tab.dart';
import 'tour_screen.dart';
import 'theme.dart';

class Shell extends StatefulWidget {
  const Shell({required this.repo, super.key});

  final Repository repo;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Tab _tab = Tab.home;

  /// Bumped to force the visible tab to rebuild after the add sheet closes.
  /// Items watches a stream and does not need it; the other three read futures.
  int _generation = 0;

  /*
    ── The shell answers notification taps ─────────────────────────────────

    Here rather than on a tab, because a link can name a record on any of
    three of them and because this is the widget that outlives all of them.
    A tap that arrives while somebody is in Settings has to work as well as
    one that arrives on the dashboard.
  */
  bool _opening = false;

  /*
    ── Whether to draw PRO beside the wordmark ─────────────────────────────

    Read here rather than watched, because there is no settings stream and
    adding one for a single boolean would be a lot of machinery for a badge.

    Re-read on every tab change, which is sufficient and not a shortcut: the
    only way to become Pro is the unlock sheet, the only way to that sheet is
    the Settings tab, and the only way to see this masthead is to leave
    Settings. Buying it and arriving here is a tab change by definition.
  */
  bool _pro = false;

  Future<void> _readPro() async {
    final settings = await widget.repo.settings();
    if (!mounted) return;
    final now = settings.entitlements.proUnlock;
    if (now != _pro) setState(() => _pro = now);
  }

  /*
    ── The tour finally has a trigger ──────────────────────────────────────

    `tourDue`, `remindLater` and `TourState` were written and tested and never
    called. `showTour` was reachable from one place — the "Take the tour" row
    in Settings — which is the only route somebody who already knows about the
    tour would take. On a fresh install the app opened onto an empty dashboard
    and explained nothing.

    Here rather than in `main`, because showing a sheet needs a Navigator and a
    context that outlives it, and this is the widget that has both.

    Delayed past `splashTotal` because the splash is drawn OVER this — Shell is
    built at t=0 and sits underneath it. A sheet opened at t=0 would slide up
    behind a full-screen title card and be half over by the time anybody saw
    it. The extra 240ms is so it starts after the fade finishes rather than
    during it.
  */
  /*
    Held and cancelled, not awaited.

    This was `await Future.delayed(...)`, and a bare delay is a timer nobody
    owns: it keeps running after the widget is gone, and `if (!mounted)`
    afterwards guards the WORK without ever guarding the TIMER. Flutter's test
    binding says so out loud — "A Timer is still pending even after the widget
    tree was disposed" — on any test that finishes inside the delay, which was
    ten of them.

    In the app the same leak is quieter and still real: every rebuild of the
    shell that disposed early would leave a timer holding a reference to a
    dead State until it fired.
  */
  Timer? _tourAt;

  Future<void> _maybeTour() async {
    if (!mounted) return;

    final settings = await widget.repo.settings();
    if (!mounted) return;

    final due = tourOnLaunch(TourState(
      doneAt: settings.onboardedAt,
      remindAt: settings.tourRemindAt,
    ));
    if (!due) return;

    // Not dismissible on the way in: a first-launch tour that vanishes on a
    // stray tap outside it, before anything is recorded, is one nobody sees
    // again and nobody chose to skip.
    await showTour(context, repo: widget.repo, dismissible: false);
  }

  @override
  void initState() {
    super.initState();
    pendingLink.addListener(_handleLink);
    _readPro();
    _tourAt = Timer(splashTotal + const Duration(milliseconds: 240), _maybeTour);

    /*
      And one read straight away, for the tap that WAS the launch.

      The two paths cover different races and both are needed. `init` runs off
      the first frame rather than before it — the time zone lookup and the
      plugin handshake are not worth delaying the splash for — so a link can
      be set either side of this widget existing:

        Set BEFORE the listener was attached, and a ValueNotifier does not
        replay. Only this post-frame read finds it.

        Set AFTER, which is the likelier order. Only the listener finds it.

      Neither alone is enough, and which one fires is a matter of how long the
      platform took to answer — that is, not something to design around.
    */
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleLink());
  }

  @override
  void dispose() {
    _tourAt?.cancel();
    pendingLink.removeListener(_handleLink);
    super.dispose();
  }

  Future<void> _handleLink() async {
    final link = pendingLink.value;
    if (link == null || _opening || !mounted) return;

    /*
      Cleared before the trip rather than after.

      Opening a record is an await, and a second tap arriving mid-flight
      would otherwise queue a second screen on top of the first. The guard
      and the clear together mean one tap opens one thing, and a link that
      fails to resolve — a record deleted since the reminder was scheduled —
      is dropped rather than retried for ever.
    */
    pendingLink.value = null;
    _opening = true;

    try {
      final repo = widget.repo;

      switch (link.kind) {
        case LinkKind.home:
          setState(() => _tab = Tab.home);

        case LinkKind.item:
          final item = await repo.item(link.id!);
          if (!mounted) return;
          // Deleted since the reminder was scheduled. Sixty days is plenty of
          // time for that, so it is a normal outcome rather than an error —
          // the dashboard is the honest place to land.
          if (item == null) {
            setState(() => _tab = Tab.home);
            return;
          }
          setState(() => _tab = Tab.items);
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ItemDetailScreen(repo: repo, item: item),
            ),
          );

        case LinkKind.paper:
          final paper = await repo.paper(link.id!);
          if (!mounted) return;
          setState(() => _tab = Tab.papers);
          if (paper == null) return;
          await showPaperForm(context, repo: repo, existing: paper);

        case LinkKind.sub:
          final sub = await repo.subscription(link.id!);
          if (!mounted) return;
          setState(() => _tab = Tab.subs);
          if (sub == null) return;
          await showSubForm(context, repo: repo, existing: sub);
      }
    } finally {
      _opening = false;
      // Something may have arrived while that one was open.
      if (mounted && pendingLink.value != null) unawaited(_handleLink());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    /*
      ── The add button sits OVER the whole app, title bar and nav included ──

      It has been moved twice. As a `floatingActionButton` it lived in the
      Scaffold's own slot, sized to itself, so its scrim could dim the eighty
      pixels it occupied and nothing else. Moved into the body it could dim the
      screen but not the heading above it or the tab bar below — and a menu
      that leaves two strips of the app fully lit is a menu that has not taken
      over, which is the one thing it needs to look like.

      So it stacks on top of the entire Scaffold. Everything is behind the
      scrim because everything is behind it.
    */
    return Stack(
      children: [
        _scaffold(context, c),

        /*
          ── Not on Settings ────────────────────────────────────────────────

          There is nothing on that screen to add one of. Every other tab is a
          list the button puts things into; Settings is the one place where a
          floating "Stash it" answers no question, and it sits over the version
          card and the share button while doing it.
        */
        if (_tab != Tab.settings)
          Positioned.fill(
            child: StashItButton(
              repo: widget.repo,
              onDone: () => setState(() => _generation++),
            ),
          ),
      ],
    );
  }

  Widget _scaffold(BuildContext context, StashColors c) {
    return Scaffold(
      body: SafeArea(
        /*
          ── The swipe, which `logic/swipe.dart` has always known how to do ───

          `nextTab` and the direction rules were ported in phase 1, tested, and
          then never called — the sixth green-test-no-caller in this port. The
          gesture is what makes a five-tab app feel like a phone app rather
          than a website with a tab bar.

          `onHorizontalDragEnd` rather than tracking the drag: the velocity is
          the whole signal, and a partial drag with a live preview is a much
          bigger piece of work for something people do without looking.
        */
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final vx = details.primaryVelocity ?? 0;

            // Below this it was a scroll that wandered, not a swipe. The web
            // version fought the browser for the same reason `touch-action:
            // pan-y` is set there.
            if (vx.abs() < 220) return;

            final to = nextTab(_tab, vx < 0 ? Direction.left : Direction.right);
            if (to == null) return;
            _select(to);
          },
          child: Column(
            children: [
              // The heading belongs to the shell, not to each screen: it has to
              // be in the same place, at the same size, after every swipe, and
              // five screens each drawing their own is five chances for one to
              // drift. Home takes the wordmark — see `Wordmark`.
              if (_tab == Tab.home)
                Padding(
                  // The same 2 and 4 as `TabTitle`, so the wordmark and every
                  // screen's name sit on exactly the same line. They are the
                  // same object doing the same job, and a four-pixel drift
                  // between tabs is visible the moment you swipe.
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      // Baseline would be the instinct and is wrong here: the
                      // badge has no baseline worth aligning to, only a box.
                      // Centring the box against the wordmark's line is what
                      // makes it sit level rather than hang.
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Wordmark(),
                        if (_pro) ...[
                          const SizedBox(width: 9),
                          const ProBadge(),
                        ],
                      ],
                    ),
                  ),
                )
              else
                TabTitle(
                  switch (_tab) {
                    Tab.items => 'Items',
                    Tab.subs => 'Subscriptions',
                    Tab.papers => 'Documents',
                    Tab.settings => 'Settings',
                    Tab.home => '',
                  },
                  /*
                    None. Every screen stands Scout beside its own content, at a
                    size worth looking at — Settings included, now.

                    He was in this heading for Settings alone, and a pose here
                    forces the row to align on its bottom edge, which pushed
                    that one title a few pixels off the line every other tab
                    sits on. A heading that moves between tabs is the one thing
                    this widget exists to prevent.
                  */
                  pose: null,
                  /*
                    ── The album moved off this title ──────────────────────────

                    Ten taps on the word "Settings" used to open Scout's album.
                    It was well hidden and badly signposted: a heading is the
                    one thing on a screen nobody suspects of doing anything, so
                    in practice the only people who found it were told.

                    It lives on Scout himself now, over in the Settings tab —
                    see `_pokeScout`. Poking the animal is a thing people
                    already do.
                  */
                ),

              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: KeyedSubtree(
                        key: ValueKey('${_tab.name}-$_generation'),
                        child: switch (_tab) {
                          Tab.home => HomeTab(repo: widget.repo, onGo: _select),
                          Tab.items => ItemsTab(repo: widget.repo),
                          Tab.subs => SubsTab(repo: widget.repo),
                          Tab.papers => PapersTab(repo: widget.repo),
                          Tab.settings => SettingsTab(repo: widget.repo),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: NavigationBar(
        height: 74,
        backgroundColor: c.slate800,
        selectedIndex: _tab.index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => _select(Tab.values[i]),
        destinations: [
          for (final tab in Tab.values)
            NavigationDestination(
              icon: NavIcon(tab, color: c.muted),
              selectedIcon: NavIcon(tab, color: c.gold),
              label: switch (tab) {
                Tab.home => 'Home',
                Tab.items => 'Items',
                Tab.subs => 'Subs',
                Tab.papers => 'Documents',
                Tab.settings => 'Settings',
              },
            ),
        ],
      ),
    );
  }

  /*
    Tapping a figure on the dashboard goes somewhere.

    `destinationFor` decides where, and it exists because of a real bug: every
    chip under the ring opened the Items list, and both of its counts span
    items and documents. A house whose "action needed" was two passports
    tapped an accurate number and landed on an empty items screen — the count
    was right, the destination was wrong, and the app looked as though it had
    mislaid them.
  */
  void _select(Tab to) {
    if (to == _tab) return;
    // A lower, rounder note than an ordinary tap: moving between tabs is a
    // bigger gesture, and pitch carries that better than volume does.
    feedback(Cue.nav);
    setState(() => _tab = to);

    // Cheap, and it is what makes the badge appear the moment somebody comes
    // back from buying. Leaving Settings is the only route to seeing it.
    _readPro();
  }
}
