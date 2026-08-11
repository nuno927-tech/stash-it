import type { Item } from '@/db/types';
import { warrantyLabel, warrantyProgress, warrantyState, type WarrantyState } from '@/lib/warranty';
import { ItemIcon } from './ItemIcon';
import { WarrantyRing } from './WarrantyRing';
import { useThumbUrl } from './useThumbUrl';

const CHIP_CLASS: Record<WarrantyState, string> = {
  covered: 'ok',
  'ending-soon': 'warn',
  expired: 'dead',
  unknown: 'none',
};

export function ItemRow({ item, onOpen }: { item: Item; onOpen?: (id: string) => void }) {
  const state = warrantyState(item);
  const thumb = useThumbUrl(item.thumbBlobId);

  const meta = [item.model, item.purchaseDate?.slice(0, 4)].filter(Boolean).join(' · ');

  return (
    <button type="button" className="item" onClick={() => onOpen?.(item.id)}>
      <div className="thumbwrap">
        <WarrantyRing size={50} stroke={3} progress={warrantyProgress(item)} state={state} />
        <div className="thumb">
          {thumb ? <img src={thumb} alt="" /> : <ItemIcon item={item} />}
        </div>
      </div>

      <div className="item-txt">
        <h3>{item.name}</h3>
        <p>{meta || 'No model recorded'}</p>
      </div>

      <div className={`chip ${CHIP_CLASS[state]}`}>{warrantyLabel(item)}</div>
    </button>
  );
}
