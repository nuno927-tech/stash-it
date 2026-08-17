import { useMemo, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItems, activeRooms, deletedItems, softDeleteItem } from '@/db/repo';
import type { Item } from '@/db/types';
import { binSummary } from '@/lib/bin';
import { prefsFrom } from '@/lib/prefs';
import { matchSummary, searchItems } from '@/lib/search';
import { effectiveExpiry, warrantyState } from '@/lib/warranty';
import { feedback } from '@/lib/feedback';
import { ItemRow } from '@/components/ItemRow';
import { SwipeRow } from '@/components/SwipeRow';
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

/**
 * Ordered by how often the answer is wanted, not alphabetically and not by
 * how the type union happens to read. Expiring is the default and therefore
 * first; Room is the most specific question and goes last.
 */
const SORTS: Sort[] = ['expiry', 'recent', 'name', 'room'];

const SORT_LABEL: Record<Sort, string> = {
  expiry: 'Expiring',
  recent: 'Newest',
  name: 'A–Z',
  room: 'Room',
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
  onOpenBin,
}: {
  propertyId: string;
  filter?: ItemsFilter;
  onOpenItem: (id: string) => void;
  onAdd: () => void;
  onOpenBin: () => void;
}) {
  const items = useLiveQuery(() => activeItems(propertyId), [propertyId]);
  const binned = useLiveQuery(() => deletedItems(propertyId), [propertyId]) ?? [];
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

  /*
    Lapsed items stay in the list by default. Cover ending doesn't stop you
    owning the thing — the receipt, the serial number and the manual are all
    still worth having, and a fridge that vanishes from your inventory the day
    its warranty runs out is an inventory you can't trust. The toggle is for
    the other mood: "what is still covered".
  */
  const [showLapsed, setShowLapsed] = useState(true);

  // One row open at a time, so "tap anywhere else to close" means something.
  const [swiped, setSwiped] = useState<string | null>(null);

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
    /*
      Hiding lapsed items must never hide the ones you asked to see. Picking
      the "Lapsed" chip and getting an empty list because a toggle elsewhere
      says otherwise is the sort of contradiction that reads as a broken app.
    */
    const lapsedOk = (list: Item[]) =>
      showLapsed || active === 'expired'
        ? list
        : list.filter((i) => warrantyState(i) !== 'expired');

    if (!active) return lapsedOk(all);
    const live = docs.filter((d) => !d.deletedAt);
    const withProof = new Set(
      live.filter((d) => d.kind === 'receipt' || d.kind === 'warranty').map((d) => d.itemId),
    );
    const withReceipt = new Set(live.filter((d) => d.kind === 'receipt').map((d) => d.itemId));

    return lapsedOk(all).filter((i) => {
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
  }, [all, active, docs, showLapsed]);

  const groups = useMemo(() => groupItems(filtered, rooms, sort), [filtered, rooms, sort]);
  const lapsed = all.filter((i) => warrantyState(i) === 'expired').length;

  if (!items) return null;

  if (all.length === 0) {
    return (
      <div className="empty">
        <Scout pose="receipt" height={180} motion={['float']} shadow alt="" />
        <h3>Nothing stashed yet</h3>
        <p>Everything you add shows up here, grouped by the room it lives in.</p>
        <button type="button" className="btn" onClick={onAdd}>
          Add an item
        </button>
        {/* Deleting the last item lands you here, which makes this the one
            screen where the way back to the bin matters most. */}
        <BinLink binned={binned} onOpenBin={onOpenBin} />
      </div>
    );
  }

  return (
    <>
      {/*
        Title, search and filters travel together and stick to the top. On a
        list this long, scrolling used to take the search box with it — so
        finding something meant scrolling back up first, which is the opposite
        of what a search box is for.

        Scout stands to the right across both rows. The search field is
        shortened to make the room rather than him being squeezed into a
        corner; the field was wider than any query anyone types anyway.
      */}
      <div className="itemshead">
        <header className="apphead">
          <div className="apptitle">Items</div>
        </header>

        <div className="itemsmark">
          <Scout pose="receipt" height={104} motion={['breathe']} alt="" />
        </div>

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

        {!searching && (
          <div className="chiprow">
            {SORTS.map((s) => (
              <button
                key={s}
                type="button"
                className={`pick${sort === s ? ' on' : ''}`}
                onClick={() => setSort(s)}
              >
                {SORT_LABEL[s]}
              </button>
            ))}

            {/* Offered only when there's something to hide. A toggle for a
                category you don't own anything in is a control that does
                nothing, sitting where a useful one could be. */}
            {lapsed > 0 && (
              <button
                type="button"
                className={`pick lapsedpick${showLapsed ? ' on' : ''}`}
                aria-pressed={showLapsed}
                onClick={() => setShowLapsed((v) => !v)}
              >
                {showLapsed ? `Lapsed shown · ${lapsed}` : `Lapsed hidden · ${lapsed}`}
              </button>
            )}
          </div>
        )}
      </div>

      {searching ? (
        <SearchResults hits={hits} onOpenItem={onOpenItem} />
      ) : (
        <>
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
                    <Row
                      key={item.id}
                      item={item}
                      open={swiped === item.id}
                      onOpenChange={(o) => setSwiped(o ? item.id : null)}
                      onOpenItem={onOpenItem}
                    />
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
                        <Row
                          key={item.id}
                          item={item}
                          open={swiped === item.id}
                          onOpenChange={(o) => setSwiped(o ? item.id : null)}
                          onOpenItem={onOpenItem}
                        />
                      ))}
                    </div>
                  )}
                </section>
              ),
            )
          )}
        </>
      )}

      <BinLink binned={binned} onOpenBin={onOpenBin} />
    </>
  );
}

/**
 * One row, with the delete offer behind it.
 *
 * Soft delete, so it lands in Recently deleted with its thirty days rather
 * than going for good — a swipe is the easiest gesture in the app to make by
 * accident, and this is the one place in the list that can remove something.
 */
function Row({
  item,
  open,
  onOpenChange,
  onOpenItem,
}: {
  item: Item;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onOpenItem: (id: string) => void;
}) {
  return (
    <SwipeRow
      open={open}
      onOpenChange={onOpenChange}
      deleteLabel={`Delete ${item.name}`}
      onDelete={() => {
        void softDeleteItem(item.id).then(() => feedback('delete'));
        onOpenChange(false);
      }}
    >
      {/* An open row must not also be a link to the item — the tap that closes
          it would otherwise open the thing you were about to delete. */}
      <ItemRow item={item} onOpen={open ? () => onOpenChange(false) : onOpenItem} />
    </SwipeRow>
  );
}

/**
 * The way into the bin, shown only when there's something in it.
 *
 * An always-present "Recently deleted (0)" is a row that answers no question,
 * on the screen that can least afford another one. And the moment the app
 * promises the bin — the delete confirmation — is a moment there is certainly
 * something inside it, so the promise is never made about a row that isn't
 * there.
 */
function BinLink({ binned, onOpenBin }: { binned: Item[]; onOpenBin: () => void }) {
  if (binned.length === 0) return null;
  return (
    <button type="button" className="binlink" onClick={onOpenBin}>
      <span>Recently deleted</span>
      <small>{binSummary(binned)}</small>
    </button>
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
      <div className="empty inline">
        <Scout pose="alert" height={120} motion={['float']} shadow alt="" />
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
