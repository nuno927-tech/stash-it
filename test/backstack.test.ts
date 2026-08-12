/**
 * The Back gesture.
 *
 *   npm run test:backstack
 *
 * The bug this exists to prevent: back on an item detail closing the whole
 * app. The fix is bookkeeping — one history entry per open thing — and
 * bookkeeping is exactly the sort of thing that drifts by one and then behaves
 * strangely in a way nobody can reproduce. So the invariant under test is that
 * the depth of our stack always matches the number of entries we've taken.
 */

import { backDepth, clearBack, pushBack } from '@/lib/backstack';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

/**
 * Enough of History and window to exercise the module: entries are counted,
 * back() and go() fire popstate the way a browser would.
 */
function fakeBrowser() {
  let entries = 1; // the page load itself
  const listeners: (() => void)[] = [];

  const win = {
    addEventListener: (type: string, fn: () => void) => {
      if (type === 'popstate') listeners.push(fn);
    },
    removeEventListener: () => {},
  };

  const hist = {
    pushState: () => {
      entries++;
    },
    back: () => hist.go(-1),
    go: (n: number) => {
      const steps = Math.min(-n, entries - 1);
      for (let i = 0; i < steps; i++) {
        entries--;
        for (const fn of [...listeners]) fn();
      }
    },
  };

  (globalThis as Record<string, unknown>).window = win;
  (globalThis as Record<string, unknown>).history = hist;

  return { depth: () => entries - 1, hist };
}

function main() {
  const browser = fakeBrowser();

  /* ------------------------------------------------------- one open thing */

  let closed = 0;
  const releaseDetail = pushBack(() => closed++);
  check('an entry is taken', browser.depth() === 1, String(browser.depth()));
  check('and tracked', backDepth() === 1);

  // The gesture: the browser pops, we close the screen.
  browser.hist.back();
  check('back closes the screen', closed === 1);
  check('and the entry is gone', backDepth() === 0);
  check('with history back where it started', browser.depth() === 0, String(browser.depth()));

  // Releasing something the gesture already closed must do nothing at all.
  // Otherwise it eats a second entry and the *next* back press exits the app.
  releaseDetail();
  check('releasing an already-closed screen is a no-op', browser.depth() === 0);
  check('and does not go negative', backDepth() === 0);

  /* ----------------------------------------------------- closed by button */

  let closedByGesture = 0;
  const release = pushBack(() => closedByGesture++);
  check('a second entry is taken', browser.depth() === 1);

  release();
  check('closing by button gives the entry back', browser.depth() === 0, String(browser.depth()));
  check('without invoking the back handler', closedByGesture === 0);
  check('and the stack is empty', backDepth() === 0);

  /* ---------------------------------------------------------------- nested */

  const order: string[] = [];
  pushBack(() => order.push('detail'));
  pushBack(() => order.push('photo'));
  check('two entries for two things', browser.depth() === 2 && backDepth() === 2);

  // A photo open over an item detail: back closes the photo, not the item,
  // and certainly not both at once.
  browser.hist.back();
  check('the topmost closes first', order.join() === 'photo', order.join());
  check('the one underneath survives', backDepth() === 1);

  browser.hist.back();
  check('then the one underneath', order.join() === 'photo,detail');
  check('and nothing is left', backDepth() === 0 && browser.depth() === 0);

  /* ----------------------------------------------------------- the jump */

  const jumped: string[] = [];
  pushBack(() => jumped.push('a'));
  pushBack(() => jumped.push('b'));
  pushBack(() => jumped.push('c'));
  check('three deep', backDepth() === 3 && browser.depth() === 3);

  // Tapping a tab: everything open is now closed, in one move.
  clearBack();
  check('clearing drops every entry', backDepth() === 0, String(backDepth()));
  check('and every history entry with it', browser.depth() === 0, String(browser.depth()));
  check('without running any handler', jumped.length === 0, jumped.join());

  check('clearing an empty stack is safe', (clearBack(), backDepth() === 0));

  /* ------------------------------------------------- past the last entry */

  // Nothing of ours is open, so back belongs to the browser: this is the one
  // case where leaving the app is the right answer.
  let stray = 0;
  pushBack(() => stray++);
  browser.hist.back();
  browser.hist.back();
  check('an extra back does not fire a stale handler', stray === 1, String(stray));

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
