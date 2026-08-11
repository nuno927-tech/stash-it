import { useMemo, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { activeItems, activeRooms } from '@/db/repo';
import { ITEM_CATEGORIES, type Item, type ItemCategory } from '@/db/types';
import { effectiveExpiry, warrantyState } from '@/lib/warranty';
import { ItemRow } from '@/components/ItemRow';
import { Nutsy } from '@/components/Nutsy';

type Sort = 'name' | 'expiry' | 'recent';

const SORT_LABEL: Record<Sort, string> = {
  name: 'A–Z',
  expiry: 'Expiring',
  recent: 'Newest',
};

/**
 * The full inventory. Home answers "what needs me"; this answers "what do I
 * own", so it defaults to alphabetical rather than urgency order.
 */
export function Items({
  propertyId,
  onOpenItem,
  onAdd,
}: {
  propertyId: string;
  onOpenItem: (id: string) => void;
  onAdd: () => void;
}) {
  const items = useLiveQuery(() => activeItems(propertyId), [propertyId]);
  const rooms = useLiveQuery(() => activeRooms(propertyId), [propertyId]) ?? [];

  const [roomId, setRoomId] = useState<string>('');
  const [category, setCategory] = useState<ItemCategory | ''>('');
  const [sort, setSort] = useState<Sort>('name');

  const all = useMemo(() => items ?? [], [items]);

  // Only offer filters that would actually return something — a category chip
  // that yields an empty list is a dead end the user has to back out of.
  const usedCategories = useMemo(
    () => ITEM_CATEGORIES.filter((c) => all.some((i) => i.category === c)),
    [all],
  );
  const usedRooms = useMemo(
    () => rooms.filter((r) => all.some((i) => i.roomId === r.id)),
    [rooms, all],
  );

  const shown = useMemo(() => {
    const filtered = all.filter(
      (i) => (!roomId || i.roomId === roomId) && (!category || i.category === category),
    );
    return filtered.sort(comparator(sort));
  }, [all, roomId, category, sort]);

  if (!items) return null;

  if (all.length === 0) {
    return (
      <div className="empty">
        <Nutsy pose="stand" height={170} motion={['float']} shadow />
        <h3>Nothing stashed yet</h3>
        <p>Everything you add shows up here, filterable by room and category.</p>
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
        <div className="sortpick">
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
      </header>

      {(usedRooms.length > 0 || usedCategories.length > 0) && (
        <div className="chiprow">
          <button
            type="button"
            className={`pick${!roomId && !category ? ' on' : ''}`}
            onClick={() => {
              setRoomId('');
              setCategory('');
            }}
          >
            All
          </button>

          {usedRooms.map((r) => (
            <button
              key={r.id}
              type="button"
              className={`pick${roomId === r.id ? ' on' : ''}`}
              onClick={() => setRoomId(roomId === r.id ? '' : r.id)}
            >
              {r.name}
            </button>
          ))}

          {usedCategories.map((c) => (
            <button
              key={c}
              type="button"
              className={`pick${category === c ? ' on' : ''}`}
              onClick={() => setCategory(category === c ? '' : c)}
            >
              {c}
            </button>
          ))}
        </div>
      )}

      <div className="seclabel">
        <span>{roomId || category ? 'Filtered' : 'Everything'}</span>
        <span>
          {shown.length} of {all.length}
        </span>
      </div>

      {shown.length === 0 ? (
        <p className="hint">Nothing matches those filters.</p>
      ) : (
        shown.map((item) => <ItemRow key={item.id} item={item} onOpen={onOpenItem} />)
      )}
    </>
  );
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
