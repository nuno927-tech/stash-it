import { useEffect, useRef, useState, type ReactNode } from 'react';
import { pushBack } from '@/lib/backstack';
import { feedback } from '@/lib/feedback';

export type Tab = 'home' | 'items' | 'subs' | 'settings';

/** What the + can create. Adding a third later means one entry here. */
export type AddKind = 'item' | 'subscription';

const ICONS: Record<Tab, ReactNode> = {
  home: <path d="M3 10l9-7 9 7v10a1 1 0 01-1 1h-5v-6H9v6H4a1 1 0 01-1-1z" />,
  items: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M3 9h18M9 20V9" />
    </>
  ),
  subs: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M3 10h18M8 3v4M16 3v4" />
      <circle cx="8.5" cy="14.5" r="1.1" fill="currentColor" stroke="none" />
      <circle cx="15.5" cy="17.5" r="1.1" fill="currentColor" stroke="none" />
    </>
  ),
  settings: (
    <>
      <circle cx="12" cy="12" r="3.2" />
      <path d="M19.4 15a1.6 1.6 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.6 1.6 0 00-2.7 1.1v.3a2 2 0 11-4 0V21a1.6 1.6 0 00-2.8-1.1l-.1.1a2 2 0 11-2.8-2.8l.1-.1A1.6 1.6 0 003 15a2 2 0 010-4 1.6 1.6 0 001.1-2.8l-.1-.1a2 2 0 112.8-2.8l.1.1A1.6 1.6 0 0010 4.3V4a2 2 0 014 0v.3a1.6 1.6 0 002.7 1.1l.1-.1a2 2 0 112.8 2.8l-.1.1A1.6 1.6 0 0021 11a2 2 0 010 4z" />
    </>
  ),
};

const LABELS: Record<Tab, string> = {
  home: 'Home',
  items: 'Items',
  subs: 'Subs',
  settings: 'Settings',
};

const TABS: Tab[] = ['home', 'items', 'subs', 'settings'];

/**
 * What the + offers, in the order it offers them.
 *
 * A list rather than two hard-coded buttons, because the whole reason for
 * making the button expand — instead of asking "product or subscription?" in a
 * dialog — is that a third and fourth kind are coming. Adding one should be a
 * line here and nothing else.
 */
const ADD_KINDS: { kind: AddKind; label: string; note: string; glyph: ReactNode }[] = [
  {
    kind: 'item',
    label: 'Product',
    note: 'Something you own',
    glyph: (
      <>
        <rect x="3" y="7" width="18" height="13" rx="2" />
        <path d="M8 7V5a2 2 0 012-2h4a2 2 0 012 2v2" />
      </>
    ),
  },
  {
    kind: 'subscription',
    label: 'Subscription',
    note: 'Something you pay for',
    glyph: (
      <>
        <rect x="3" y="5" width="18" height="16" rx="2" />
        <path d="M3 10h18M8 3v4M16 3v4" />
      </>
    ),
  },
];

export function BottomNav({
  active,
  onChange,
  onAdd,
  addDisabled,
}: {
  active: Tab;
  onChange: (t: Tab) => void;
  onAdd?: (kind: AddKind) => void;
  addDisabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const close = useRef(() => setOpen(false));

  // System back closes the menu rather than leaving the screen behind it.
  useEffect(() => {
    if (!open) return;
    return pushBack(close.current);
  }, [open]);

  const pick = (kind: AddKind) => {
    setOpen(false);
    feedback('tap');
    onAdd?.(kind);
  };

  return (
    <nav className="nav">
      {onAdd && (
        <>
          {/*
            The scrim is what makes this a menu rather than two buttons that
            happened to appear. It also gives the gesture an undo: anywhere
            else on the screen puts it away.
          */}
          {open && (
            <button
              type="button"
              className="addscrim"
              aria-label="Close"
              onClick={() => setOpen(false)}
            />
          )}

          <div className={`addstack${open ? ' open' : ''}`}>
            {/*
              Rendered whether or not it's open, so the springs run on a real
              transition rather than on mount. Mounting into the final position
              gives you a pop; transitioning from a collapsed one gives you the
              settle. `inert` keeps the collapsed buttons out of the tab order
              and away from a screen reader.
            */}
            {ADD_KINDS.map((k, i) => (
              <button
                key={k.kind}
                type="button"
                className="addchoice"
                // Each one leaves a beat after the one below it, so they read
                // as a stack unfolding rather than as a block appearing.
                style={{ transitionDelay: open ? `${i * 45}ms` : `${(ADD_KINDS.length - 1 - i) * 30}ms` }}
                tabIndex={open ? 0 : -1}
                aria-hidden={!open}
                onClick={() => pick(k.kind)}
              >
                <span className="addchoice-ico">
                  <svg
                    width="17"
                    height="17"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.9"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    {k.glyph}
                  </svg>
                </span>
                <span className="addchoice-txt">
                  <strong>{k.label}</strong>
                  <small>{k.note}</small>
                </span>
              </button>
            ))}
          </div>

          <button
            type="button"
            className={`fab${open ? ' open' : ''}`}
            onClick={() => {
              feedback('tap');
              setOpen((o) => !o);
            }}
            disabled={addDisabled}
            aria-expanded={open}
            aria-label={addDisabled ? 'Item limit reached' : open ? 'Close' : 'Add something'}
          >
            <svg
              width="19"
              height="19"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.6"
              strokeLinecap="round"
            >
              <path d="M12 5v14M5 12h14" />
            </svg>
            Stash it
          </button>
        </>
      )}

      {TABS.map((t) => (
        <button
          key={t}
          type="button"
          className={`navitem${t === active ? ' active' : ''}`}
          onClick={() => onChange(t)}
          aria-current={t === active ? 'page' : undefined}
        >
          <span className="navpill">
            <svg
              width="21"
              height="21"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
            >
              {ICONS[t]}
            </svg>
          </span>
          {LABELS[t]}
        </button>
      ))}
    </nav>
  );
}
