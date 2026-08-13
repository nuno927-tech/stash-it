/**
 * Making the system Back gesture close what's open, instead of the app.
 *
 * The app navigates by state, not by URL, so as far as the browser is
 * concerned every screen is the same page. On Android, that means the back
 * swipe finds nothing to go back to and leaves the app — from the item detail,
 * from the add form, from a full-screen photo. It's the single most jarring
 * thing about using this on a phone: the gesture everyone uses to mean "up one
 * level" instead means "throw away what I was doing".
 *
 * The fix is to give the browser something to pop. Anything that can be closed
 * registers a handler and pushes one history entry; a single popstate listener
 * calls the topmost handler. When the stack is empty, back does what it always
 * did and leaves — which is correct, at the top level.
 *
 * Kept out of React because the history stack is global and singular, and two
 * components each with their own popstate listener would both fire on one
 * gesture and close two things at once.
 */

interface Entry {
  onBack: () => void;
}

const stack: Entry[] = [];

let listening = false;
/** Set when we call history.back() ourselves; that pop is bookkeeping. */
let selfPop = 0;

function onPopState(): void {
  if (selfPop > 0) {
    selfPop--;
    return;
  }
  stack.pop()?.onBack();
}

function listen(): void {
  if (listening || typeof window === 'undefined') return;
  window.addEventListener('popstate', onPopState);
  listening = true;
}

/**
 * Registers a back handler and takes a history entry for it.
 *
 * Returns a dismiss function for when the thing is closed some other way — a
 * Cancel button, a save, a tab change. Calling it drops the entry we took, so
 * the history depth always matches what's actually open. Not calling it means
 * the next back press appears to do nothing.
 */
export function pushBack(onBack: () => void): () => void {
  listen();

  const entry: Entry = { onBack };
  stack.push(entry);
  history.pushState({ stashDepth: stack.length }, '');

  return () => {
    const at = stack.indexOf(entry);
    // Already gone: the gesture fired and this is the close it caused.
    if (at === -1) return;
    stack.splice(at, 1);
    selfPop++;
    history.back();
  };
}

/**
 * Hands the topmost entry to a different screen, keeping its history entry.
 *
 * For a sideways move at the same depth: the add form saves and becomes the
 * item it just created. One screen replaces another, the stack is no deeper
 * and no shallower, and there is exactly one thing to go back from.
 *
 * Doing it as release-then-push instead would be a race. `history.back()` is
 * asynchronous; pushing a new entry before its popstate arrives leaves the
 * browser's depth and ours disagreeing, which is the bug this whole module
 * exists to avoid. Nothing needs to move — only the handler changes.
 *
 * Returns false when there was nothing to replace, so the caller can take an
 * entry properly rather than assume it has one.
 */
export function replaceTopBack(onBack: () => void): boolean {
  const top = stack[stack.length - 1];
  if (!top) return false;
  top.onBack = onBack;
  return true;
}

/**
 * Drops every entry at once, for a jump that isn't "up" — tapping a tab while
 * three screens deep. Without it, Back afterwards would walk you through
 * screens you've visibly left.
 */
export function clearBack(): void {
  const depth = stack.length;
  if (depth === 0) return;
  stack.length = 0;
  selfPop += depth;
  history.go(-depth);
}

/** Test seam. */
export function backDepth(): number {
  return stack.length;
}
