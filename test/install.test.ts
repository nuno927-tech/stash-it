/**
 * When to offer the install prompt.
 *
 *   npm run test:install
 *
 * The combinations matter more than they look. Get one wrong and you either
 * nag someone who already installed, or hide the option from the one platform
 * where it can't be discovered any other way.
 */

import { installOffer, installOfferIgnoringDismissal, type InstallState } from '@/lib/install';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const state = (over: Partial<InstallState> = {}): InstallState => ({
  standalone: false,
  dismissed: false,
  nativePrompt: false,
  iosSafari: false,
  ...over,
});

/* --------------------------------------------------------- the happy paths */

check('Chromium with a captured event offers the button', installOffer(state({ nativePrompt: true })) === 'native');
check('iOS Safari gets instructions instead', installOffer(state({ iosSafari: true })) === 'ios');

/* ------------------------------------------------------------ suppression */

check(
  'an installed app is never nagged',
  installOffer(state({ standalone: true, nativePrompt: true })) === 'none',
);
check(
  'not even on iOS',
  installOffer(state({ standalone: true, iosSafari: true })) === 'none',
);
check('a dismissal is respected', installOffer(state({ nativePrompt: true, dismissed: true })) === 'none');
check('on iOS too', installOffer(state({ iosSafari: true, dismissed: true })) === 'none');

check(
  'installed beats dismissed — both mean silence',
  installOffer(state({ standalone: true, dismissed: true, nativePrompt: true })) === 'none',
);

/* --------------------------------------------------- nothing worth offering */

check('a desktop browser with no event says nothing', installOffer(state()) === 'none');
check(
  'nor a non-Safari iOS browser, which cannot install at all',
  installOffer(state({ iosSafari: false })) === 'none',
);

/* ------------------------------------------------------------ the native win */

check(
  'a real prompt beats instructions when somehow both apply',
  installOffer(state({ nativePrompt: true, iosSafari: true })) === 'native',
);

/* -------------------------------------------------------------- settings */

// Settings keeps the option visible after a dismissal — someone who tapped
// "Not now" and changed their mind shouldn't have to clear site data.
check(
  'settings ignores the dismissal',
  installOfferIgnoringDismissal(state({ nativePrompt: true, dismissed: true })) === 'native',
);
check(
  'settings still hides it once installed',
  installOfferIgnoringDismissal(state({ standalone: true, dismissed: true })) === 'none',
);
check(
  'and still says nothing when there is nothing to say',
  installOfferIgnoringDismissal(state({ dismissed: true })) === 'none',
);

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
