import { useEffect, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { pushBack } from '@/lib/backstack';

export interface Choice {
  key: string;
  label: string;
  note?: string;
  icon?: ReactNode;
}

/**
 * A short question, asked as a card in the middle of the screen.
 *
 * ── Why this is a portal ──────────────────────────────────────────────────
 * It was rendered where it was used, inside the item form, and appeared at the
 * bottom of the scrolled page instead of over it: you had to scroll to find
 * the dialog. `position: fixed` is only fixed to the viewport when no ancestor
 * establishes a containing block, and a transform, filter or animation
 * anywhere up the tree quietly does. The form is inside an animated screen
 * wrapper inside a scrolling body, so the odds of that were always high — and
 * the failure is invisible until it happens on a long page.
 *
 * Rendering into document.body removes the question entirely. There is no
 * ancestor left to be relative to.
 *
 * Centred, not bottom-anchored: with two options and a cancel there isn't
 * enough content to justify a sheet, and the middle of the screen is where
 * your eyes already are.
 */
export function ChoiceSheet({
  title,
  choices,
  onPick,
  onCancel,
}: {
  title: string;
  choices: Choice[];
  onPick: (key: string) => void;
  onCancel: () => void;
}) {
  useEffect(() => pushBack(onCancel), [onCancel]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onCancel();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onCancel]);

  return createPortal(
    <div
      className="sheetscrim"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onClick={onCancel}
    >
      {/* The scrim closes; the card must not close when tapped through. */}
      <div className="sheetcard" onClick={(e) => e.stopPropagation()}>
        <h4>{title}</h4>

        {choices.map((c) => (
          <button key={c.key} type="button" className="choice" onClick={() => onPick(c.key)}>
            {c.icon && <span className="choice-icon">{c.icon}</span>}
            <span className="choice-txt">
              <b>{c.label}</b>
              {c.note && <span>{c.note}</span>}
            </span>
          </button>
        ))}

        <button type="button" className="btn ghost" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </div>,
    document.body,
  );
}
