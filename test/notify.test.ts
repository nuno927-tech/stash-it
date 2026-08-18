/**
 * When to ask whether reminders should arrive as notifications.
 *
 *   npm run test:notify
 *
 * Every assertion here is a reason NOT to ask, which is the right shape for a
 * prompt: the cost of one that appears when it shouldn't is paid by everyone
 * who sees it, and the cost of one that doesn't is a switch in Settings.
 */

import { datedSave, shouldOffer } from '@/lib/notifyOffer';
import type { PushVerdict } from '@/lib/push';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const ready = { asked: false, enabled: false, verdict: 'ready' as PushVerdict, dated: true };

function main() {
  /* --------------------------------------------------------- when to ask */

  check('a dated save on a capable device gets the question', shouldOffer(ready));

  check('but only once ever', !shouldOffer({ ...ready, asked: true }));
  check('and not when it is already on', !shouldOffer({ ...ready, enabled: true }));
  check('nor for something with no date on it', !shouldOffer({ ...ready, dated: false }));

  /*
    The two that matter most. Asking someone to switch on a feature this build
    cannot provide gets a yes, then a failure, and teaches them the app is
    broken — for a switch that was never going to work.
  */
  check('never in a browser that cannot', !shouldOffer({ ...ready, verdict: 'unsupported' }));
  check('never in a build with no key', !shouldOffer({ ...ready, verdict: 'no-key' }));
  check('and not after they blocked it', !shouldOffer({ ...ready, verdict: 'denied' }));

  /*
    The exception. On an iPhone "add it to your Home Screen first" is a real
    instruction someone can follow, so the offer is worth making — the dialog
    carries the sentence that says so.
  */
  check('an iPhone is asked, and told to install', shouldOffer({ ...ready, verdict: 'needs-install' }));

  // asked wins over everything, including a device that could.
  check(
    'a previous no is respected even on a perfect device',
    !shouldOffer({ ...ready, asked: true, verdict: 'ready' }),
  );

  /* ---------------------------------------------- what counts as "dated" */

  check('a document with an expiry counts', datedSave({ expiresOn: '2027-01-01', hasCover: false }));
  check('one without does not', !datedSave({ expiresOn: '', hasCover: false }));
  check('and neither does whitespace', !datedSave({ expiresOn: '   ', hasCover: false }));

  /*
    A warranty needs both halves. A purchase date with no cover expires
    nothing, and cover with no purchase date has nothing to count from — either
    on its own would generate an empty schedule and an offer with nothing
    behind it.
  */
  check('a purchase date with cover counts', datedSave({ purchaseDate: '2026-08-17', hasCover: true }));
  check('a date with no cover does not', !datedSave({ purchaseDate: '2026-08-17', hasCover: false }));
  check('nor cover with no date', !datedSave({ purchaseDate: '', hasCover: true }));

  /*
    Deliberately crude: whether the date lands inside the two-month push
    horizon is not asked. A three-year warranty bought last week generates no
    wake for years and is exactly the one worth a reminder — it is the one
    nobody will still be thinking about.
  */
  check(
    'a warranty years out still counts',
    datedSave({ purchaseDate: '2026-08-17', hasCover: true }),
  );

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
