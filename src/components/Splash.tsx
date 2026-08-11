import { useEffect, useState } from 'react';
import { Nutsy } from './Nutsy';

/**
 * The launch screen.
 *
 * It holds for a minimum beat even when the database opens instantly — a
 * splash that flickers for 40ms reads as a glitch, not a welcome. Once both
 * the app is ready and that beat has passed, it fades out and unmounts, so
 * nothing is left overlaying the dashboard.
 */
const MIN_VISIBLE_MS = 900;
const FADE_MS = 420;

export function Splash({ ready }: { ready: boolean }) {
  const [held, setHeld] = useState(false);
  const [gone, setGone] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setHeld(true), MIN_VISIBLE_MS);
    return () => clearTimeout(t);
  }, []);

  const leaving = ready && held;

  useEffect(() => {
    if (!leaving) return;
    const t = setTimeout(() => setGone(true), FADE_MS);
    return () => clearTimeout(t);
  }, [leaving]);

  if (gone) return null;

  return (
    <div className={`splash${leaving ? ' leaving' : ''}`} aria-hidden={leaving}>
      <div className="splash-inner">
        <Nutsy pose="acorn" height={190} motion={['float', 'breathe']} shadow alt="" />
        <h1 className="splash-word">
          Stash<span>&nbsp;it</span>
        </h1>
        <p>Warranties, receipts and manuals for everything you own.</p>
      </div>
    </div>
  );
}
