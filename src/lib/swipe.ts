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

/*
  Every tab, in bar order. Subscriptions was added to the bar and not to this
  list, so swiping left from Items landed on Settings — it skipped the tab
  sitting between them and there was nothing on screen to explain why.
*/
export const TAB_ORDER: Tab[] = ['home', 'items', 'subs', 'papers', 'settings'];

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
 * Which way "back" is.
 *
 * Content follows the finger, so dragging right reveals what's to the left of
 * the screen — which is where you came from. Named rather than written as a
 * literal in the shell because it has to agree with the sign convention in
 * `swipeVerdict`, and those two live in different files.
 */
export const BACK_DIRECTION: Direction = 'right';

/* ------------------------------------------------ swiping a row aside */

/**
 * How far a list row slides to show the delete button behind it.
 *
 * Half the row, roughly — far enough that the button is a comfortable target
 * and that the row plainly hasn't gone anywhere. A row that slid clean off
 * would be a delete, and this is not a delete: it is the offer of one.
 */
export const ROW_REVEAL = 96;

/**
 * Past this, letting go opens the row rather than springing it shut.
 *
 * Deliberately less than half of ROW_REVEAL. Opening costs nothing — the row
 * comes back on the next tap anywhere — so the gesture should succeed on a
 * hesitant drag rather than demand a confident one.
 */
export const ROW_OPEN_AT = 34;

/**
 * Only leftwards, and only when it's clearly not a scroll.
 *
 * Strictly past the threshold, not at it — "past this" in the constant's own
 * description, and a boundary that reads one way in prose and another in code
 * is a boundary somebody will get wrong later.
 */
export function rowOpens(dx: number, dy: number): boolean {
  if (dx >= -ROW_OPEN_AT) return false;
  return Math.abs(dx) >= Math.abs(dy) * DOMINANCE;
}

/** Where the row sits mid-drag: never right of home, never past the button. */
export function rowOffset(dx: number, open: boolean): number {
  const from = open ? -ROW_REVEAL : 0;
  return Math.max(-ROW_REVEAL, Math.min(0, from + dx));
}

/* ------------------------------------------------- throwing a card away */

/**
 * A drag that means "get this out of my way".
 *
 * Either direction. The card it dismisses is centred rather than anchored to
 * an edge, so there is no correct way to throw it — insisting on downwards
 * would only teach people the gesture doesn't work.
 *
 * Looser than the tab swipe on purpose. Changing tabs by accident loses your
 * place; closing a reminder by accident costs nothing, and the reminder is
 * shown after every single save. When the failure is that asymmetric, the
 * threshold should be too.
 *
 * "Looser" means under MIN_PIXELS, not merely under the tab swipe's effective
 * threshold on a phone. That one scales with the screen and the floor doesn't,
 * so only beating the floor makes the claim true on every device rather than
 * on the handset it happened to be tuned against. A test holds it to that.
 */
export const DISMISS_PIXELS = 44;
export const DISMISS_FLICK_PIXELS = 24;

export interface Drag {
  dy: number;
  /** Milliseconds from first contact to release. */
  elapsed: number;
}

export function dismissedByDrag({ dy, elapsed }: Drag): boolean {
  const ay = Math.abs(dy);
  if (ay >= DISMISS_PIXELS) return true;
  return elapsed <= FLICK_MS && ay >= DISMISS_FLICK_PIXELS;
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
 * Marks an element whose horizontal drags belong to it, not to the shell.
 *
 * A list row that slides aside to show a delete button is doing the same thing
 * the tab swipe does, at the same time, with the same finger — so one of them
 * has to stand down, and it has to be the one that isn't under the thumb. The
 * row opts out by carrying this attribute; nothing else has to know.
 */
export const OWNS_SWIPE = 'data-owns-swipe';

export function ownsItsSwipe(target: Element | null, root: Element): boolean {
  let node: Element | null = target;
  while (node && node !== root) {
    if (node.hasAttribute(OWNS_SWIPE)) return true;
    node = node.parentElement;
  }
  return false;
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
