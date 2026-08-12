import { useState } from 'react';
import { createPortal } from 'react-dom';
import { feedback } from '@/lib/feedback';
import { promptInstall, type InstallOffer } from '@/lib/install';
import { Scout } from './Scout';

/**
 * The invitation to install.
 *
 * A sheet rather than a banner, because the reason to install isn't obvious
 * and a one-line bar can't carry it: installing is what earns persistent
 * storage, which is what stops the browser evicting a database that exists
 * nowhere else. That's worth two sentences and a moment of attention.
 *
 * Asked on every launch until the app is installed. It used to remember a
 * dismissal forever, which sounds polite and wasn't — the flag outlived
 * uninstalling the app, so the people who hadn't installed were precisely the
 * people no longer being asked. "Not now" means not now.
 */
export function InstallPrompt({ offer, onClose }: { offer: InstallOffer; onClose: () => void }) {
  const [busy, setBusy] = useState(false);

  if (offer === 'none') return null;

  const install = async () => {
    setBusy(true);
    const outcome = await promptInstall();
    feedback(outcome === 'accepted' ? 'save' : 'tap');
    onClose();
  };

  // Into document.body: a fixed overlay rendered inside the shell is at the
  // mercy of whatever that shell does with overflow and transforms.
  return createPortal(
    <div className="installscrim" role="dialog" aria-modal="true" aria-labelledby="install-title">
      <div className="installsheet">
        <Scout pose="acorn" height={110} motion={['float', 'breathe']} shadow alt="" />

        <h2 id="install-title">Keep Stash it on your home screen</h2>

        <p>
          Everything you add lives on this device and nowhere else. Installing gives it a permanent
          home, so the browser won't clear it to free up space — and it opens full screen, without
          the address bar.
        </p>

        {offer === 'native' && (
          <button type="button" className="btn wide" disabled={busy} onClick={install}>
            {busy ? 'Opening…' : 'Install'}
          </button>
        )}
        {offer === 'ios' && <IOSSteps />}
        {offer === 'manual' && <AndroidSteps />}

        <button type="button" className="btn ghost" onClick={onClose}>
          Not now
        </button>
      </div>
    </div>,
    document.body,
  );
}

/**
 * Chromium didn't offer us a button this time. That happens — a fresh profile,
 * a recent uninstall, an engagement heuristic nobody documents — and the menu
 * item is there regardless, so say where it is rather than showing nothing.
 */
function AndroidSteps() {
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
            fill="currentColor"
            stroke="none"
            aria-label="the browser menu"
          >
            <circle cx="12" cy="5" r="1.9" />
            <circle cx="12" cy="12" r="1.9" />
            <circle cx="12" cy="19" r="1.9" />
          </svg>
          in the browser bar
        </span>
      </li>
      <li>
        <span className="stepnum">2</span>
        <span>Choose Add to Home screen, or Install app</span>
      </li>
    </ol>
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
