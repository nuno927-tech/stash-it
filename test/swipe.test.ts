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
const g = (over: Partial<Gesture> = {}): Gesture => ({
  dx: 0,
  dy: 0,
  elapsed: 400,
  width: W,
  ...over,
});

function main() {
  /* ---------------------------------------------------------- the order */

  check('three tabs, in bar order', TAB_ORDER.join() === 'home,items,settings');
  check('swiping left goes forward', nextTab('home', 'left') === 'items');
  check('and again', nextTab('items', 'left') === 'settings');
  check('swiping right goes back', nextTab('settings', 'right') === 'items');

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
