import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { db, nowISO } from '@/db/db';
import { pushBack } from '@/lib/backstack';
import { feedback } from '@/lib/feedback';
import { swipeVerdict } from '@/lib/swipe';
import { isLastStep, stepAt, TOUR_STEPS } from '@/lib/tour';
import { Scout } from './Scout';

/**
 * A short deck, swipeable, skippable from the first screen.
 *
 * A tour has to be leaveable at any point or it's a hostage situation — but
 * Skip is deliberately quieter than Next, because someone who taps through a
 * handful of short screens learns things that otherwise take a fortnight to
 * find. How many screens is decided in lib/tour.ts, which treats the count as
 * a budget rather than as a list.
 *
 * Finishing and skipping both record `tourDoneAt`. Declining is an answer, and
 * an app that re-asks a question you've answered is an app you stop reading.
 */
export function Tour({ onClose }: { onClose: () => void }) {
  const [at, setAt] = useState(0);
  const [drag, setDrag] = useState(0);
  const from = useRef<{ x: number; y: number; t: number } | null>(null);

  const step = stepAt(at);
  const last = isLastStep(at);

  const finish = async () => {
    await db.settings.update('singleton', { tourDoneAt: nowISO(), tourRemindAt: undefined });
    feedback('save');
    onClose();
  };

  const go = (delta: number) => {
    const next = at + delta;
    setDrag(0);
    if (next < 0) return;
    if (next >= TOUR_STEPS.length) return void finish();
    feedback('nav');
    setAt(next);
  };

  // The system back gesture leaves the tour. It could step backwards through
  // it instead, but then Back would mean two different things depending on how
  // far in you are, and the only reliable way out would be a button in the
  // corner.
  useEffect(() => pushBack(onClose), [onClose]);

  return createPortal(
    <div
      className="tourscrim"
      role="dialog"
      aria-modal="true"
      aria-label={`Tour, step ${at + 1} of ${TOUR_STEPS.length}`}
      onPointerDown={(e) => {
        if (e.pointerType === 'mouse') return;
        from.current = { x: e.clientX, y: e.clientY, t: e.timeStamp };
      }}
      onPointerMove={(e) => {
        if (!from.current) return;
        setDrag(e.clientX - from.current.x);
      }}
      onPointerUp={(e) => {
        const start = from.current;
        from.current = null;
        if (!start) return;
        const verdict = swipeVerdict({
          dx: e.clientX - start.x,
          dy: e.clientY - start.y,
          elapsed: e.timeStamp - start.t,
          width: window.innerWidth,
        });
        if (verdict === 'left') go(1);
        else if (verdict === 'right') go(-1);
        else setDrag(0);
      }}
      onPointerCancel={() => {
        from.current = null;
        setDrag(0);
      }}
    >
      <button type="button" className="tourskip linkish" onClick={() => void finish()}>
        Skip
      </button>

      <div
        className="tourbody"
        style={{
          transform: `translateX(${drag * 0.4}px)`,
          transition: from.current === null ? 'transform 0.25s ease' : 'none',
        }}
      >
        <Scout
          key={step.key}
          pose={step.pose}
          height={168}
          motion={['float', 'breathe']}
          shadow
          alt=""
        />
        <h2>{step.title}</h2>
        <p>{step.body}</p>
      </div>

      <div className="tourfoot">
        <div className="tourdots" aria-hidden="true">
          {TOUR_STEPS.map((s, i) => (
            <i key={s.key} className={i === at ? 'on' : ''} />
          ))}
        </div>

        <button type="button" className="btn wide tallbtn" onClick={() => go(1)}>
          {last ? 'Start stashing' : 'Next'}
        </button>

        {at > 0 && (
          <button type="button" className="linkish" onClick={() => go(-1)}>
            Back
          </button>
        )}
      </div>
    </div>,
    document.body,
  );
}
