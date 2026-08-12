import { useEffect, useRef, useState } from 'react';
import { feedback } from '@/lib/feedback';
import { clearLock, verifyBiometrics, type LockVerdict } from '@/lib/lock';
import { Nutsy } from './Nutsy';

/**
 * The unlock gate: a sheet across the lower two thirds, over a blurred app.
 *
 * Not a full-screen takeover. The scrim leaves the top of the dashboard
 * visible but unreadable, which says "your things are behind this" far better
 * than a blank panel — and the sheet's own weight then does the asking.
 *
 * It opens the OS prompt on mount rather than waiting for a tap. On a phone
 * that is one gesture removed, and the button is still there for the second
 * attempt.
 */
export function LockScreen({
  credentialId,
  verdict,
  onUnlocked,
}: {
  credentialId: string;
  verdict: LockVerdict;
  onUnlocked: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string>();
  const [rescue, setRescue] = useState(false);
  const tried = useRef(false);

  const unlock = async () => {
    setBusy(true);
    setNote(undefined);
    const outcome = await verifyBiometrics(credentialId);
    if (outcome === 'unlocked') {
      feedback('save');
      onUnlocked();
      return;
    }
    feedback('error');
    setBusy(false);
    setNote(
      outcome === 'cancelled'
        ? 'Not recognised. Try again.'
        : "This device wouldn't answer. Try again, or use the recovery option below.",
    );
    if (outcome !== 'cancelled') setRescue(true);
  };

  useEffect(() => {
    if (verdict === 'locked' && !tried.current) {
      tried.current = true;
      void unlock();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [verdict]);

  // Stranded: the device no longer has any authenticator, so no amount of
  // trying can ever succeed. This is the only state that offers a way past
  // without biometrics, and reaching it on a phone you don't own means getting
  // past the passcode first.
  const stranded = verdict === 'stranded';

  return (
    <div className="lockscrim" role="dialog" aria-modal="true" aria-labelledby="lock-title">
      <div className="locksheet">
        <span className="lockgrip" aria-hidden="true" />

        <Nutsy pose="acorn" height={92} motion={['breathe']} />

        <h2 id="lock-title">
          {stranded ? 'Biometrics unavailable' : 'Stash it is locked'}
        </h2>

        <p>
          {stranded
            ? "This device no longer offers a fingerprint or face check, so the lock can't be satisfied. You can turn it off and get back in."
            : 'Use your fingerprint or face to open your things.'}
        </p>

        {note && !stranded && <p className="locknote">{note}</p>}

        {!stranded && (
          <button type="button" className="btn wide lockbtn" disabled={busy} onClick={unlock}>
            <FingerprintGlyph />
            {busy ? 'Waiting for the device…' : 'Unlock'}
          </button>
        )}

        {(stranded || rescue) && (
          <button type="button" className="btn ghost" onClick={() => void clearLock()}>
            Turn the lock off
          </button>
        )}

        <small className="lockfoot">
          The lock keeps the app shut. It doesn't encrypt what's inside, so keep exporting backups.
        </small>
      </div>
    </div>
  );
}

function FingerprintGlyph() {
  return (
    <svg
      width="19"
      height="19"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M12 10.5v3.2a7 7 0 001 3.6" />
      <path d="M8.6 8.6a4.8 4.8 0 016.8 3.4v2a9.6 9.6 0 00.8 3.8" />
      <path d="M5.6 12a6.4 6.4 0 011.5-4.6" />
      <path d="M8.7 20a11 11 0 01-1.6-4.3" />
      <path d="M4.2 8.2A8.7 8.7 0 0119.4 9a8.6 8.6 0 01.6 3.2v2.4" />
      <path d="M19.4 18.6c.3-.9.5-1.4.6-2" />
      <path d="M12 13.8a3.6 3.6 0 01-1.4 2.9" />
    </svg>
  );
}
