import { useState } from 'react';
import { feedback } from '@/lib/feedback';
import { promptInstall, rememberDismissal, type InstallOffer } from '@/lib/install';
import { Nutsy } from './Nutsy';

/**
 * The first-run invitation to install.
 *
 * A sheet rather than a banner, because the reason to install isn't obvious
 * and a one-line bar can't carry it: installing is what earns persistent
 * storage, which is what stops the browser evicting a database that exists
 * nowhere else. That's worth two sentences and a moment of attention.
 *
 * Dismissible, and remembered — asked once, not every launch.
 */
export function InstallPrompt({ offer, onClose }: { offer: InstallOffer; onClose: () => void }) {
  const [busy, setBusy] = useState(false);

  if (offer === 'none') return null;

  const close = (remember: boolean) => {
    if (remember) rememberDismissal();
    onClose();
  };

  const install = async () => {
    setBusy(true);
    const outcome = await promptInstall();
    feedback(outcome === 'accepted' ? 'save' : 'tap');
    // Either way the question has been answered; don't ask again.
    close(true);
  };

  return (
    <div className="installscrim" role="dialog" aria-modal="true" aria-labelledby="install-title">
      <div className="installsheet">
        <Nutsy pose="acorn" height={124} motion={['float', 'breathe']} shadow />

        <h2 id="install-title">Keep Stash it on your home screen</h2>

        <p>
          Everything you add lives on this device and nowhere else. Installing gives it a permanent
          home, so the browser won't clear it to free up space — and it opens full screen, without
          the address bar.
        </p>

        {offer === 'native' ? (
          <button type="button" className="btn wide" disabled={busy} onClick={install}>
            {busy ? 'Opening…' : 'Install'}
          </button>
        ) : (
          <IOSSteps />
        )}

        <button type="button" className="btn ghost" onClick={() => close(true)}>
          Not now
        </button>
      </div>
    </div>
  );
}

/**
 * iOS has no install API, so the only useful thing is to describe the two taps
 * — with the actual Share glyph, since "the share button" describes four
 * different icons across the platforms people have used.
 */
function IOSSteps() {
  return (
    <ol className="installsteps">
      <li>
        <span className="stepnum">1</span>
        <span>
          Tap
          <svg
            width="17"
            height="17"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.9"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-label="Share"
          >
            <path d="M12 15V3.5M8.5 7L12 3.5 15.5 7" />
            <path d="M6 11H4.5v9.5h15V11H18" />
          </svg>
          in the toolbar
        </span>
      </li>
      <li>
        <span className="stepnum">2</span>
        <span>Choose Add to Home Screen</span>
      </li>
    </ol>
  );
}
