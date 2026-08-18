import { db, nowISO } from '@/db/db';
import { money, YEARLY_AMOUNT } from '@/lib/donate';
import { ScoutDialog } from './ScoutDialog';

/**
 * Shown once, the first time notifications are switched on.
 *
 * ── Why this moment and no other ──────────────────────────────────────────
 * Every other part of Stash it runs on the device and costs nobody anything.
 * Notifications are the one feature with a bill attached: a server that has to
 * be awake every hour, for everyone, forever. Somebody has just chosen to use
 * it, which makes this the only honest moment to mention what it costs — and
 * the only one where the person is not being asked to pay for something
 * abstract.
 *
 * ── What it must not do ───────────────────────────────────────────────────
 * It cannot gate the feature, and it cannot come back. Reminders work whether
 * or not anyone gives a penny, and an app that asks twice has started charging
 * by attrition. So: one appearance, a date written the moment it is seen, and
 * the only two ways out are "maybe later" and the tip jar.
 *
 * The number is real rather than gestural. Ten dollars covers a year of the
 * sender, so that is what it says — a figure someone can check against a
 * feeling of fairness beats a vague appeal, and people give more readily to a
 * number that means something.
 */
export function RunningCosts({ onSupport, onClose }: { onSupport: () => void; onClose: () => void }) {
  const done = async (then: () => void) => {
    await db.settings.update('singleton', { pushCostShownAt: nowISO() });
    then();
  };

  return (
    <ScoutDialog
      pose="acorn"
      height={200}
      title="Reminders are on"
      alt="Scout holding an acorn"
      onClose={() => void done(onClose)}
    >
      <p>
        Everything else in Stash it happens on your phone and costs nothing to run. Notifications
        are the exception — they need a server awake around the clock, and that lands on me.
      </p>
      <p>
        The app stays free either way. But if you want to help,{' '}
        <b>{money(YEARLY_AMOUNT)} a year</b> covers the whole thing.
      </p>

      <button type="button" className="btn wide" onClick={() => void done(onSupport)}>
        Chip in {money(YEARLY_AMOUNT)}
      </button>
      <button type="button" className="linkish wide-link" onClick={() => void done(onClose)}>
        Maybe later
      </button>
    </ScoutDialog>
  );
}
