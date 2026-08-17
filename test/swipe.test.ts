/**
 * Swiping: between tabs, and throwing a card off the screen.
 *
 *   npm run test:swipe
 *
 * All thresholds, and thresholds are where a gesture stops feeling like one.
 * The two failures that matter are opposites: too eager and a list can't be
 * scrolled without changing tabs, too strict and the swipe seems broken. Both
 * are decided here, so both are pinned here.
 */

import {
  BACK_DIRECTION,
  dismissedByDrag,
  OWNS_SWIPE,
  ownsItsSwipe,
  ROW_OPEN_AT,
  ROW_REVEAL,
  rowOffset,
  rowOpens,
  DISMISS_FLICK_PIXELS,
  DISMISS_PIXELS,
  DOMINANCE,
  FLICK_PIXELS,
  MIN_PIXELS,
  nextTab,
  startedAtEdge,
  swipeVerdict,
  TAB_ORDER,
  type Gesture,
} from '@/lib/swipe';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const W = 390; // a common phone width

/*
  Enough of an element tree for ownsItsSwipe, which only ever asks two things:
  does this carry the attribute, and what is its parent. Building it by hand
  keeps this file free of a DOM implementation for one function.
*/
type Node = { hasAttribute: (n: string) => boolean; parentElement: Node | null };
const fakeRoot = (): Node => ({ hasAttribute: () => false, parentElement: null });
const fakeNode = (owns: boolean): Node => {
  const root = fakeRoot();
  const row = { hasAttribute: (n: string) => owns && n === OWNS_SWIPE, parentElement: root };
  return { hasAttribute: () => false, parentElement: row };
};
const g = (over: Partial<Gesture> = {}): Gesture => ({
  dx: 0,
  dy: 0,
  elapsed: 400,
  width: W,
  ...over,
});

