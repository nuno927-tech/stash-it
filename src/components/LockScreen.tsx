import { useEffect, useRef, useState } from 'react';
import { feedback } from '@/lib/feedback';
import { clearLock, verifyBiometrics, type LockVerdict } from '@/lib/lock';
import { Scout } from './Scout';

/**
 * The unlock gate.
 *
 * Scout stands in the top third, on the scrim; the card sits in the bottom two
 * thirds. That split isn't decoration — the browser's own verification dialog
 * is a bottom sheet on Android, so it covers the card and leaves Scout in
 * view. The app stays recognisably itself while the platform does the part we
 * aren't allowed to draw.
 *
 * The check fires on mount. An earlier version waited for a tap so our sheet
 * would paint before the system one, but that made opening a locked app two
 * deliberate actions — a button whose only job is to summon the real button.
 * With Scout above the fold, there's nothing left for that first tap to buy.
 *
 * So there is exactly one button in the normal path, it appears only after an
 * attempt has already failed, and pressing it does the same thing the launch
 * did: ask for a fingerprint.
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
  const [busy, setBusy] = useState(true);
  const [note, setNote] = useState<string>();
  const [rescue, setRescue] = useState(false);
  const asked = useRef(false);

  const stranded = verdict === 'stranded';

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
        ? 'Not recognised.'
        : "This device wouldn't answer.",
    );
    // A cancel is a decision, not a fault. Only a real failure suggests the
    // credential is broken, and only then is a way past worth offering.
    if (outcome !== 'cancelled') setRescue(true);
  };

  useEffect(() => {
    // Once. React runs effects twice in development, and a second WebAuthn
    // call while the first is open aborts it.
    if (stranded || asked.current) {
      if (stranded) setBusy(false);
      return;
    }
    asked.current = true;
    void unlock();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [stranded]);

  return (
    <div className="lockscrim" role="dialog" aria-modal="true" aria-labelledby="lock-title">
      {/* Above the sheet, and above the system dialog that will cover it. */}
      <div className="lockstage">
        <Scout
          pose="acorn"
          height={148}
          motion={busy ? ['float', 'breathe'] : ['breathe']}
          shadow
          alt="Scout holding an acorn"
        />
      </div>

      <div className="locksheet">
        <span className="lockgrip" aria-hidden="true" />

        <h2 id="lock-title">{stranded ? 'Biometrics unavailable' : 'Stash it is locked'}</h2>

        <p>
          {stranded
            ? "This device no longer offers a fingerprint or face check, so the lock can't be satisfied. You can turn it off and get back in."
            : busy
              ? 'Waiting for your fingerprint or face.'
              : 'Use your fingerprint or face to open your things.'}
        </p>

        {note && !stranded && <p className="locknote">{note}</p>}

        {/* Nothing to press while the platform prompt is already up — a
            disabled button under a dialog is furniture. */}
        {!stranded && !busy && (
          <button type="button" className="btn wide lockbtn" onClick={unlock}>
            <FingerprintGlyph />
            Unlock
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
