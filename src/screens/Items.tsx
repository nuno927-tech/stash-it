import { useMemo, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItems, activeRooms } from '@/db/repo';
import type { Item } from '@/db/types';
import { prefsFrom } from '@/lib/prefs';
import { matchSummary, searchItems } from '@/lib/search';
import { effectiveExpiry, warrantyState } from '@/lib/warranty';
import { ItemRow } from '@/components/ItemRow';
import { Scout } from '@/components/Scout';
import { RoomIcon } from '@/components/RoomIcon';

export type ItemsFilter =
  | 'ending'
  | 'expired'
  | 'nopaperwork'
  | 'noreceipt'
  | 'nowarranty'
  | 'nodate'
  | 'nophoto';

const FILTER_LABEL: Record<ItemsFilter, string> = {
  ending: 'Ending soon',
  expired: 'Lapsed',
  nopaperwork: 'No proof of purchase',
  noreceipt: 'No receipt',
  nowarranty: 'No warranty length',
  nodate: 'No purchase date',
  nophoto: 'No photo',
};

type Sort = 'room' | 'name' | 'expiry' | 'recent';

const SORT_LABEL: Record<Sort, string> = {
  room: 'Room',
  name: 'A–Z',
  expiry: 'Expiring',
  recent: 'Newest',
};

const UNASSIGNED = '\0unassigned';

/**
 * The inventory, grouped by room by default — that's how people picture their
 * own house, and it makes "what's in the garage" a scroll rather than a query.
 * Search lives here too now, rather than in its own tab: searching is a way of
 * filtering this list, not a separate place to be.
 */
