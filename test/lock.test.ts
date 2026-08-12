/**
 * The biometric lock.
 *
 *   npm run test:lock
 *
 * Two properties matter more than the rest. A lock that stays up when it can
 * never be satisfied is a data-loss event — the user's only copy of everything
 * they own, behind a check the device can no longer perform. And a lock that
 * quietly opens because a field was missing is worse than not shipping one.
 */

import 'fake-indexeddb/auto';

import { canOfferLock, fromBase64Url, lockVerdict, toBase64Url } from '@/lib/lock';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

function main() {
  const CRED = 'abc123';

  /* -------------------------------------------------------------- verdict */

  check('off means open', lockVerdict({ enabled: false, credentialId: CRED, available: true }) === 'open');
  check(
    'off stays open even with no authenticator',
    lockVerdict({ enabled: false, available: false }) === 'open',
  );
  check(
    'on with a credential and a sensor locks',
    lockVerdict({ enabled: true, credentialId: CRED, available: true }) === 'locked',
  );

  // Enrolment that never finished must not lock anyone out. The switch is
  // written together with the credential, but a partial write, an interrupted
  // upgrade or a hand-edited record could still land here.
  check(
    'on without a credential opens rather than locking',
    lockVerdict({ enabled: true, available: true }) === 'open',
  );
  check(
    'and an empty credential counts as none',
    lockVerdict({ enabled: true, credentialId: '', available: true }) === 'open',
  );

  // The stranded case: the switch is on, a credential exists, and the device
  // has no authenticator left to satisfy it. This is the only state that may
  // offer a way past without biometrics.
  check(
    'no authenticator strands rather than locking',
    lockVerdict({ enabled: true, credentialId: CRED, available: false }) === 'stranded',
  );

  /* --------------------------------------------------------------- offer */

  check('no sensor, no switch', !canOfferLock(false));
  check('a sensor earns the switch', canOfferLock(true));

  /* -------------------------------------------------------------- base64 */

  // Credential ids are bytes and get stored as text. A round trip that drops a
  // byte produces a lock that can never be opened, which is the failure this
  // whole file exists to prevent.
  const bytes = new Uint8Array([0, 1, 2, 250, 251, 252, 253, 254, 255, 62, 63]);
  const encoded = toBase64Url(bytes);
  check('the encoding is URL-safe', !/[+/=]/.test(encoded), encoded);
  const back = fromBase64Url(encoded);
  check('a round trip keeps the length', back.length === bytes.length);
  check('and every byte', bytes.every((b, i) => back[i] === b));

  // Lengths either side of a base64 quantum, where padding goes wrong.
  for (const n of [1, 2, 3, 4, 5, 16, 31, 32, 33, 64]) {
    const b = new Uint8Array(n).map((_, i) => (i * 37) % 256);
    const r = fromBase64Url(toBase64Url(b));
    check(`${n} bytes survive the round trip`, r.length === n && b.every((v, i) => r[i] === v));
  }

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
