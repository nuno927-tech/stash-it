import type { Nudge } from '@/lib/nudges';

/**
 * Where a reminder actually shows up.
 *
 * There is no push notification and there can't be one: no server, no account,
 * nothing running while the app is closed. So a reminder is a card at the top
 * of the dashboard, seen the next time you open the app. That's the whole
 * mechanism, and it's why the copy never says "we'll let you know".
 *
 * Dismissal is for the session only, deliberately. A backup that's overdue is
 * still overdue tomorrow, and a reminder you can permanently silence with one
 * stray tap isn't a reminder — the way to turn these off is the setting that
 * governs them.
 */
export function NudgeBar({
  nudges,
  preview,
  onAct,
  onDismiss,
}: {
  nudges: Nudge[];
  /** Samples from the developer card, not the real state of your data. */
  preview?: boolean;
  onAct: (n: Nudge) => void;
  onDismiss: (n: Nudge) => void;
}) {
  if (nudges.length === 0) return null;

  return (
    <div className="nudges">
      {/* Said plainly, because otherwise a preview of "no backup yet" on a
          dashboard is indistinguishable from the real alarm. */}
      {preview && (
        <p className="nudgenote">
          Preview — these are samples. Leaving this screen clears them.
        </p>
      )}

      {nudges.map((n) => (
        <div key={n.kind} className={`nudge ${n.kind}`}>
          <div className="nudge-txt">
            <strong>{n.title}</strong>
            <p>{n.body}</p>
          </div>

          <div className="nudge-acts">
            <button type="button" className="minibtn" onClick={() => onAct(n)}>
              {n.action}
            </button>
            <button type="button" className="linkish" onClick={() => onDismiss(n)}>
              Not now
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
