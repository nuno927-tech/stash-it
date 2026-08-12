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
 * Listeners are attached to the DOM node rather than expressed as React props
 * so the move handler can be passive: React attaches everything actively, and
 * a non-passive `pointermove`/`touchmove` on a scrolling container costs a
 * frame on every scroll. This runs on the element the user's thumb is on for
 * the whole life of the app, so that matters.
 *
 * Nothing is ever preventDefault-ed. The gesture is recognised on release, so
 * scrolling stays entirely the browser's until the moment we act — which is
 * what stops it feeling like the page is fighting the finger.
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
    let tracking = false;

    const down = (e: PointerEvent) => {
      // Mouse drags on desktop are how people select text, not how they
      // navigate; touch and pen only.
      if (e.pointerType === 'mouse') return;

      const width = node.clientWidth || window.innerWidth;
      if (startedAtEdge(e.clientX, width)) return;
      if (inHorizontalScroller(e.target as Element | null, node)) return;

      x0 = e.clientX;
      y0 = e.clientY;
      t0 = e.timeStamp;
      tracking = true;
    };

    const up = (e: PointerEvent) => {
      if (!tracking) return;
      tracking = false;

      const direction = swipeVerdict({
        dx: e.clientX - x0,
        dy: e.clientY - y0,
        elapsed: e.timeStamp - t0,
        width: node.clientWidth || window.innerWidth,
      });
      if (direction) handler.current(direction);
    };

    const cancel = () => {
      tracking = false;
    };

    node.addEventListener('pointerdown', down, { passive: true });
    node.addEventListener('pointerup', up, { passive: true });
    node.addEventListener('pointercancel', cancel, { passive: true });

    return () => {
      node.removeEventListener('pointerdown', down);
      node.removeEventListener('pointerup', up);
      node.removeEventListener('pointercancel', cancel);
    };
  }, [ref, enabled]);
}
