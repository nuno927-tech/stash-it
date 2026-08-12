/**
 * When to offer the install prompt.
 *
 *   npm run test:install
 *
 * The combinations matter more than they look. Get one wrong and you either
 * nag someone who already installed, or hide the option from the one person
 * who needs it — which is exactly what happened, and is why there is no
 * "dismissed" input any more.
 */

import { installOffer, type InstallState } from '@/lib/install';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const state = (over: Partial<InstallState> = {}): InstallState => ({
  standalone: false,
  nativePrompt: false,
  iosSafari: false,
  android: false,
  settled: false,
  ...over,
});

/* --------------------------------------------------------- the happy paths */

check(
  'Chromium with a captured event offers the button',
  installOffer(state({ nativePrompt: true, android: true })) === 'native',
);
check('iOS Safari gets instructions instead', installOffer(state({ iosSafari: true })) === 'ios');

/* ------------------------------------------------------------ suppression */

// Installed is the only thing that ends the invitation, and it ends it for
// good — there's nothing left to offer.
check(
  'an installed app is never nagged',
  installOffer(state({ standalone: true, nativePrompt: true })) === 'none',
);
check(
  'not even on iOS',
  installOffer(state({ standalone: true, iosSafari: true })) === 'none',
);
check(
  'nor with the written steps',
  installOffer(state({ standalone: true, android: true, settled: true })) === 'none',
);

/* ------------------------------------------------- the event that never came */

// Chromium fires beforeinstallprompt when it likes and sometimes not at all —
// a fresh profile, a recent uninstall, an engagement heuristic. Before this,
// that combination showed nothing whatsoever, which is how someone ends up
// unable to install an app that keeps telling them to install it.
check(
  'while the browser might still fire, wait',
  installOffer(state({ android: true, settled: false })) === 'none',
);
check(
  'once it has had its chance, say where the menu is',
  installOffer(state({ android: true, settled: true })) === 'manual',
);
check(
  'a real button always beats written steps',
  installOffer(state({ android: true, settled: true, nativePrompt: true })) === 'native',
);

/* ------------------------------------------------------------- elsewhere */

// A desktop browser with no event and no platform we have instructions for.
check('nothing to say on an unknown platform', installOffer(state({ settled: true })) === 'none');
check(
  'and a Chrome-on-iOS user is not sent to a Safari menu',
  installOffer(state({ iosSafari: false, settled: true })) === 'none',
);

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
