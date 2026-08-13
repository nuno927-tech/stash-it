/**
 * Writing to the developer.
 *
 *   npm run test:contact
 *
 * A mailto is a URL the user's mail client parses, and the failure mode is
 * quiet: a stray `&` or `#` in the subject truncates everything after it, and
 * the message arrives with half its body missing. Nobody notices until someone
 * sends one.
 */

import {
  contactBody,
  contactUrl,
  contextLine,
  DEVELOPER_EMAIL,
  platformWord,
  type ContactKind,
} from '@/lib/contact';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const CTX = { version: '1.2.3', standalone: true, platform: 'Android' };

function main() {
  /* --------------------------------------------------------- the address */

  check('the address is the developer', DEVELOPER_EMAIL === 'nuno927@gmail.com', DEVELOPER_EMAIL);
  check('every kind is addressed to it', contactUrl('question', CTX).startsWith(`mailto:${DEVELOPER_EMAIL}?`));

  /* ---------------------------------------------------------- the context */

  check(
    'the context names the build first',
    contextLine(CTX) === '— Stash it v1.2.3 · installed · Android',
    contextLine(CTX),
  );
  check(
    'a browser says so',
    contextLine({ ...CTX, standalone: false }).includes('in a browser'),
    contextLine({ ...CTX, standalone: false }),
  );
  check(
    'an unknown platform is left out rather than guessed',
    contextLine({ version: '1.0.0', standalone: false }) === '— Stash it v1.0.0 · in a browser',
    contextLine({ version: '1.0.0', standalone: false }),
  );

  // Nothing about the user's own data may ride along. The only thing they
  // send is what they typed.
  const body = contactBody('idea', CTX);
  check('the body opens with room to type', body.startsWith('\n\n'), JSON.stringify(body.slice(0, 4)));
  check('the context is last, where it can be deleted', body.trimEnd().endsWith(contextLine(CTX)));
  check('and there is nothing else in it', body.split('\n').filter((l) => l.trim()).length === 2, body);

  /* ----------------------------------------------------------- encoding */

  const url = contactUrl('bug', CTX);
  check('the subject is encoded', url.includes('subject=Stash%20it%20%E2%80%94%20something%20is%20wrong'), url);
  check('newlines survive as %0A', url.includes('%0A%0A'), url);
  check('the em dash is encoded', !url.includes('—'), url);
  // A raw ampersand or hash in either field would end the parameter early and
  // silently truncate the message.
  const params = url.slice(url.indexOf('?') + 1).split('&');
  check('there are exactly two parameters', params.length === 2, params.length + ': ' + params.join(' | '));
  check('no stray hash starts a fragment', url.indexOf('#') === -1, url);

  const kinds: ContactKind[] = ['question', 'idea', 'bug'];
  for (const kind of kinds) {
    const u = contactUrl(kind, CTX);
    check(`${kind} carries a subject`, /[?&]subject=[^&]+/.test(u));
    check(`${kind} carries a body`, /[&]body=[^&]+/.test(u));
    check(`${kind} names the version`, decodeURIComponent(u).includes('v1.2.3'));
  }

  check(
    'each kind asks its own question',
    new Set(kinds.map((k) => contactBody(k, CTX))).size === 3,
  );

  /* ---------------------------------------------------------- platforms */

  check('android is recognised', platformWord('Mozilla/5.0 (Linux; Android 14; Pixel 8)') === 'Android');
  check('iphone is recognised', platformWord('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)') === 'iOS');
  check('mac is recognised', platformWord('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15)') === 'macOS');
  check('windows is recognised', platformWord('Mozilla/5.0 (Windows NT 10.0; Win64)') === 'Windows');
  // Android is Linux-based, so order matters: the more specific test wins.
  check('android is not reported as linux', platformWord('Mozilla/5.0 (Linux; Android 14)') !== 'Linux');
  check('anything else is left undefined', platformWord('Some Odd Browser/1.0') === undefined);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
