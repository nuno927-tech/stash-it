import type { ReactNode } from 'react';

export type Tab = 'home' | 'items' | 'settings';

const ICONS: Record<Tab, ReactNode> = {
  home: <path d="M3 10l9-7 9 7v10a1 1 0 01-1 1h-5v-6H9v6H4a1 1 0 01-1-1z" />,
  items: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M3 9h18M9 20V9" />
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
  settings: 'Settings',
};

const TABS: Tab[] = ['home', 'items', 'settings'];

export function BottomNav({
  active,
  onChange,
  onAdd,
  addDisabled,
}: {
  active: Tab;
  onChange: (t: Tab) => void;
  onAdd?: () => void;
  addDisabled?: boolean;
}) {
  return (
    <nav className="nav">
      {onAdd && (
        <button
          type="button"
          className="fab"
          onClick={onAdd}
          disabled={addDisabled}
          aria-label={addDisabled ? 'Item limit reached' : 'Add an item'}
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
