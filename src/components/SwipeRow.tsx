import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent, type ReactNode } from 'react';
import { feedback } from '@/lib/feedback';
import { ROW_REVEAL, rowOffset, rowOpens } from '@/lib/swipe';

/**
 * A list row you can push aside to reveal a delete button.
 *
 * Two steps on purpose. The swipe does not delete — it offers to. A gesture
 * that removed something outright would be a gesture you could make by
 * accident while scrolling a list with your thumb, and the thing it removes is
 * a record of something you own.
 *
 * A long press opens it too, because a swipe is invisible: nothing on a row
 * suggests it can be moved, and someone who has been told "hold it" will hold
 * it. Both land on the same open state.
 *
 * Only one row is open at a time — the parent passes `open` and is told when
 * this row wants it — so the screen never has three half-open rows on it and
 * "tap anywhere to close" has one obvious meaning.
 */
export function SwipeRow({
  open,
  onOpenChange,
  onDelete,
  deleteLabel,
  children,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onDelete: () => void;
  deleteLabel: string;
  children: ReactNode;
}) {
  const [dx, setDx] = useState(0);
  const drag = useRef<{ x: number; y: number; moved: boolean } | null>(null);
  const hold = useRef<number | undefined>(undefined);

  // Closing is always someone else's decision — another row opening, a tap
  // elsewhere — so the offset follows the prop rather than local state.
  useEffect(() => {
    if (!open) setDx(0);
  }, [open]);

  const clearHold = () => {
    if (hold.current) window.clearTimeout(hold.current);
    hold.current = undefined;
  };

  const down = (e: ReactPointerEvent) => {
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    drag.current = { x: e.clientX, y: e.clientY, moved: false };

    // 500ms is the platform's own long-press timing. Shorter and a slow tap
    // opens it; longer and it feels like the app didn't notice.
    clearHold();
    hold.current = window.setTimeout(() => {
      if (drag.current && !drag.current.moved) {
        feedback('tap');
        onOpenChange(true);
      }
    }, 500);
  };

  const move = (e: ReactPointerEvent) => {
    const from = drag.current;
    if (!from) return;

    const moveX = e.clientX - from.x;
    const moveY = e.clientY - from.y;
    if (!from.moved && Math.abs(moveX) + Math.abs(moveY) > 6) {
      from.moved = true;
      clearHold();
    }

    // A vertical drag is the list scrolling. Leave it alone, and don't hold on
    // to a gesture that clearly isn't ours.
    if (Math.abs(moveY) > Math.abs(moveX) && Math.abs(moveY) > 10) {
      drag.current = null;
      setDx(0);
      return;
    }

    if (from.moved) setDx(rowOffset(moveX, open) - (open ? -ROW_REVEAL : 0));
  };

  const up = (e: ReactPointerEvent) => {
    const from = drag.current;
    drag.current = null;
    clearHold();
    if (!from || !from.moved) return;

    const moveX = e.clientX - from.x;
    const moveY = e.clientY - from.y;
    setDx(0);

    if (!open && rowOpens(moveX, moveY)) {
      feedback('tap');
      onOpenChange(true);
    } else if (open && moveX > 20) {
      onOpenChange(false);
    }
  };

  const offset = open ? ROW_REVEAL : 0;

  return (
    <div className="swiperow">
      {/*
        Behind the row rather than beside it, so the row slides over the top
        and the button is revealed rather than pushed into place.
      */}
      <button
        type="button"
        className="swipedel"
        tabIndex={open ? 0 : -1}
        aria-hidden={!open}
        aria-label={deleteLabel}
        onClick={() => {
          feedback('delete');
          onDelete();
        }}
      >
        <svg
          width="19"
          height="19"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.9"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <path d="M4 7h16M9 7V5a1 1 0 011-1h4a1 1 0 011 1v2M6 7l1 13a1 1 0 001 1h8a1 1 0 001-1l1-13" />
          <path d="M10 11v6M14 11v6" />
        </svg>
        Delete
      </button>

      <div
        className="swipefront"
        style={{
          transform: `translateX(${-offset + dx}px)`,
          // Follows the finger exactly while dragging; springs only on release.
          transition: drag.current ? 'none' : 'transform 0.22s cubic-bezier(0.22, 1, 0.36, 1)',
        }}
        onPointerDown={down}
        onPointerMove={move}
        onPointerUp={up}
        onPointerCancel={() => {
          drag.current = null;
          clearHold();
          setDx(0);
        }}
        onContextMenu={(e) => {
          // A long press on a touch device raises this on some browsers; the
          // native menu on top of our own gesture is one thing too many.
          if (open) e.preventDefault();
        }}
      >
        {children}
      </div>
    </div>
  );
}