export function Items({
  propertyId,
  filter,
  onOpenItem,
  onAdd,
}: {
  propertyId: string;
  filter?: ItemsFilter;
  onOpenItem: (id: string) => void;
  onAdd: () => void;
}) {
  const items = useLiveQuery(() => activeItems(propertyId), [propertyId]);
  const rooms = useLiveQuery(() => activeRooms(propertyId), [propertyId]) ?? [];
  const docs = useLiveQuery(() => db.docs.toArray(), []) ?? [];
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const startCollapsed = prefsFrom(settings).roomsView === 'collapsed';

  const [query, setQuery] = useState('');
  // Expiring first, by default. Grouping by room answers "what's in the
  // garage", which is a question you ask occasionally; "what needs me this
  // month" is the one the app exists for, and it should not need a tap.
  const [sort, setSort] = useState<Sort>('expiry');
  const [active, setActive] = useState<ItemsFilter | undefined>(filter);

  // Which rooms the user has toggled away from the default this session.
  // Storing the exceptions rather than the state means changing the setting
  // takes effect immediately, without fighting whatever was toggled earlier.
  const [flipped, setFlipped] = useState<Set<string>>(new Set());
  const isOpen = (key: string) => (startCollapsed ? flipped.has(key) : !flipped.has(key));
  const toggle = (key: string) =>
    setFlipped((set) => {
      const next = new Set(set);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });

  const all = useMemo(() => items ?? [], [items]);
  const searching = query.trim().length > 0;

  const hits = useMemo(
    () => (searching ? searchItems(query, { items: all, docs, rooms }) : []),
    [searching, query, all, docs, rooms],
  );

  const filtered = useMemo(() => {
    if (!active) return all;
    const live = docs.filter((d) => !d.deletedAt);
    const withProof = new Set(
      live.filter((d) => d.kind === 'receipt' || d.kind === 'warranty').map((d) => d.itemId),
    );
    const withReceipt = new Set(live.filter((d) => d.kind === 'receipt').map((d) => d.itemId));

    return all.filter((i) => {
      switch (active) {
        case 'ending':
          return warrantyState(i) === 'ending-soon';
        case 'expired':
          return warrantyState(i) === 'expired';
        case 'noreceipt':
          return !withReceipt.has(i.id);
        case 'nowarranty':
          return warrantyState(i) === 'unknown';
        case 'nodate':
          return !i.purchaseDate;
        case 'nophoto':
          return !i.thumbBlobId;
        default:
          return !withProof.has(i.id);
      }
    });
  }, [all, active, docs]);

  const groups = useMemo(() => groupItems(filtered, rooms, sort), [filtered, rooms, sort]);

  if (!items) return null;

  if (all.length === 0) {
    return (
      <div className="empty">
        <Scout pose="stand" height={170} motion={['float']} shadow />
        <h3>Nothing stashed yet</h3>
        <p>Everything you add shows up here, grouped by the room it lives in.</p>
        <button type="button" className="btn" onClick={onAdd}>
          Add an item
        </button>
      </div>
    );
  }

  return (
    <>
      <header className="apphead">
        <div className="apptitle">Items</div>
        <span className="countpill">{all.length}</span>
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
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search name, brand, serial…"
          autoComplete="off"
          aria-label="Search items"
        />
        {query && (
          <button
            type="button"
            className="iconbtn small"
            onClick={() => setQuery('')}
            aria-label="Clear search"
          >
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

      {searching ? (
        <SearchResults hits={hits} onOpenItem={onOpenItem} />
      ) : (
        <>
          <div className="chiprow">
            {(Object.keys(SORT_LABEL) as Sort[]).map((s) => (
              <button
                key={s}
                type="button"
                className={`pick${sort === s ? ' on' : ''}`}
                onClick={() => setSort(s)}
              >
                {SORT_LABEL[s]}
              </button>
            ))}
          </div>

          {active && (
            <button type="button" className="activefilter" onClick={() => setActive(undefined)}>
              {FILTER_LABEL[active]} · {filtered.length} of {all.length}
              <span aria-hidden="true">×</span>
            </button>
          )}

          {filtered.length === 0 ? (
            <p className="hint">Nothing matches that.</p>
          ) : (
            groups.map((g) =>
              g.title === null ? (
                <section key={g.key}>
                  {g.items.map((item) => (
                    <ItemRow key={item.id} item={item} onOpen={onOpenItem} />
                  ))}
                </section>
              ) : (
                <section key={g.key} className="roomgroup">
                  {/*
                    The tile is the disclosure. Collapsed, the icon and the
                    count answer "what's in the garage" without scrolling past
                    everything else in the house.
                  */}
                  <button
                    type="button"
                    className={`roomtile${isOpen(g.key) ? ' open' : ''}`}
                    aria-expanded={isOpen(g.key)}
                    onClick={() => toggle(g.key)}
                  >
                    <span className="roomtile-icon">
                      <RoomIcon name={g.title} size={26} />
                    </span>
                    <span className="roomtile-txt">
                      <strong>{g.title}</strong>
                      <small>
                        {g.items.length} {g.items.length === 1 ? 'item' : 'items'}
                      </small>
                    </span>
                    <svg
                      className="roomtile-go"
                      width="18"
                      height="18"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2.2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      aria-hidden="true"
                    >
                      <path d="M6 9l6 6 6-6" />
                    </svg>
                  </button>

                  {isOpen(g.key) && (
                    <div className="roomitems">
                      {g.items.map((item) => (
                        <ItemRow key={item.id} item={item} onOpen={onOpenItem} />
                      ))}
                    </div>
                  )}
                </section>
              ),
            )
          )}
        </>
      )}
    </>
  );
}

function SearchResults({
  hits,
  onOpenItem,
}: {
  hits: ReturnType<typeof searchItems>;
  onOpenItem: (id: string) => void;
}) {
  if (hits.length === 0) {
    return (
      <div className="empty" style={{ paddingTop: 30 }}>
        <Scout pose="stand" height={120} motion={['float']} shadow />
        <h3>Nothing found</h3>
        <p>Scout checked names, brands, models, serials, rooms, notes and document titles.</p>
      </div>
    );
  }

  return (
    <>
      <div className="seclabel">
        <span>Results</span>
        <span>{hits.length}</span>
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
  );
}

interface Group {
  key: string;
  title: string | null;
  items: Item[];
}

function groupItems(items: Item[], rooms: { id: string; name: string }[], sort: Sort): Group[] {
  if (sort !== 'room') {
    return [{ key: 'all', title: null, items: [...items].sort(comparator(sort)) }];
  }

  const byId = new Map(rooms.map((r) => [r.id, r.name]));
  const buckets = new Map<string, Item[]>();

  for (const item of items) {
    const key = item.roomId && byId.has(item.roomId) ? item.roomId : UNASSIGNED;
    const list = buckets.get(key) ?? [];
    list.push(item);
    buckets.set(key, list);
  }

  // Rooms keep their own order, so the list matches the order set in Settings.
  // Unassigned always sinks to the bottom — it's a to-do, not a room.
  const ordered: Group[] = rooms
    .filter((r) => buckets.has(r.id))
    .map((r) => ({
      key: r.id,
      title: r.name,
      items: buckets.get(r.id)!.sort((a, b) => a.name.localeCompare(b.name)),
    }));

  if (buckets.has(UNASSIGNED)) {
    ordered.push({
      key: UNASSIGNED,
      title: 'No room set',
      items: buckets.get(UNASSIGNED)!.sort((a, b) => a.name.localeCompare(b.name)),
    });
  }

  return ordered;
}

function comparator(sort: Sort): (a: Item, b: Item) => number {
  if (sort === 'name') return (a, b) => a.name.localeCompare(b.name);
  if (sort === 'recent') return (a, b) => b.createdAt.localeCompare(a.createdAt);

  // Expiring: soonest real expiry first, no-warranty items last rather than
  // first — sorting undefined to the top would bury what actually matters.
  return (a, b) => {
    const ea = effectiveExpiry(a)?.getTime();
    const eb = effectiveExpiry(b)?.getTime();
    if (ea == null && eb == null) return a.name.localeCompare(b.name);
    if (ea == null) return 1;
    if (eb == null) return -1;
    const expiredA = warrantyState(a) === 'expired';
    const expiredB = warrantyState(b) === 'expired';
    if (expiredA !== expiredB) return expiredA ? 1 : -1;
    return ea - eb;
  };
}
