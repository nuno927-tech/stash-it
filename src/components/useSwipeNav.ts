import { useEffect, useRef, type RefObject } from 'react';
import {
  inHorizontalScroller,
  startedAtEdge,
  swipeVerdict,
  type Direction,
} from '@/lib/swipe';

/**
 * Horizontal swipe on the scrolling body of the app.
 *
 * Listeners go on the DOM node rather than through React props so they can be
 * passive: React attaches actively, and a non-passive move handler on the
 * element the thumb lives on costs a frame on every scroll.
 *
 * Nothing is ever preventDefault-ed. The gesture is judged at the end, so
 * scrolling stays the browser's throughout — which is what keeps the page from
 * feeling like it's fighting the finger.
 *
 * ── Why the last move, and not the release ────────────────────────────────
 * A pointer is *cancelled*, not released, the moment the browser decides the
 * touch belongs to a scroll. With `touch-action: pan-y` that happens on any
 * swipe with a little vertical drift, which is most real swipes — and a
 * cancelled pointer never reaches pointerup. Treating cancel as "gesture
 * abandoned" threw away exactly the swipes people were making.
 *
 * So every move is recorded, and both endings judge the same recorded travel.
 * A genuine abandonment fails the thresholds anyway.
 */
export function useSwipeNav(
  ref: RefObject<HTMLElement | null>,
  enabled: boolean,
  onSwipe: (direction: Direction) => void,
) {
  const handler = useRef(onSwipe);
  handler.current = onSwipe;

  useEffect(() => {
    const node = ref.current;
    if (!node || !enabled) return;

    let x0 = 0;
    let y0 = 0;
    let t0 = 0;
    let lastX = 0;
    let lastY = 0;
    let lastT = 0;
    let tracking = false;
    let pointer = -1;

    const width = () => node.clientWidth || window.innerWidth;

    const down = (e: PointerEvent) => {
      // Mouse drags are how people select text, not how they navigate.
      if (e.pointerType === 'mouse') return;
      // A second finger means a pinch or a scroll-with-two-fingers; neither is
      // ours, and reading one of them as a swipe is worse than ignoring both.
      if (tracking) {
        tracking = false;
        return;
      }
      if (startedAtEdge(e.clientX, width())) return;
      if (inHorizontalScroller(e.target as Element | null, node)) return;

      pointer = e.pointerId;
      x0 = lastX = e.clientX;
      y0 = lastY = e.clientY;
      t0 = lastT = e.timeStamp;
      tracking = true;
    };

    const move = (e: PointerEvent) => {
      if (!tracking || e.pointerId !== pointer) return;
      lastX = e.clientX;
      lastY = e.clientY;
      lastT = e.timeStamp;
    };

    /** Both endings, and a cancel is an ending — see the note above. */
    const finish = (e: PointerEvent) => {
      if (!tracking || e.pointerId !== pointer) return;
      tracking = false;

      // pointerup carries a position; pointercancel's is unreliable, and on
      // some builds repeats the last move. The recorded travel is the honest
      // one either way.
      const x = e.type === 'pointerup' ? e.clientX : lastX;
      const y = e.type === 'pointerup' ? e.clientY : lastY;
      const t = e.type === 'pointerup' ? e.timeStamp : lastT;

      const direction = swipeVerdict({
        dx: x - x0,
        dy: y - y0,
        elapsed: t - t0,
        width: width(),
      });
      if (direction) handler.current(direction);
    };

    const opts = { passive: true } as const;
    node.addEventListener('pointerdown', down, opts);
    node.addEventListener('pointermove', move, opts);
    node.addEventListener('pointerup', finish, opts);
    node.addEventListener('pointercancel', finish, opts);

    return () => {
      node.removeEventListener('pointerdown', down);
      node.removeEventListener('pointermove', move);
      node.removeEventListener('pointerup', finish);
      node.removeEventListener('pointercancel', finish);
    };
  }, [ref, enabled]);
}
