import { useLiveQuery } from 'dexie-react-hooks';
import { activeItems } from '@/db/repo';
import type { Item } from '@/db/types';
import { effectiveExpiry, warrantyState } from '@/lib/warranty';
import { ItemRow } from '@/components/ItemRow';
import { Nutsy } from '@/components/Nutsy';

/**
 * Urgency order: things about to lapse, then things still covered by how soon
 * they end, then items with no warranty on record, then expired. The point of
 * the screen is "what needs you", not "what you own" — that's the Items tab.
 */
const RANK = { 'ending-soon': 0, covered: 1, unknown: 2, expired: 3 } as const;

function byUrgency(a: Item, b: Item): number {
  const ra = RANK[warrantyState(a)];
  const rb = RANK[warrantyState(b)];
  if (ra !== rb) return ra - rb;

  const ea = effectiveExpiry(a)?.getTime() ?? Infinity;
  const eb = effectiveExpiry(b)?.getTime() ?? Infinity;
  if (ea !== eb) return ea - eb;

  return a.name.localeCompare(b.name);
}

export function Home({
  propertyId,
  onAdd,
  onOpenItem,
  onSeeEndingSoon,
}: {
  propertyId: string;
  onAdd: () => void;
  onOpenItem: (id: string) => void;
  onSeeEndingSoon: () => void;
}) {
  const items = useLiveQuery(() => activeItems(propertyId), [propertyId]);

  if (!items) return null; // first paint only; Dexie resolves in the same tick

  if (items.length === 0) return <EmptyHome onAdd={onAdd} />;

  const sorted = [...items].sort(byUrgency);
  const endingSoon = sorted.filter((i) => warrantyState(i) === 'ending-soon');

  return (
    <>
      <header className="apphead">
        <div className="apptitle">
          Stash<span>&nbsp;it</span>
        </div>
        <div className="avatar">
          <Nutsy pose="avatar" height={36} alt="Nutsy" />
        </div>
      </header>

      {endingSoon.length > 0 && (
        <button type="button" className="alert" onClick={onSeeEndingSoon}>
          <Nutsy pose="alert" height={54} motion={['alert']} />
          <span className="alert-txt">
            <h4>
              {endingSoon.length} warrant{endingSoon.length === 1 ? 'y ends' : 'ies end'} soon
            </h4>
            <p>Check {endingSoon.length === 1 ? 'it' : 'them'} before the window closes.</p>
          </span>
        </button>
      )}

      <div className="seclabel">
        <span>Your stash</span>
        <span>
          {items.length} item{items.length === 1 ? '' : 's'}
        </span>
      </div>

      {sorted.map((item) => (
        <ItemRow key={item.id} item={item} onOpen={onOpenItem} />
      ))}
    </>
  );
}

function EmptyHome({ onAdd }: { onAdd: () => void }) {
  return (
    <div className="empty">
      <Nutsy pose="wave" height={210} motion={['float', 'pop']} shadow alt="Nutsy waving" />
      <h3>Nothing stashed yet</h3>
      <p>Add your first item and Nutsy will keep track of the warranty for you.</p>
      <button type="button" className="btn" onClick={onAdd}>
        Add an item
      </button>
      <button type="button" className="btn ghost" disabled>
        Restore from a backup
      </button>
    </div>
  );
}
