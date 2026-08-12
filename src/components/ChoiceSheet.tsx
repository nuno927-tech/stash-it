import { useEffect, type ReactNode } from 'react';
import { pushBack } from '@/lib/backstack';

export interface Choice {
  key: string;
  label: string;
  note?: string;
  icon?: ReactNode;
}

/**
 * A short question, asked as a bottom sheet.
 *
 * For the cases where two controls sat side by side because the app couldn't
 * be bothered to ask — a photo slot with a camera button welded to its corner,
 * say. Two half-labelled targets in the space of one is harder to read than a
 * single clear button and one question, and the question can afford to say
 * what each option actually does.
 *
 * Anchored to the bottom because that's where the thumb is, and dismissible by
 * the system back gesture like everything else that can be closed.
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

  return (
    <div
      className="sheetscrim"
      role="dialog"
      aria-modal="true"
      aria-label={title}
      onClick={onCancel}
    >
      {/* The scrim closes; the card must not close when tapped through. */}
      <div className="sheetcard" onClick={(e) => e.stopPropagation()}>
        <span className="lockgrip" aria-hidden="true" />
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
    </div>
  );
}
