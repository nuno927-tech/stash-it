import { useEffect, useRef, type RefObject } from 'react';

/**
 * Scroll the next section into view once a section is finished with.
 *
 * The intent is that answering the last question in a card should take you to
 * the next one, so a long form is a sequence rather than a scroll. The risk is
 * that moving the page under someone is one of the most unpleasant things an
 * interface can do, so this is deliberately narrow:
 *
 *  - ONCE PER SECTION. It fires on the false → true edge and then latches. A
 *    card you complete, edit, and complete again does not throw you forward a
 *    second time.
 *
 *  - NOT ON ARRIVAL. Opening an already-complete record — every edit, ever —
 *    would otherwise scroll straight past the thing you came to change. The
 *    first render is recorded and never acted on.
 *
 *  - NOT WHILE TYPING. Callers pass `complete` from discrete choices — a
 *    service picked, a cadence chosen, a date set — not from text length. A
 *    form that jumps when you pause mid-word is worse than one that never
 *    moves at all.
 *
 *  - NOT IF THE KEYBOARD IS UP. `document.activeElement` being a text field
 *    means the person is still working; scrolling then hides what they're
 *    looking at behind the keyboard.
 *
 * `prefers-reduced-motion` downgrades the animation, not the behaviour: the
 * jump still happens, it just doesn't slide.
 */
export function useAutoAdvance(complete: boolean, next: RefObject<HTMLElement | null>): void {
  const fired = useRef(false);
  const mounted = useRef(false);

  useEffect(() => {
    if (!mounted.current) {
      mounted.current = true;
      // Arriving complete is not the same as becoming complete.
      if (complete) fired.current = true;
      return;
    }

    if (!complete || fired.current) return;

    const active = document.activeElement;
    const typing =
      active instanceof HTMLInputElement || active instanceof HTMLTextAreaElement
        ? active.type !== 'date' && active.type !== 'checkbox'
        : false;
    if (typing) return;

    fired.current = true;

    const node = next.current;
    if (!node) return;

    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    // A beat, so the tap that completed the section is seen to land before the
    // page moves. Without it the two read as one event and the movement looks
    // like a mis-tap.
    const timer = window.setTimeout(() => {
      node.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'start' });
    }, 220);

    return () => window.clearTimeout(timer);
  }, [complete, next]);
}
