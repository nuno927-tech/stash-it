import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react';
import { createPortal } from 'react-dom';
import { pushBack } from '@/lib/backstack';
import { feedback } from '@/lib/feedback';
import { dismissedByDrag } from '@/lib/swipe';
import { Scout } from './Scout';

/**
 * The one part of the job the app cannot do for you.
 *
 * Everything else here is a copy: the photo, the dates, the export. The paper
 * original is the only artefact that exists once, and a phone in a puddle
 * doesn't take it with it. Retailers and manufacturers vary on whether a
 * photograph is enough — plenty accept one, some still want the physical
 * receipt, and you find out which on the day the thing breaks.
 *
 * So this shows after every save, not once. It was tempting to fire it three
 * times and stop, on the grounds that people learn — but the habit is per
 * receipt, not per person. Knowing you should file the paper is no use on the
 * eleventh purchase if the paper for it is in a carrier bag.
 *
 * It began as a strip along the top of the item page and became a dialog,
 * because a strip above the fold is a strip you stop seeing by the fourth one.
 * A dialog you have to dismiss is read; the price is that dismissing it has to
 * be effortless, which is why there are four ways out — the ×, a swipe in
 * either direction, the scrim, and Escape or system back.
 */

/** One wording, used here, by the tour and by the site. */
export const STASH_THE_PAPER = {
  title: 'Now stash the paper',
  body: "Scout files every original. A photo settles most claims; some still want the real receipt. One folder, somewhere dry, and you've got both.",
} as const;

export function StashThePaper({ onClose }: { onClose: () => void }) {
  const [dy, setDy] = useState(0);
  const [going, setGoing] = useState(false);
  const drag = useRef<{ y: number; at: number } | null>(null);

  useEffect(() => pushBack(onClose), [onClose]);

  useEffect(() => {
    feedback('save');
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  /*
    Fly it out the way it was thrown before unmounting. Without this the card
    vanishes from wherever the finger left it, which reads as a glitch rather
    than as the thing you just did.
  */
  const leave = (direction: number) => {
    setGoing(true);
    setDy(direction * window.innerHeight);
    window.setTimeout(onClose, 180);
  };

  const onPointerDown = (e: ReactPointerEvent) => {
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    drag.current = { y: e.clientY, at: Date.now() };
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const onPointerMove = (e: ReactPointerEvent) => {
    if (!drag.current) return;
    setDy(e.clientY - drag.current.y);
  };

  const onPointerUp = (e: ReactPointerEvent) => {
    const held = drag.current;
    drag.current = null;
    if (!held) return;

    const moved = e.clientY - held.y;
    if (dismissedByDrag({ dy: moved, elapsed: Date.now() - held.at })) {
      feedback('tap');
      leave(Math.sign(moved) || 1);
    } else {
      // Not far enough. Spring back rather than close: a half-hearted drag
      // that dismissed things would make the card feel unstable.
      setDy(0);
    }
  };

  return createPortal(
    <div
      className="paperscrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby="paper-title"
      onPointerDown={(e) => {
        // Only the backdrop itself, not a drag that started on the card and
        // happened to end out here.
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="papermodal"
        style={{
          transform: dy ? `translateY(${dy}px)` : undefined,
          // Fading with distance makes the threshold legible: by the time it
          // looks nearly gone, letting go will finish the job.
          opacity: going ? 0 : Math.max(0.3, 1 - Math.abs(dy) / 320),
          transition: drag.current ? 'none' : 'transform 0.18s ease, opacity 0.18s ease',
        }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={() => {
          drag.current = null;
          setDy(0);
        }}
      >
        <span className="paperpill" aria-hidden="true" />

        <button type="button" className="iconbtn paperclose" onClick={onClose} aria-label="Close">
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
          >
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>

        <Scout pose="folder" height={148} motion={['breathe']} alt="Scout filing a receipt" />

        <h2 id="paper-title">{STASH_THE_PAPER.title}</h2>
        <p>{STASH_THE_PAPER.body}</p>

        <button type="button" className="btn wide" onClick={onClose}>
          Will do
        </button>
      </div>
    </div>,
    document.body,
  );
}
