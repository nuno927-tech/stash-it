/**
 * Swiping between tabs.
 *
 *   npm run test:swipe
 *
 * All thresholds, and thresholds are where a gesture stops feeling like one.
 * The two failures that matter are opposites: too eager and a list can't be
 * scrolled without changing tabs, too strict and the swipe seems broken. Both
 * are decided here, so both are pinned here.
 */

import {
  DOMINANCE,
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

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
