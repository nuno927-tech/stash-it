/**
 * Swiping between the three tabs.
 *
 * The decision of "was that a swipe" is here, pure, because it is entirely
 * made of thresholds and every one of them is a judgement that shows up as a
 * feel. Too eager and the list won't scroll without changing tabs; too strict
 * and the gesture feels broken. Numbers you can argue about in a test are
 * better than numbers buried in an event handler.
 */

import type { Tab } from '@/components/BottomNav';

export const TAB_ORDER: Tab[] = ['home', 'items', 'settings'];

export type Direction = 'left' | 'right';

/**
 * The tab a swipe lands on, or null at the ends.
 *
 * No wrapping. Settings → swipe left → Home would put you at the other end of
 * the app from a gesture that means "next", and the bottom bar is right there
 * showing you there is no next.
 */
export function nextTab(current: Tab, direction: Direction): Tab | null {
  const at = TAB_ORDER.indexOf(current);
  if (at === -1) return null;
  const to = at + (direction === 'left' ? 1 : -1);
  return TAB_ORDER[to] ?? null;
}

export interface Gesture {
  dx: number;
  dy: number;
  /** Milliseconds from first contact to release. */
  elapsed: number;
  /** Viewport width, so the threshold scales with the device. */
  width: number;
}

/**
 * Distance, or speed. A deliberate drag has to cross a fifth of the screen —
 * far enough that it can't be a stray thumb while reading. A flick doesn't:
 * it's short and fast on purpose, and demanding the same distance from it is
 * what makes a gesture feel heavy.
 */
export const MIN_FRACTION = 0.16;
export const MIN_PIXELS = 48;
export const FLICK_MS = 350;
export const FLICK_PIXELS = 36;

/**
 * Horizontal has to beat vertical. At 1.3 a diagonal scroll while skimming a
 * list still doesn't change tabs — the accident worth preventing — but a real
 * swipe made with the thumb's natural arc does.
 */
export const DOMINANCE = 1.3;

export function swipeVerdict(g: Gesture): Direction | null {
  const ax = Math.abs(g.dx);
  const ay = Math.abs(g.dy);

  if (ax < FLICK_PIXELS) return null;
  if (ax < ay * DOMINANCE) return null;

  const far = ax >= Math.max(MIN_PIXELS, g.width * MIN_FRACTION);
  const fast = g.elapsed <= FLICK_MS && ax >= FLICK_PIXELS;
  if (!far && !fast) return null;

  // Content follows the finger, so dragging left reveals what's to the right.
  return g.dx < 0 ? 'left' : 'right';
}

/**
 * The system back gesture owns the screen edges on Android, and a swipe that
 * starts there is already spoken for. Ours must not also fire, or one gesture
 * does two things.
 */
export const EDGE_GUARD = 26;

export function startedAtEdge(x: number, width: number): boolean {
  return x <= EDGE_GUARD || x >= width - EDGE_GUARD;
}

/**
 * True when the gesture began inside something that scrolls sideways itself —
 * the recently-added strip, a row of chips, the thumbnail strip. Those own
 * their own horizontal movement, and stealing it to change tabs would make
 * them unusable.
 */
export function inHorizontalScroller(target: Element | null, root: Element): boolean {
  let node: Element | null = target;
  while (node && node !== root) {
    if (node.scrollWidth > node.clientWidth + 4) {
      const overflow = getComputedStyle(node).overflowX;
      if (overflow === 'auto' || overflow === 'scroll') return true;
    }
    node = node.parentElement;
  }
  return false;
}
