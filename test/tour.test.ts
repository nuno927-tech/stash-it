/**
 * The tour, and when to offer it again.
 *
 *   npm run test:tour
 *
 * "Remind me later" has to mean a specific day or it means never, and never is
 * what most apps quietly implement. The other half matters just as much: an
 * app that periodically decides you'd like to be taught how to use it is one
 * you stop reading.
 */

import { isLastStep, REMIND_DAYS, remindLater, stepAt, TOUR_STEPS, tourDue } from '@/lib/tour';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const NOW = new Date('2026-08-12T09:00:00Z');
const day = 86_400_000;
const at = (days: number) => new Date(NOW.getTime() + days * day).toISOString();

function main() {
  /* ------------------------------------------------------------ the steps */

  check('there are steps', TOUR_STEPS.length >= 4, String(TOUR_STEPS.length));
  check('each has a unique key', new Set(TOUR_STEPS.map((s) => s.key)).size === TOUR_STEPS.length);
  check(
    'each says something',
    TOUR_STEPS.every((s) => s.title.length > 8 && s.body.length > 30),
  );
  // Screen after screen of the same picture is a slideshow, not a tour.
  check('the poses vary', new Set(TOUR_STEPS.map((s) => s.pose)).size >= 4);

  /*
    A CEILING, not just a floor.

    Documents, subscriptions and reminders all arrived after this tour was
    written, and the obvious move each time was to append a screen. Three of
    those and the introduction to an app whose pitch is "this is quick" runs to
    eleven taps. The count is a budget: to add one, fold two of the old ones
    together — which is what happened to the email-receipt and missing-details
    screens. This is the assertion that forces that conversation.
  */
  check('and the deck stays short', TOUR_STEPS.length <= 8, String(TOUR_STEPS.length));

  // Everything the app does should be findable in it. Not an exhaustive
  // feature list — the four things it is for.
  const script = TOUR_STEPS.map((s) => `${s.title} ${s.body}`).join(' ').toLowerCase();
  for (const subject of ['warrant', 'document', 'subscription', 'reminder', 'backup:back up']) {
    const [name, needle] = subject.includes(':') ? subject.split(':') : [subject, subject];
    check(`the tour mentions ${name}`, script.includes(needle!));
  }

  /*
    And it must not promise something that was removed. Google Drive backup is
    gone — the app shares one file to wherever you like now — and a tour still
    telling people to "connect Google Drive" sends them looking for a setting
    that no longer exists.
  */
  check('and promises nothing that was removed', !script.includes('google drive'));

  check('the last step knows it is last', isLastStep(TOUR_STEPS.length - 1));
  check('the first does not', !isLastStep(0));
  // Index arithmetic that runs off the end should not crash a full-screen
  // takeover with no other way out.
  check('an index past the end clamps', stepAt(99).key === TOUR_STEPS.at(-1)!.key);
  check('and so does a negative one', stepAt(-3).key === TOUR_STEPS[0]!.key);

  /* ------------------------------------------------------------- the wait */

  check('three days is the promise', REMIND_DAYS === 3);
  check('and remindLater keeps it', remindLater(NOW) === at(3));

  check('no reminder pending, no offer', !tourDue({}, NOW));
  check('not due yet', !tourDue({ remindAt: at(1) }, NOW));
  check('due on the day', tourDue({ remindAt: at(0) }, NOW));
  check('and after it', tourDue({ remindAt: at(-1) }, NOW));

  // Having taken it is the end of the matter, whatever else is set.
  check('a finished tour is never offered', !tourDue({ doneAt: at(-10) }, NOW));
  check(
    'not even with a reminder still pending',
    !tourDue({ doneAt: at(-10), remindAt: at(-1) }, NOW),
  );

  // A corrupt date came from a reminder that was genuinely requested. Showing
  // it is recoverable; silently dropping it is not.
  check('a corrupt date errs towards offering', tourDue({ remindAt: 'not a date' }, NOW));

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
