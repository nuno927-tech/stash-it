/**
 * Unlocking the developer card.
 *
 *   npm run test:dev
 *
 * Two things have to hold: ten deliberate taps get you in, and a slow drip of
 * taps across a week never does. The second is the one that matters — if the
 * counter accumulated across sessions the card would eventually appear on its
 * own, which is exactly what hiding it was meant to prevent.
 */

// readUnlocked/rememberUnlocked touch sessionStorage, which Node has not got.
// A two-line stand-in is enough to assert the round trip and, more usefully,
// that a browser which throws on storage access reports "locked" rather than
// taking the whole settings screen down with it.
const store = new Map<string, string>();
let throws = false;
(globalThis as { sessionStorage?: unknown }).sessionStorage = {
  getItem: (k: string) => {
    if (throws) throw new Error('denied');
    return store.get(k) ?? null;
  },
  setItem: (k: string, v: string) => {
    if (throws) throw new Error('denied');
    store.set(k, v);
  },
  removeItem: (k: string) => {
    if (throws) throw new Error('denied');
    store.delete(k);
  },
};

import {
  NO_TAPS,
  readUnlocked,
  rememberUnlocked,
  tap,
  tapHint,
  tapsLeft,
  TAP_GAP_MS,
  TAPS_TO_UNLOCK,
  unlocked,
  type TapState,
} from '@/lib/devmode';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

/** Taps 300ms apart, which is about as fast as a thumb goes. */
function run(n: number, from: TapState = NO_TAPS, start = 1_000): TapState {
  let s = from;
  for (let i = 0; i < n; i++) s = tap(s, start + i * 300);
  return s;
}

function main() {
  check('a fresh state is locked', !unlocked(NO_TAPS));
  check('and asks for ten', tapsLeft(NO_TAPS) === TAPS_TO_UNLOCK);

  check('nine taps is not enough', !unlocked(run(9)));
  check('the tenth opens it', unlocked(run(10)));
  check('and so does the eleventh', unlocked(run(11)));

  /* ------------------------------------------------------------- the gap */

  // A pause means a different intention. Without this the counter would carry
  // over from yesterday's visit to the settings screen.
  const paused = tap(run(9), 1_000 + 8 * 300 + TAP_GAP_MS + 1);
  check('a pause restarts the run', paused.count === 1);
  check('and a restarted run is locked', !unlocked(paused));
  check(
    'nine more after the pause still is not enough',
    !unlocked(run(8, paused, paused.last + 300)),
  );
  check('ten from the pause opens it', unlocked(run(9, paused, paused.last + 300)));

  // Exactly at the gap is still one run: the boundary should not punish a
  // steady, unhurried tapper.
  const atTheEdge = tap({ count: 4, last: 1_000 }, 1_000 + TAP_GAP_MS);
  check('a tap exactly on the gap continues the run', atTheEdge.count === 5);

  /* ------------------------------------------------------------- the hint */

  check('nothing is said early on', tapHint(run(3)) === null);
  check('nor at six', tapHint(run(6)) === null);
  check('three left is announced', tapHint(run(7)) === '3 more taps');
  check('and counts down', tapHint(run(8)) === '2 more taps');
  check('the last one is singular', tapHint(run(9)) === '1 more tap');
  check('and it goes quiet once open', tapHint(run(10)) === null);

  /* --------------------------------------------------- staying unlocked */

  /*
    The card used to close every time you left Settings, which is the one
    moment a notification test requires — you have to leave to see whether the
    thing arrived. Ten more taps to get back in is how a test bench stops being
    used.
  */
  check('closed to begin with', !readUnlocked());
  rememberUnlocked(true);
  check('and open once remembered', readUnlocked());
  rememberUnlocked(false);
  check('Hide closes it again', !readUnlocked());

  // A browser that refuses storage must report locked, not throw. Nothing
  // behind the card is worth taking the settings screen down for.
  rememberUnlocked(true);
  throws = true;
  check('storage that throws reads as locked', readUnlocked() === false);
  let survived = true;
  try {
    rememberUnlocked(false);
  } catch {
    survived = false;
  }
  check('and writing to it does not throw', survived);
  throws = false;

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
