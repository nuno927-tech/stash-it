import { useEffect, useState } from 'react';
import { db } from '@/db/db';
import type { Item } from '@/db/types';
import { warrantyLabel, warrantyProgress, warrantyState, type WarrantyState } from '@/lib/warranty';
import { CategoryIcon } from './CategoryIcon';
import { WarrantyRing } from './WarrantyRing';

const CHIP_CLASS: Record<WarrantyState, string> = {
  covered: 'ok',
  'ending-soon': 'warn',
  expired: 'dead',
  unknown: 'none',
};

/** Object URLs are revoked on unmount — long lists would otherwise leak. */
function useThumbUrl(blobId: string | undefined): string | undefined {
  const [url, setUrl] = useState<string>();

  useEffect(() => {
    if (!blobId) {
      setUrl(undefined);
      return;
    }
    let revoked = false;
    let made: string | undefined;

    db.blobs.get(blobId).then((rec) => {
      if (!rec || revoked) return;
      made = URL.createObjectURL(rec.data);
      setUrl(made);
    });

    return () => {
      revoked = true;
      if (made) URL.revokeObjectURL(made);
    };
  }, [blobId]);

  return url;
}

export function ItemRow({ item, onOpen }: { item: Item; onOpen?: (id: string) => void }) {
  const state = warrantyState(item);
  const thumb = useThumbUrl(item.thumbBlobId);

  const meta = [item.model, item.purchaseDate?.slice(0, 4)].filter(Boolean).join(' · ');

  return (
    <button type="button" className="item" onClick={() => onOpen?.(item.id)}>
      <div className="thumbwrap">
        <WarrantyRing size={50} stroke={3} progress={warrantyProgress(item)} state={state} />
        <div className="thumb">
          {thumb ? <img src={thumb} alt="" /> : <CategoryIcon category={item.category} />}
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