function main() {
  /* ---------------------------------------------------------- the order */

  /*
    Every tab in the bar, in the bar's order. Subscriptions was added to the
    bar and not to this list, so swiping left from Items skipped straight to
    Settings — past a tab that was right there on screen.
  */
  check('four tabs, in bar order', TAB_ORDER.join() === 'home,items,subs,settings');
  check('swiping left goes forward', nextTab('home', 'left') === 'items');
  check('and again', nextTab('items', 'left') === 'subs');
  check('and again', nextTab('subs', 'left') === 'settings');
  check('swiping right goes back', nextTab('settings', 'right') === 'subs');

  // No wrapping. Settings → left → Home would answer "next" by jumping to the
  // far end of the app, and the bottom bar already shows there is no next.
  check('nothing past the last tab', nextTab('settings', 'left') === null);
  check('nothing before the first', nextTab('home', 'right') === null);

  /* -------------------------------------------------------- the verdict */

  // A deliberate drag: a fifth of the screen.
  check('a long drag left', swipeVerdict(g({ dx: -120 })) === 'left');
  check('a long drag right', swipeVerdict(g({ dx: 120 })) === 'right');
  check('half a screen still counts', swipeVerdict(g({ dx: -195 })) === 'left');

  // A flick: short and fast, and demanding full distance from it is what
  // makes a gesture feel heavy.
  check('a fast flick counts', swipeVerdict(g({ dx: -50, elapsed: 120 })) === 'left');
  check(
    'the same distance taken slowly does not',
    swipeVerdict(g({ dx: -50, elapsed: 900 })) === null,
  );

  /* ------------------------------------------------- what must not fire */

  // The common accident: a slightly diagonal thumb while reading a list.
  check('a vertical scroll is not a swipe', swipeVerdict(g({ dx: -30, dy: -200 })) === null);
  check(
    'nor a mostly-vertical diagonal',
    swipeVerdict(g({ dx: -90, dy: -140 })) === null,
    'dominance',
  );
  check(
    'a clearly horizontal diagonal does fire',
    swipeVerdict(g({ dx: -140, dy: -40 })) === 'left',
  );

  // Right at the dominance boundary, from both sides.
  const dy = 60;
  check('just under dominance is refused', swipeVerdict(g({ dx: -(dy * DOMINANCE - 1), dy })) === null);
  check(
    'just over it is allowed, given the distance',
    swipeVerdict(g({ dx: -140, dy: 140 / DOMINANCE - 1 })) === 'left',
  );

  check('a tap is not a swipe', swipeVerdict(g({ dx: 0, dy: 0, elapsed: 90 })) === null);
  check('a twitch is not a swipe', swipeVerdict(g({ dx: -12, elapsed: 100 })) === null);

  /* ------------------------------------------------- what a thumb does */

  // A real swipe is an arc, not a straight line — the thumb pivots. These are
  // the shapes that were being rejected while feeling, to the user, like
  // perfectly ordinary swipes.
  check('an arcing swipe counts', swipeVerdict(g({ dx: -110, dy: 62, elapsed: 260 })) === 'left');
  check(
    'a modest, unhurried swipe counts',
    swipeVerdict(g({ dx: -66, dy: 18, elapsed: 700 })) === 'left',
    'a fifth of the screen was too much to ask',
  );
  check(
    'a swipe that drifts up counts too',
    swipeVerdict(g({ dx: 95, dy: -50, elapsed: 300 })) === 'right',
  );

  /* ------------------------------------------------------ narrow screens */

  // The threshold scales, so a small phone doesn't demand a heroic drag and a
  // tablet doesn't fire on a nudge.
  check('a short screen needs less', swipeVerdict(g({ dx: -70, width: 320, elapsed: 800 })) === 'left');
  check(
    'a wide screen needs more',
    swipeVerdict(g({ dx: -70, width: 1024, elapsed: 800 })) === null,
  );

  /* ----------------------------------------------------------- the edges */

  // Android's back gesture owns the edges. One gesture must not do two things.
  check('the left edge belongs to the system', startedAtEdge(8, W));
  check('so does the right', startedAtEdge(W - 8, W));
  check('the middle is ours', !startedAtEdge(W / 2, W));
  check('and just inside the guard', !startedAtEdge(40, W));

  /* ------------------------------------------------------- stepping back */

  /*
    A pushed screen — an item, the rooms list, the bin — reads a horizontal
    swipe as "up one level". Getting the sign backwards would send people
    deeper, or nowhere, so the direction is named in one place and checked
    against the verdict that produces it.
  */
  check('back is to the right', BACK_DIRECTION === 'right');
  check(
    'and a rightward drag produces it',
    swipeVerdict(g({ dx: 120 })) === BACK_DIRECTION,
  );
  check('dragging the other way is not back', swipeVerdict(g({ dx: -120 })) !== BACK_DIRECTION);

  // Our gesture and Android's system back must not both fire. The edge belongs
  // to the system, and useSwipeNav refuses to start there — which is what
  // makes it safe to put a back swipe on the same screens.
  check('a swipe from the edge is never ours', startedAtEdge(10, W) && startedAtEdge(W - 10, W));

  /* ------------------------------------------------ pushing a row aside */

  /*
    Left only, and never mistakable for a scroll. The row slides to reveal a
    delete button — it does not delete — because a horizontal drag is the
    easiest gesture in the app to make by accident while thumbing down a list.
  */
  check('a decisive left drag opens it', rowOpens(-60, 4));
  check('a small one does not', !rowOpens(-12, 0));
  check('rightwards never opens it', !rowOpens(60, 0));
  check('a diagonal scroll does not', !rowOpens(-40, 90));
  check('right at the threshold', !rowOpens(-ROW_OPEN_AT, 0) && rowOpens(-ROW_OPEN_AT - 1, 0));

  // Opening is cheaper to undo than changing tabs, so it asks for less.
  check('it takes less than a tab swipe', ROW_OPEN_AT < MIN_PIXELS, `${ROW_OPEN_AT} vs ${MIN_PIXELS}`);

  /*
    The row and the shell were both reading the same drag: the row slid open
    and the app changed tab underneath it. A row marked as owning its swipe is
    skipped by the tab gesture entirely.
  */
  check(
    'a row that owns its swipe is left alone',
    ownsItsSwipe(fakeNode(true), fakeRoot()) && !ownsItsSwipe(fakeNode(false), fakeRoot()),
  );

  check('the row never travels past the button', rowOffset(-400, false) === -ROW_REVEAL);
  check('nor right of where it started', rowOffset(200, false) === 0);
  check('mid-drag it tracks the finger', rowOffset(-40, false) === -40);
  check('an open row drags from where it is', rowOffset(0, true) === -ROW_REVEAL);
  check('and can be pushed back shut', rowOffset(ROW_REVEAL, true) === 0);

  /* ------------------------------------------------ throwing a card away */

  /*
    The paper reminder after every save. Deliberately looser than the tab
    swipe, and the asymmetry is the argument: changing tabs by accident loses
    your place, closing a reminder by accident costs nothing at all.
  */
  const d = (dy: number, elapsed = 500) => dismissedByDrag({ dy, elapsed });

  check('a firm drag down closes it', d(DISMISS_PIXELS));
  check('and so does one up — the card is centred, not anchored', d(-DISMISS_PIXELS));
  check('a nudge does not', !d(12));
  check('nor does a slow short drag', !d(DISMISS_FLICK_PIXELS + 2, 900));
  check('but a flick that short does', d(DISMISS_FLICK_PIXELS + 2, 200));
  check('a flick upward too', d(-(DISMISS_FLICK_PIXELS + 2), 200));
  check('a tap is not a throw', !d(0, 90));

  // Looser than the tab gesture, checked rather than asserted in a comment:
  // the day someone tunes one of these, the relationship should hold.
  check(
    'it takes less than changing tabs',
    DISMISS_PIXELS < MIN_PIXELS && DISMISS_FLICK_PIXELS < FLICK_PIXELS,
    `${DISMISS_PIXELS} vs ${MIN_PIXELS}, ${DISMISS_FLICK_PIXELS} vs ${FLICK_PIXELS}`,
  );

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
