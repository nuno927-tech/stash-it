import { useEffect, useRef, type RefObject } from 'react';

/**
 * Scroll the next section into view once a section is finished with.
 *
 * The intent is that answering the last question in a card should take you to
 * the next one, so a long form is a sequence rather than a scroll. The risk is
 * that moving the page under someone is one of the most unpleasant things an
 * interface can do, so this is deliberately narrow:
 *
 *  - EVERY FIELD IN THE CARD, not the interesting one. This is the rule that
 *    was wrong first time round. Each caller watched the field that mattered
 *    most — the expiry date, the service, the room — so setting that one field
 *    threw you forward past three others you hadn't touched yet. "Answering
 *    the last question" has to mean the last question, and a card is not
 *    finished because its most important answer arrived. Callers pass
 *    `cardFilled(...)` listing everything in the section, so the predicate is
 *    a visible inventory rather than someone's judgement about which fields
 *    count.
 *
 *    The cost is real and worth it: a card holding an optional Notes box will
 *    now almost never advance. A convenience that fires rarely is strictly
 *    better than one that fires while you are still working.
 *
 *  - ONCE PER SECTION. It fires on the false → true edge and then latches. A
 *    card you complete, edit, and complete again does not throw you forward a
 *    second time.
 *
 *  - NOT ON ARRIVAL. Opening an already-complete record — every edit, ever —
 *    would otherwise scroll straight past the thing you came to change. The
 *    first render is recorded and never acted on.
 *
 *  - NOT IF THE KEYBOARD IS UP. `document.activeElement` being a text field
 *    means the person is still working; scrolling then hides what they're
 *    looking at behind the keyboard. This is also what keeps a text field from
 *    advancing the page mid-word now that typing can complete a card.
 *
 * `prefers-reduced-motion` downgrades the animation, not the behaviour: the
 * jump still happens, it just doesn't slide.
 */
/**
 * True when every field listed has something in it.
 *
 * Call it with the card's whole contents — including the optional ones. The
 * point is that the caller has to write the inventory down, so adding a field
 * to a card and forgetting it here is visible in the diff rather than silent
 * on the phone.
 *
 * Strings are trimmed, so a space bar is not an answer. Booleans pass through
 * for the controls that aren't text: a chosen room, a picked toggle.
 */
export function cardFilled(...fields: (string | boolean | null | undefined)[]): boolean {
  return fields.every((f) => (typeof f === 'string' ? f.trim().length > 0 : !!f));
}

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
