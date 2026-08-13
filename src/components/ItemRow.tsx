import type { Item } from '@/db/types';
import { coverageArcs, coveragesOf, coverSummary } from '@/lib/warranty';
import { ItemIcon } from './ItemIcon';
import { TimeLeft } from './TimeLeft';
import { MAX_RINGS, RING_STEP, WarrantyRing } from './WarrantyRing';
import { useThumbUrl } from './useThumbUrl';

export function ItemRow({ item, onOpen }: { item: Item; onOpen?: (id: string) => void }) {
  const thumb = useThumbUrl(item.thumbBlobId);

  /*
    On an item with several policies the cover is the more useful second line
    — which one ends first, and how many there are — so it takes the slot the
    model and year usually hold. On everything else nothing changes: one
    warranty needs no explaining, and "Warranty ends first · 1 policy" down
    the whole list would be noise dressed as information.
  */
  const cover = coverSummary(item);
  const meta = [item.model, item.purchaseDate?.slice(0, 4)].filter(Boolean).join(' · ');

  // The photo gives up whatever the extra rings take, and no more. Computed
  // from the ring count rather than a class per count, because it has to match
  // the step the ring actually draws with — see WarrantyRing.
  const arcs = coverageArcs(item);
  const policies = coveragesOf(item).length;
  const inset = 5 + (Math.min(arcs.length, MAX_RINGS) - 1) * RING_STEP;

  return (
    <button type="button" className="item" onClick={() => onOpen?.(item.id)}>
      {/* One arc per policy, outermost expiring first. The count sits on the
          corner because the arcs stop being countable past three or so — and
          past four they aren't all drawn, so the ring alone would understate
          an item with six. */}
      <div className="thumbwrap">
        <WarrantyRing size={50} stroke={3} arcs={arcs} />
        <div className="thumb" style={{ inset }}>
          {thumb ? <img src={thumb} alt="" /> : <ItemIcon item={item} />}
        </div>
        {policies > 1 && (
          <span className="ringcount" aria-label={`${policies} policies`}>
            {policies}
          </span>
        )}
      </div>

      <div className="item-txt">
        <h3>{item.name}</h3>
        <p>{cover ?? meta ?? 'No model recorded'}</p>
      </div>

      {/* The number is the reason to open the row, so it gets the type. The
          unit sits under it rather than beside it — "142 days left" on one
          line at this size wraps on a phone. Which policy it belongs to is
          named on the left, where a variable-length word doesn't push the
          right-hand column out of alignment with the rows above it. */}
      <TimeLeft item={item} />
    </button>
  );
}
