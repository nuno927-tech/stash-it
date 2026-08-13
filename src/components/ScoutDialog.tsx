import {
  useEffect,
  useId,
  useRef,
  useState,
  type PointerEvent as ReactPointerEvent,
  type ReactNode,
} from 'react';
import { createPortal } from 'react-dom';
import { pushBack } from '@/lib/backstack';
import { feedback } from '@/lib/feedback';
import { dismissedByDrag } from '@/lib/swipe';
import { Scout, type ScoutPose } from './Scout';

/**
 * A centred dialog with Scout in it.
 *
 * Two screens wanted the same object — "you've saved it, now file the paper"
 * and "are you sure you want to delete this" — and both had been inline blocks
 * in the page. Inline is why they were being missed: one was a strip above the
 * fold that stops registering by the fourth save, the other was a confirmation
 * that appeared below the bottom of the screen, so deleting something asked
 * you to scroll to find out what you'd agreed to.
 *
 * Building it twice would have given us two objects with the same job and
 * different physics, which is the sort of thing nobody notices and everybody
 * feels.
 *
 * DISMISSAL. Four ways out, because a dialog seen after every save has to cost
 * nothing: the ×, a swipe in either direction, the scrim, and Escape or system
 * back. All of them mean the same thing — close, take no action. The dangerous
 * option is never the default and never the one your thumb lands on by
 * momentum, so a swipe can only ever cancel.
 */
export function ScoutDialog({
  pose,
  height = 200,
  title,
  alt,
  children,
  onClose,
}: {
  pose: ScoutPose;
  height?: number;
  title: string;
  alt?: string;
  /** The body copy and the buttons. */
  children: ReactNode;
  onClose: () => void;
}) {
  const [dy, setDy] = useState(0);
  const [going, setGoing] = useState(false);
  const drag = useRef<{ y: number; at: number } | null>(null);
  const titleId = useId();

  useEffect(() => pushBack(onClose), [onClose]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  /*
    Fly it out the way it was thrown, then unmount. Without this the card
    disappears from wherever the finger left it, which reads as a glitch rather
    than as the thing you just did.
  */
  const leave = (direction: number) => {
    setGoing(true);
    setDy(direction * window.innerHeight);
    window.setTimeout(onClose, 180);
  };

  const onPointerDown = (e: ReactPointerEvent) => {
    // Never start a drag on a button: the press would fight the gesture and
    // the tap would sometimes not register.
    if ((e.target as HTMLElement).closest('button')) return;
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    drag.current = { y: e.clientY, at: Date.now() };
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const onPointerMove = (e: ReactPointerEvent) => {
    if (drag.current) setDy(e.clientY - drag.current.y);
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
      // Not far enough. Spring back rather than close — a card that closes on
      // a half-hearted drag feels unstable, and on the delete dialog it would
      // also be answering a question you hadn't answered.
      setDy(0);
    }
  };

  return createPortal(
    <div
      className="dlgscrim"
      role="dialog"
      aria-modal="true"
      aria-labelledby={titleId}
      onPointerDown={(e) => {
        // The backdrop itself, not a drag that began on the card and happened
        // to finish out here.
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="dlgcard"
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
        {/* The only hint that the card can be thrown. Without a handle nobody
            tries to swipe a dialog. */}
        <span className="dlgpill" aria-hidden="true" />

        <button type="button" className="iconbtn dlgclose" onClick={onClose} aria-label="Close">
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

        {/*
          The card doesn't scroll — it interprets vertical drags. This does,
          for the one case that would otherwise trap content off the bottom: a
          long item name in the delete title, on a short phone. When it fits,
          which is almost always, there is nothing for the browser to pan and
          the drag runs as normal.
        */}
        <div className="dlgscroll">
          <Scout pose={pose} height={height} motion={['breathe']} alt={alt ?? ''} />

          <h2 id={titleId}>{title}</h2>
          {children}
        </div>
      </div>
    </div>,
    document.body,
  );
}
