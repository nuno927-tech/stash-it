/**
 * Sharing the app.
 *
 *   npm run test:share
 *
 * The fallback chain is the whole feature: share sheet, then clipboard, then
 * showing the address. A share button that silently does nothing on a browser
 * without the API is worse than no button at all.
 */

import { shareApp, shareMessage, SHARE_TEXT, type ShareDeps } from '@/lib/share';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

// The marketing page, which is what appUrl() resolves to — not the app.
const URL_ = 'https://nuno927-tech.github.io/stash-it/';

function abort(): Promise<never> {
  const e = new Error('cancelled');
  e.name = 'AbortError';
  return Promise.reject(e);
}

async function main() {
  /* ------------------------------------------------------- the happy path */

  /*
    Read through a function, not directly.

    TypeScript cannot see that an async callback ran, so it narrows `shared`
    back to `null` at every check below and each property read lands on
    `never`. A getter returns the declared type instead — which is also more
    honest about what is being asserted: the last thing the fake share saw.
  */
  let shared: { title: string; text: string; url: string } | null = null;
  const lastShared = () => shared;
  const withShare: ShareDeps = {
    share: async (d) => {
      shared = d;
    },
    copy: async () => {
      throw new Error('should not be reached');
    },
  };

  check('the share sheet is preferred', (await shareApp(URL_, withShare)) === 'shared');
  check('the URL is passed along', lastShared()?.url === URL_);
  check('so is a description', lastShared()?.text === SHARE_TEXT);
  check('and a title', lastShared()?.title === 'Stash it');

  /* ----------------------------------------------------- no share support */

  let copied = '';
  const copyOnly: ShareDeps = {
    copy: async (t) => {
      copied = t;
    },
  };
  check('falls back to the clipboard', (await shareApp(URL_, copyOnly)) === 'copied');
  check('and copies the address', copied === URL_, copied);

  /* --------------------------------------------------- the user backs out */

  // Dismissing the sheet must not silently copy a link they just declined to
  // send — the fallback is for missing capability, not for changed minds.
  let copiedAfterAbort = false;
  const cancelled: ShareDeps = {
    share: abort,
    copy: async () => {
      copiedAfterAbort = true;
    },
  };
  check('cancelling is reported as cancelled', (await shareApp(URL_, cancelled)) === 'cancelled');
  check('and does not fall through to copying', !copiedAfterAbort);

  /* ------------------------------------------------ a genuine share failure */

  const brokenShare: ShareDeps = {
    share: async () => {
      throw new Error('NotAllowedError');
    },
    copy: async (t) => {
      copied = t;
    },
  };
  check(
    'a real failure does fall through to copying',
    (await shareApp(URL_, brokenShare)) === 'copied',
  );

  /* ------------------------------------------------------ nothing available */

  check('with no capability at all it says so', (await shareApp(URL_, {})) === 'unavailable');
  check(
    'a clipboard that throws is also unavailable',
    (await shareApp(URL_, {
      copy: async () => {
        throw new Error('denied');
      },
    })) === 'unavailable',
  );

  /* -------------------------------------------------------------- messages */

  check('sharing is acknowledged', shareMessage('shared', URL_) !== null);
  check('copying says where it went', /clipboard/i.test(shareMessage('copied', URL_) ?? ''));
  check('cancelling says nothing at all', shareMessage('cancelled', URL_) === null);
  check(
    'and the last resort shows the address itself',
    (shareMessage('unavailable', URL_) ?? '').includes(URL_),
  );

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
