import { useMemo, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItems, activeRooms } from '@/db/repo';
import type { Item } from '@/db/types';
import { matchSummary, searchItems } from '@/lib/search';
import { warrantyState } from '@/lib/warranty';
import { ItemRow } from '@/components/ItemRow';
import { Nutsy } from '@/components/Nutsy';

type Shortcut = 'ending' | 'expired' | 'nowarranty' | 'nodocs';

const SHORTCUTS: { key: Shortcut; label: string }[] = [
  { key: 'ending', label: 'Ending soon' },
  { key: 'expired', label: 'Expired' },
  { key: 'nowarranty', label: 'No warranty recorded' },
  { key: 'nodocs', label: 'Missing documents' },
];

export function Search({
  propertyId,
  onOpenItem,
}: {
  propertyId: string;
  onOpenItem: (id: string) => void;
}) {
  const [query, setQuery] = useState('');
  const [shortcut, setShortcut] = useState<Shortcut | null>(null);

  const items = useLiveQuery(() => activeItems(propertyId), [propertyId]) ?? [];
  const rooms = useLiveQuery(() => activeRooms(propertyId), [propertyId]) ?? [];
  const docs = useLiveQuery(() => db.docs.toArray(), []) ?? [];

  const hits = useMemo(
    () => searchItems(query, { items, docs, rooms }),
    [query, items, docs, rooms],
  );

  const shortlist = useMemo(
    () => (shortcut ? items.filter(matcherFor(shortcut, docs)) : []),
    [shortcut, items, docs],
  );

  const searching = query.trim().length > 0;

  return (
    <>
      <header className="apphead">
        <div className="apptitle">Search</div>
      </header>

      <div className="searchbar">
        <svg
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          aria-hidden="true"
        >
          <circle cx="11" cy="11" r="7" />
          <path d="M20 20l-4-4" />
        </svg>
        <input
          type="search"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setShortcut(null);
          }}
          placeholder="Name, brand, serial, room…"
          autoComplete="off"
          // eslint-disable-next-line jsx-a11y/no-autofocus
          autoFocus
        />
        {query && (
          <button type="button" className="iconbtn small" onClick={() => setQuery('')} aria-label="Clear">
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
            >
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          </button>
        )}
      </div>

      {!searching && (
        <div className="chiprow">
          {SHORTCUTS.map((s) => (
            <button
              key={s.key}
              type="button"
              className={`pick${shortcut === s.key ? ' on' : ''}`}
              onClick={() => setShortcut(shortcut === s.key ? null : s.key)}
            >
              {s.label}
            </button>
          ))}
        </div>
      )}

      {searching ? (
        hits.length === 0 ? (
          <div className="empty" style={{ paddingTop: 40 }}>
            <Nutsy pose="stand" height={130} motion={['float']} shadow />
            <h3>Nothing found</h3>
            <p>
              Nutsy looked through names, brands, models, serials, rooms, notes and document titles.
            </p>
          </div>
        ) : (
          <>
            <div className="seclabel">
              <span>Results</span>
              <span>
                {hits.length} {hits.length === 1 ? 'item' : 'items'}
              </span>
            </div>
            {hits.map((hit) => {
              const why = matchSummary(hit);
              return (
                <div key={hit.item.id}>
                  <ItemRow item={hit.item} onOpen={onOpenItem} />
                  {why && <p className="why">{why}</p>}
                </div>
              );
            })}
          </>
        )
      ) : shortcut ? (
        <>
          <div className="seclabel">
            <span>{SHORTCUTS.find((s) => s.key === shortcut)?.label}</span>
            <span>{shortlist.length}</span>
          </div>
          {shortlist.length === 0 ? (
            <p className="hint">Nothing here — which is the answer you wanted.</p>
          ) : (
            shortlist.map((item) => <ItemRow key={item.id} item={item} onOpen={onOpenItem} />)
          )}
        </>
      ) : (
        <p className="hint">
          Search across names, brands, models, serial numbers, retailers, rooms, notes and the
          titles of anything you've attached. Partial serials work.
        </p>
      )}
    </>
  );
}

function matcherFor(shortcut: Shortcut, docs: { itemId: string; deletedAt?: string }[]) {
  const withDocs = new Set(docs.filter((d) => !d.deletedAt).map((d) => d.itemId));

  return (item: Item): boolean => {
    switch (shortcut) {
      case 'ending':
        return warrantyState(item) === 'ending-soon';
      case 'expired':
        return warrantyState(item) === 'expired';
      case 'nowarranty':
        return warrantyState(item) === 'unknown';
      case 'nodocs':
        return !withDocs.has(item.id);
    }
  };
}
