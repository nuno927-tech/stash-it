import { useState } from 'react';
import { db, nowISO } from '@/db/db';
import { feedback } from '@/lib/feedback';
import { VERDICT_COPY } from '@/lib/push';
import { enablePush, pushVerdict, refreshNotes, syncSchedule } from '@/lib/pushClient';
import { ScoutDialog } from './ScoutDialog';

/**
 * "You've saved something with a date on it. Want to be told?"
 *
 * Asked once, at the only moment it means anything — see lib/notifyOffer.ts for
 * why here and not on the settings screen.
 *
 * ── The shape of the two buttons ──────────────────────────────────────────
 * Yes is the filled one and No is a plain link, which is the usual way round,
 * and it is worth saying why that is not a dark pattern here: declining costs
 * nothing. The dashboard carries the same information, so "No thanks" leaves
 * someone with a working app rather than a degraded one. If saying no broke
 * something, the buttons would have to be equal.
 *
 * ── Why it says what leaves the phone, in a sentence ──────────────────────
 * This is a permission prompt for the one feature that needs a server, put in
 * front of someone who chose this app because it doesn't have one. Asking them
 * to decide without that fact is asking for a yes they would take back.
 */
export function NotifyOffer({ propertyId, onClose }: { propertyId: string; onClose: () => void }) {
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState<string | null>(null);
  const verdict = pushVerdict();

  /* Written on both answers. A question that comes back is a question that
     gets swatted, and a swat is not an answer. */
  const remember = () => db.settings.update('singleton', { pushAskedAt: nowISO() });

  const yes = async () => {
    setBusy(true);
    try {
      const outcome = await enablePush();
      if (outcome !== 'on') {
        feedback('error');
        setFailed(VERDICT_COPY[outcome]);
        setBusy(false);
        return;
      }
      await refreshNotes(propertyId);
      await syncSchedule(propertyId, true);
      await remember();
      feedback('save');
      onClose();
    } catch (e) {
      feedback('error');
      setFailed((e as Error).message);
      setBusy(false);
    }
  };

  const no = async () => {
    await remember();
    onClose();
  };

  return (
    <ScoutDialog
      pose="alert"
      height={200}
      title="Want a nudge nearer the time?"
      alt="Scout with a raised paw"
      onClose={() => void no()}
    >
      <p>
        That one has a date on it. Stash it can tell you while there is still time to do something
        about it — even with the app closed.
      </p>
      <p className="hint">
        It means sending one thing off this phone: a delivery address and the days something is
        due. Never what it is. {verdict === 'needs-install' ? VERDICT_COPY[verdict] : ''}
      </p>

      {failed && <p className="hint warnhint">{failed}</p>}

      <button type="button" className="btn wide" disabled={busy} onClick={() => void yes()}>
        {busy ? 'Just a second…' : 'Yes, notify me'}
      </button>
      <button type="button" className="linkish wide-link" onClick={() => void no()}>
        No thanks — I'll check the app
      </button>
    </ScoutDialog>
  );
}
