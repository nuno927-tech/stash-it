import { useEffect, useRef, useState } from 'react';
import { pushBack } from '@/lib/backstack';
import { feedback } from '@/lib/feedback';

export interface Shot {
  id: string;
  url: string;
  caption?: string;
}

/**
 * Full-screen photos, swipeable.
 *
 * A receipt photographed at arm's length is unreadable at 96px, which is the
 * size the detail page shows it at — so tapping it has to do something, and
 * the only useful something is "make it as big as the screen".
 *
 * Pointer Events rather than touch events: the same handler then works for a
 * mouse drag on desktop, and Chrome on Android reports touches through both
 * APIs, which double-fires anything written against `touchstart`.
 */
export function PhotoViewer({
  shots,
  startAt = 0,
  onClose,
}: {
  shots: Shot[];
  startAt?: number;
  onClose: () => void;
}) {
  const [at, setAt] = useState(Math.min(startAt, Math.max(0, shots.length - 1)));
  const [drag, setDrag] = useState(0);
  const from = useRef<number | null>(null);

  // Back closes the photo, not the app — and not the item behind it either.
  useEffect(() => pushBack(onClose), [onClose]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowRight') go(1);
      if (e.key === 'ArrowLeft') go(-1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const go = (delta: number) => {
    setAt((i) => {
      const next = i + delta;
      if (next < 0 || next >= shots.length) return i;
      feedback('tap');
      return next;
    });
    setDrag(0);
  };

  if (shots.length === 0) return null;
  const shot = shots[at]!;

  return (
    <div
      className="viewer"
      role="dialog"
      aria-modal="true"
      aria-label={`Photo ${at + 1} of ${shots.length}`}
      onPointerDown={(e) => {
        from.current = e.clientX;
        e.currentTarget.setPointerCapture(e.pointerId);
      }}
      onPointerMove={(e) => {
        if (from.current === null) return;
        setDrag(e.clientX - from.current);
      }}
      onPointerUp={(e) => {
        const moved = from.current === null ? 0 : e.clientX - from.current;
        from.current = null;

        // A tenth of the screen. A fixed pixel threshold is either impossible
        // to reach on a small phone or triggered by a shaky tap on a tablet.
        const enough = window.innerWidth / 10;
        if (moved > enough) go(-1);
        else if (moved < -enough) go(1);
        else setDrag(0);
      }}
      onPointerCancel={() => {
        from.current = null;
        setDrag(0);
      }}
    >
      <button type="button" className="viewer-close" onClick={onClose} aria-label="Close">
        <svg
          width="22"
          height="22"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
        >
          <path d="M6 6l12 12M18 6L6 18" />
        </svg>
      </button>

      {shots.length > 1 && (
        <span className="viewer-count">
          {at + 1} of {shots.length}
        </span>
      )}

      {/* The whole strip moves, so the neighbouring photos are already there
          as you drag — a fade between two images reads as a glitch, a slide
          reads as a stack of prints. */}
      <div
        className="viewer-strip"
        style={{
          transform: `translateX(calc(${-at * 100}% + ${drag}px))`,
          transition: from.current === null ? 'transform 0.28s cubic-bezier(0.22, 1, 0.36, 1)' : 'none',
        }}
      >
        {shots.map((s) => (
          <div className="viewer-slide" key={s.id}>
            <img src={s.url} alt={s.caption ?? ''} draggable={false} />
          </div>
        ))}
      </div>

      {shot.caption && <span className="viewer-caption">{shot.caption}</span>}

      {shots.length > 1 && (
        <div className="viewer-dots" aria-hidden="true">
          {shots.map((s, i) => (
            <i key={s.id} className={i === at ? 'on' : ''} />
          ))}
        </div>
      )}
    </div>
  );
}
