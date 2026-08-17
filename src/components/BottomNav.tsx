import { useEffect, useRef, useState, type ReactNode } from 'react';
import { pushBack } from '@/lib/backstack';
import { feedback } from '@/lib/feedback';

export type Tab = 'home' | 'items' | 'subs' | 'papers' | 'settings';

/** What the + can create. Adding a fourth later means one entry here. */
export type AddKind = 'item' | 'subscription' | 'paper';

/*
 * Scout's world, at 26px.
 *
 * The set was a generic house, drawer, calendar and cog — correct, and from a
 * different app. These are an oak, a hoard, a season and a nut, which is the
 * same four ideas told by a squirrel.
 *
 * THE SIZE AND THE STROKE GO TOGETHER. A stroke scales with its viewBox, so
 * simply drawing an icon larger buys no detail at all — everything grows in
 * proportion and the composition is exactly as legible as it was. What buys
 * detail is the *ratio* of pen to picture, so these went from 21px at stroke
 * 2.0 to 26px at 1.7. That is what makes the hollow in the tree a hollow
 * rather than a filled dot.
 *
 * Three acorns were drawn and rejected: at 26px each one is nine pixels tall
 * and the pile reads as texture. The budget for a three-object composition is
 * around 34px, which a nav bar does not have. Two acorns still say "several".
 */
const ICONS: Record<Tab, ReactNode> = {
  // An oak with a hollow in it — where a squirrel actually lives, rather than
  // a house with a chimney.
  home: (
    <>
      <path d="M12 3.2c-3.1 0-5.4 2.2-5.4 4.8 0 .8.2 1.5.7 2.1-1.3.8-2 1.9-2 3.1 0 2.2 2 3.9 4.6 3.9h4.2c2.6 0 4.6-1.7 4.6-3.9 0-1.2-.7-2.3-2-3.1.5-.6.7-1.3.7-2.1 0-2.6-2.3-4.8-5.4-4.8z" />
      <circle cx="12" cy="12" r="2.4" />
      <path d="M12 17.1V21" />
    </>
  ),
  // The hoard. Two, not three — see above.
  items: (
    <>
      <path d="M4.2 10.6c0-1.5 1.7-2.7 3.8-2.7s3.8 1.2 3.8 2.7z" />
      <path d="M4.2 10.6h7.6" />
      <path d="M5.4 10.6c0 3.3 1.2 5.7 2.6 5.7s2.6-2.4 2.6-5.7" />
      <path d="M12.6 15.2c0-1.3 1.4-2.3 3.2-2.3s3.2 1 3.2 2.3z" />
      <path d="M12.6 15.2h6.4" />
      <path d="M13.6 15.2c0 2.8 1 4.8 2.2 4.8s2.2-2 2.2-4.8" />
    </>
  ),
  /*
    An acorn that comes round again. There is no squirrel-native symbol for
    "every month", so the two-arrow cycle carries the meaning — everyone
    already reads it — and the acorn inside makes it ours without touching the
    part doing the work.
  */
  subs: (
    <>
      <path d="M20.4 12a8.4 8.4 0 01-13.6 6.6" />
      <path d="M3.6 12a8.4 8.4 0 0113.6-6.6" />
      <path d="M3.4 8.2v3.8h3.8M20.6 15.8V12h-3.8" />
      <path d="M9.4 10.4c0-1.2 1.2-2.1 2.6-2.1s2.6.9 2.6 2.1z" />
      <path d="M9.4 10.4h5.2M10.3 10.4c0 2.4.8 4.1 1.7 4.1s1.7-1.7 1.7-4.1" />
    </>
  ),
  /*
    A leaf, veined.

    The one place the squirrel theme and the subject matter meet on their own:
    a leaf IS a page, in the oldest sense of the word, and it belongs on a tree
    with the acorns. A document glyph would have been clearer for two seconds
    and generic forever — and a folded sheet at 26px next to two acorns and a
    tree reads as the icon somebody forgot to theme.
  */
  papers: (
    <>
      <path d="M5.2 18.8c-2.4-4.6-.6-11 4.2-13.4 2.6-1.3 6-1.4 9.4-.6.5 3.4.2 6.8-1.2 9.4-2.6 4.8-9 6.6-12.4 4.6z" />
      <path d="M4 20.4c1.6-3.4 4.6-6.6 8.4-8.8" />
      <path d="M11 9.6c1.1.5 2 1.4 2.6 2.6M8.2 13.4c1 .5 1.8 1.3 2.3 2.3" />
    </>
  ),
  // A nut, in both senses. The pun is free and the hexagon is the most robust
  // shape in the set — it was legible at 21px and it is legible at 12.
  settings: (
    <>
      <path d="M12 2.8 20 7.4v9.2L12 21.2 4 16.6V7.4z" />
      <circle cx="12" cy="12" r="3" />
    </>
  ),
};

const LABELS: Record<Tab, string> = {
  home: 'Home',
  items: 'Items',
  subs: 'Subs',
  papers: 'Papers',
  settings: 'Settings',
};

const TABS: Tab[] = ['home', 'items', 'subs', 'papers', 'settings'];

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
  {
    kind: 'paper',
    label: 'Paper',
    note: 'Something that expires',
    glyph: (
      <>
        <path d="M6 3h9l4 4v14H6z" />
        <path d="M15 3v4h4M9.5 12h6M9.5 16h4" />
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
                /*
                  The one nearest the button moves first, so the stack unfolds
                  upward from where you tapped rather than arriving as a block.
                  Reversed on the way out for the same reason.
                */
                style={{
                  transitionDelay: open
                    ? `${(ADD_KINDS.length - 1 - i) * 45}ms`
                    : `${i * 30}ms`,
                }}
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
            {/* 26 at 1.7, not 21 at 2.0 — see the note on ICONS. */}
            <svg
              width="26"
              height="26"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.7"
              strokeLinecap="round"
              strokeLinejoin="round"
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
