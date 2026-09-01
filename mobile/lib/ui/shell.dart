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
import '../io/incoming_card.dart';
import '../io/widget_mirror.dart';
import '../logic/bundle.dart';
import '../logic/item_filter.dart';
import '../logic/deep_link.dart';
import '../logic/swipe.dart';
import '../notify/pending_link.dart';
import 'add_button.dart';
import 'card_arrival_screen.dart';
import 'item_wizard_sheet.dart';
import 'item_view_sheet.dart';
import 'paper_form_sheet.dart';
import 'paper_view_sheet.dart';
import 'sub_form_sheet.dart';
import 'sub_view_sheet.dart';
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

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  Tab _tab = Tab.home;

  /*
    ── Which way the next tab comes from ───────────────────────────────────

    Tabs used to cut: the old one vanished and the new one was simply there,
    so a swipe and a tap on the bar looked identical and neither said which
    direction you had moved. A slide is not decoration here — it is the only
    thing that tells you the app has five screens in a row rather than five
    unrelated places.

    Derived from the enum's order, which is also the order the swipe walks and
    the order the bar draws. `Tab` is the single list — see the note at the
    top of this file — so "later in the enum" and "to the right" are the same
    statement.
  */
  bool _forward = true;

  /// The one door for changing tabs, so nothing can move without saying which
  /// way. Every `setState(() => _tab = ...)` used to be its own.
  void _goTo(Tab to, {ItemFilter? filter}) {
    if (to == _tab && filter == _itemsFilter) return;
    setState(() {
      _forward = to.index > _tab.index;
      _tab = to;
      _itemsFilter = filter;
    });
  }

  /*
    ── Which slice of the Items tab to open, held here ─────────────────────

    It used to be a `ValueNotifier` the dashboard wrote and the Items tab read
    once and cleared, which lost the instruction whenever the tab happened to
    be built twice — see the note at the top of items_tab.dart.

    "Which tab" already lives here. "Which tab, showing what" is the same fact,
    so it lives here too, and is handed down as an argument on every build.

    It is cleared by every navigation that does not set it, which is what makes
    reaching Items from the bottom bar give the plain list rather than whatever
    a dashboard figure last asked for.
  */
  ItemFilter? _itemsFilter;

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

    /*
      ── A .stashcard, tapped ────────────────────────────────────────────────

      Three arrival routes, because Android has three and none is reliable
      alone. The observer catches a resume; the post-frame read below catches
      the tap that WAS the launch; and `onCardArrived` catches a file opened
      while the app is already in front, which Android hands to the running
      activity without restarting anything.

      All three funnel into `_openCard`, which is guarded — see `_reading`.
    */
    WidgetsBinding.instance.addObserver(this);
    onWidgetOrCard(
      card: (path) => unawaited(_openCard(path)),
      add: (what) => unawaited(_openAdd(what)),
    );
    _tourAt =
        Timer(splashTotal + const Duration(milliseconds: 240), _maybeTour);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleLink();
      unawaited(_takeCard());
      unawaited(_takeAdd());
      unawaited(mirrorWidgets(widget.repo));
    });
  }

  /*
    ── Opening a card ────────────────────────────────────────────────────────

    Guarded the same way `_handleLink` is, and for the same reason: the three
    arrival routes overlap, so the same file can be offered twice within a
    frame or two. Without this, somebody would dismiss the arrival screen and
    find a second one behind it.
  */
  bool _reading = false;

  Future<void> _takeCard() async {
    final path = await takeIncomingCard();
    if (path == null || !mounted) return;
    await _openCard(path);
  }

  Future<void> _openCard(String path) async {
    if (_reading || !mounted) return;
    _reading = true;

    try {
      final card = await readCardAt(path);
      if (!mounted) return;

      final added =
          await showCardArrival(context, repo: widget.repo, card: card);

      if (added != null && added > 0 && mounted) {
        // Land where the things went. Arriving back on whatever tab happened
        // to be open, with a number in a snackbar, makes somebody hunt for
        // what they just accepted.
        _goTo(Tab.items);
        _say('Added $added ${added == 1 ? 'thing' : 'things'} to your stash.');
        // A card that arrived is data that changed, and the home screen has no
        // other way to hear about it.
        unawaited(mirrorWidgets(widget.repo));
      }
    } on BundleError catch (e) {
      // Including "that is a full backup, not a shared card".
      if (mounted) _say(e.message);
    } catch (e) {
      if (mounted) _say('That card could not be opened.');
    } finally {
      _reading = false;
    }
  }

  /*
    ── A row on the Quick add widget ─────────────────────────────────────────

    Guarded like `_openCard`, and for the same reason: launch and resume can
    both report the same tap, and two add sheets stacked on each other is a
    thing somebody has to dismiss twice.

    It moves to the matching tab before opening the sheet, so closing the form
    leaves them where the new thing landed rather than on whatever tab was
    open last.
  */
  bool _adding = false;

  Future<void> _takeAdd() async {
    final what = await takeWidgetAdd();
    if (what == null || !mounted) return;
    await _openAdd(what);
  }

  Future<void> _openAdd(String what) async {
    if (_adding || !mounted) return;
    _adding = true;

    try {
      switch (what) {
        case 'item':
          _goTo(Tab.items);
          if (mounted) await showItemWizard(context, repo: widget.repo);
        case 'paper':
          _goTo(Tab.papers);
          if (mounted) await showPaperForm(context, repo: widget.repo);
        case 'subscription':
          _goTo(Tab.subs);
          if (mounted) await showSubForm(context, repo: widget.repo);
      }
    } finally {
      _adding = false;
    }
  }

  /*
    Something was added, edited or thrown away.

    The list rebuild is what this was always for. The home screen redraw is new
    and rides along deliberately: this is the one callback the app already has
    that means "the data is different now", and a second mechanism for the same
    fact is a second one to forget to call.
  */
  void _changed() {
    if (!mounted) return;
    setState(() => _generation++);
    unawaited(mirrorWidgets(widget.repo));
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /*
    A card tapped while the app was in the background arrives with the resume
    rather than with a fresh launch, so there is nothing else that would think
    to ask.
  */
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_takeCard());
      unawaited(_takeAdd());

      /*
        And redraw the home screen, because a day may have passed.

        The counts a widget shows move at midnight whether the app was open or
        not, and nothing wakes it to notice. Resume is the first moment it can
        honestly know, which makes this the cheapest correction available: by
        the time somebody has gone back out to their home screen, the picture
        is right.
      */
      unawaited(mirrorWidgets(widget.repo));
    }
  }

  @override
  void dispose() {
    _tourAt?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
          _goTo(Tab.home);

        case LinkKind.item:
          final item = await repo.item(link.id!);
          if (!mounted) return;
          // Deleted since the reminder was scheduled. Sixty days is plenty of
          // time for that, so it is a normal outcome rather than an error —
          // the dashboard is the honest place to land.
          if (item == null) {
            _goTo(Tab.home);
            return;
          }
          _goTo(Tab.items);
          await showItemView(context, repo: repo, item: item);

        case LinkKind.paper:
          final paper = await repo.paper(link.id!);
          if (!mounted) return;
          _goTo(Tab.papers);
          if (paper == null) return;
          await showPaperView(context, repo: repo, paper: paper);

        case LinkKind.sub:
          final sub = await repo.subscription(link.id!);
          if (!mounted) return;
          _goTo(Tab.subs);
          if (sub == null) return;
          await showSubView(context, repo: repo, sub: sub);
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
              onDone: _changed,
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
                child: AnimatedSwitcher(
                  // Long enough to read as travel, short enough that somebody
                  // stepping through all five tabs is not waiting on it.
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,

                  /*
                    Both children are on screen together during the swap, one
                    arriving and one leaving. The default layout stacks them
                    centred and sizes to the largest, which makes a tall list
                    shove a short one about mid-transition; this pins both to
                    fill instead, so neither moves except along x.
                  */
                  layoutBuilder: (current, previous) => Stack(
                    children: [
                      for (final child in previous)
                        Positioned.fill(child: child),
                      if (current != null) Positioned.fill(child: current),
                    ],
                  ),

                  /*
                    Called for the arriving child AND the leaving one, so the
                    key is what tells them apart. The leaving child's animation
                    runs in reverse, which is why the same Tween sends it out
                    the opposite side rather than needing its own.
                  */
                  transitionBuilder: (child, animation) {
                    final arriving = (child.key as ValueKey<String>).value ==
                        '${_tab.name}-$_generation-${_itemsFilter?.name ?? ''}';
                    final from = _forward ? 1.0 : -1.0;

                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(arriving ? from : -from, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(
                        '${_tab.name}-$_generation-${_itemsFilter?.name ?? ''}'),
                    child: switch (_tab) {
                      Tab.home => HomeTab(repo: widget.repo, onGo: _select),
                      Tab.items => ItemsTab(
                          repo: widget.repo,
                          filter: _itemsFilter,
                          onGo: _select,
                        ),
                      Tab.subs => SubsTab(repo: widget.repo),
                      Tab.papers => PapersTab(repo: widget.repo),
                      Tab.settings => SettingsTab(repo: widget.repo),
                    },
                  ),
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
  void _select(Tab to, {ItemFilter? filter}) {
    if (to == _tab && filter == _itemsFilter) return;
    // A lower, rounder note than an ordinary tap: moving between tabs is a
    // bigger gesture, and pitch carries that better than volume does.
    feedback(Cue.nav);
    _goTo(to, filter: filter);

    // Cheap, and it is what makes the badge appear the moment somebody comes
    // back from buying. Leaving Settings is the only route to seeing it.
    _readPro();
  }
}
