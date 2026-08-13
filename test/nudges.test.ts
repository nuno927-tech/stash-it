/**
 * The app's reminders.
 *
 *   npm run test:nudges
 *
 * Written because two settings were doing nothing. "Warn me before a warranty
 * ends" wrote `reminderOffsetsDays` and no code read it — the amber threshold
 * was a hard-coded thirty days. "Remind me" wrote `backupReminderDays`, read
 * only by a hint inside the Drive card, which now sits behind the developer
 * tools. Both could be set, by anyone, to no effect whatsoever.
 *
 * A setting that writes to the database and changes nothing is worse than a
 * missing feature: it looks answered.
 */

import type { Settings } from '@/db/types';
import {
  backupNudge,
  DEFAULT_ENDING_SOON_DAYS,
  dueNudges,
  endingSoonDays,
  sampleNudges,
  tipNudge,
  warrantyNudge,
} from '@/lib/nudges';
import { getEndingSoonDays, setEndingSoonDays } from '@/lib/warranty';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const NOW = new Date('2026-08-12T09:00:00Z');
const DAY = 86_400_000;
const daysAgo = (n: number) => new Date(NOW.getTime() - n * DAY).toISOString();

function settings(over: Partial<Settings> = {}): Settings {
  return {
    id: 'singleton',
    schemaVersion: 2,
    reminderOffsetsDays: [30],
    currency: 'USD',
    backupReminderDays: 30,
    entitlements: { proUnlock: false, reportUnlock: false },
    devModeEnabled: false,
    ...over,
  };
}

function main() {
  /* ------------------------------------------------------ the threshold */

  check('the default is thirty days', endingSoonDays(settings()) === 30);
  check('a set value is honoured', endingSoonDays(settings({ reminderOffsetsDays: [7] })) === 7);
  check('an empty list falls back', endingSoonDays(settings({ reminderOffsetsDays: [] })) === DEFAULT_ENDING_SOON_DAYS);
  check('so does a missing record', endingSoonDays(undefined) === DEFAULT_ENDING_SOON_DAYS);

  // A restored backup from a future version, or a hand-edited record, must not
  // be able to paint the whole collection amber.
  check('a wild value is clamped up', endingSoonDays(settings({ reminderOffsetsDays: [0] })) === 1);
  check('and clamped down', endingSoonDays(settings({ reminderOffsetsDays: [99999] })) === 365);
  check(
    'rubbish falls back rather than throwing',
    endingSoonDays(settings({ reminderOffsetsDays: [NaN] })) === DEFAULT_ENDING_SOON_DAYS,
  );

  const before = getEndingSoonDays();
  setEndingSoonDays(7);
  check('the warranty module takes the setting', getEndingSoonDays() === 7, `${getEndingSoonDays()}`);
  setEndingSoonDays(9999);
  check('and clamps it too', getEndingSoonDays() === 365, `${getEndingSoonDays()}`);
  setEndingSoonDays(before);

  /* ---------------------------------------------------------- the backup */

  const overdue = backupNudge({ lastBackupAt: daysAgo(40), everyDays: 30, itemCount: 5 }, NOW);
  check('an overdue backup nudges', overdue !== null);
  check('and says how long it has been', overdue?.title === 'Last backup was 40 days ago', overdue?.title);

  check(
    'a recent one does not',
    backupNudge({ lastBackupAt: daysAgo(3), everyDays: 30, itemCount: 5 }, NOW) === null,
  );
  check(
    'the day it comes due, it does',
    backupNudge({ lastBackupAt: daysAgo(30), everyDays: 30, itemCount: 5 }, NOW) !== null,
  );

  const never = backupNudge({ everyDays: 30, itemCount: 5 }, NOW);
  check('never having backed up nudges', never?.title === 'No backup yet', never?.title);
  check('and counts what is at stake', never!.body.includes('5 items'), never?.body);

  // "Never" is a choice, not an interval of zero days.
  check('never means never', backupNudge({ everyDays: 0, itemCount: 5 }, NOW) === null);
  // Nagging someone to back up nothing is how reminders get ignored.
  check('an empty collection is left alone', backupNudge({ everyDays: 30, itemCount: 0 }, NOW) === null);
  check(
    'an unparseable date is treated as never',
    backupNudge({ lastBackupAt: 'not a date', everyDays: 30, itemCount: 2 }, NOW)?.title === 'No backup yet',
  );

  /* -------------------------------------------------------- the warranty */

  check('nothing ending means nothing said', warrantyNudge({ endingSoon: 0, days: 30 }) === null);
  const one = warrantyNudge({ endingSoon: 1, days: 14 });
  check('one reads as singular', one?.title === '1 warranty ends within 14 days', one?.title);
  check('and offers to show it', one?.action === 'See it');
  const many = warrantyNudge({ endingSoon: 4, days: 30 });
  check('several read as plural', many?.title === '4 warranties end within 30 days', many?.title);
  check(
    'the window quoted is the one that was set',
    warrantyNudge({ endingSoon: 2, days: 90 })?.title.includes('90 days'),
  );

  /* ------------------------------------------------------------- the tip */

  check('a one-off tip never nags', tipNudge({ monthly: false, lastAt: daysAgo(400) }, NOW) === null);
  check('a monthly one waits its month', tipNudge({ monthly: true, lastAt: daysAgo(10) }, NOW) === null);
  check('then asks', tipNudge({ monthly: true, lastAt: daysAgo(31) }, NOW) !== null);
  check('monthly with no history asks now', tipNudge({ monthly: true }, NOW) !== null);

  /* ---------------------------------------------------------- all of it */

  const all = dueNudges(
    {
      settings: settings({
        lastBackupAt: daysAgo(60),
        donateMonthly: true,
        donateLastAt: daysAgo(60),
      }),
      itemCount: 9,
      endingSoon: 2,
    },
    NOW,
  );
  check('all three can be due at once', all.length === 3, `${all.length}`);
  check('backup leads — it is the one that can cost you data', all[0]?.kind === 'backup');
  check('the tip is last, being the one that asks', all[2]?.kind === 'tip');

  const quiet = dueNudges(
    { settings: settings({ lastBackupAt: daysAgo(1) }), itemCount: 9, endingSoon: 0 },
    NOW,
  );
  check('a tidy collection says nothing', quiet.length === 0, quiet.map((n) => n.kind).join(','));
  check('no settings, no nudges', dueNudges({ settings: undefined, itemCount: 9, endingSoon: 3 }, NOW).length === 0);

  /* ------------------------------------------------------ the preview */

  const samples = sampleNudges(NOW);
  check('the developer preview has one of each', samples.length === 3, `${samples.length}`);
  check('none of them is empty', samples.every((n) => n.title && n.body && n.action));
  check(
    'and they are the real ones',
    samples.map((n) => n.kind).join(',') === 'backup,warranty,tip',
    samples.map((n) => n.kind).join(','),
  );

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
