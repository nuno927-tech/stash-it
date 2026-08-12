/**
 * Which sound a click makes.
 *
 *   npm run test:feedback
 *
 * The cue rules are pure so they can be checked without a DOM or an audio
 * context. What matters is that navigation, ordinary buttons and disclosures
 * stay distinguishable, and that a control which plays its own sound can opt
 * out rather than doubling up.
 */

import { buzzFor, pickCue, type Cue } from '@/lib/feedback';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

/* ------------------------------------------------------------- defaults */

check('an ordinary button taps', pickCue({}) === 'tap');
check('a nav button is different', pickCue({ isNav: true }) === 'nav');
check(
  'nav and tap are not the same cue',
  pickCue({ isNav: true }) !== pickCue({}),
  `${pickCue({ isNav: true })} vs ${pickCue({})}`,
);

/* ---------------------------------------------------------- disclosures */

check('a closed disclosure opens', pickCue({ isDisclosure: true, expanded: false }) === 'expand');
check('an open one closes', pickCue({ isDisclosure: true, expanded: true }) === 'collapse');
check(
  'expand and collapse differ',
  pickCue({ isDisclosure: true, expanded: false }) !== pickCue({ isDisclosure: true, expanded: true }),
);
check(
  'a disclosure inside the nav is still navigation',
  pickCue({ isNav: true, isDisclosure: true }) === 'nav',
);

/* ------------------------------------------------------------ overrides */

check('an explicit cue wins', pickCue({ override: 'save', isNav: true }) === 'save');
check('none means silence', pickCue({ override: 'none' }) === null);
check('an unknown override falls back to tap', pickCue({ override: 'nonsense' }) === 'tap');
check('an empty override is ignored', pickCue({ override: '' }) === 'tap');
check('a null override is ignored', pickCue({ override: null, isNav: true }) === 'nav');

/* ------------------------------------------------------------ coverage */

const everyCue = new Set([
  pickCue({}),
  pickCue({ isNav: true }),
  pickCue({ isDisclosure: true, expanded: false }),
  pickCue({ isDisclosure: true, expanded: true }),
]);
check('four distinct sounds across the four cases', everyCue.size === 4, [...everyCue].join(', '));

/* --------------------------------------------------------------- haptics */

const ALL: Cue[] = ['tap', 'nav', 'expand', 'collapse', 'save', 'attach', 'delete', 'error', 'launch'];
const ms = (c: Cue) => {
  const b = buzzFor(c);
  return Array.isArray(b) ? b.filter((_, i) => i % 2 === 0).reduce((a, n) => a + n, 0) : b;
};

for (const cue of ALL) {
  check(`${cue} buzzes`, ms(cue) > 0, `${ms(cue)}ms`);
}

// A per-tap buzz has to stay in tick territory. Past roughly 10ms it stops
// reading as texture and starts reading as a notification.
for (const cue of ['tap', 'nav', 'expand', 'collapse'] as Cue[]) {
  check(`${cue} is a tick, not a jolt`, ms(cue) <= 10, `${ms(cue)}ms`);
}

check('a tap is the lightest of all', ms('tap') === Math.min(...ALL.map(ms)), `${ms('tap')}ms`);
check('navigation is firmer than a tap', ms('nav') > ms('tap'));
check('deleting is firmer than navigating', ms('delete') > ms('nav'));
check('an error is the most insistent', ms('error') === Math.max(...ALL.map(ms)), `${ms('error')}ms`);

/* ---------------------------------------------------------------- launch */

// Fires unprompted, once, as the app appears — so it has to be lighter than
// anything the user asked for. A jolt on open would feel like an alarm.
check('opening is a tick, not a jolt', ms('launch') <= 10, `${ms('launch')}ms`);
check('and lighter than a save', ms('launch') < ms('save'));

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
