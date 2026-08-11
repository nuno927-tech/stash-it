import { useEffect, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeRooms, softDeleteItem } from '@/db/repo';
import type { DocKind, Item } from '@/db/types';
import { feedback } from '@/lib/feedback';
import { docsWithFiles } from '@/lib/docs';
import {
  effectiveExpiry,
  formatMoney,
  warrantyLabel,
  warrantyProgress,
  warrantyState,
  type WarrantyState,
} from '@/lib/warranty';
import { AttachDoc } from '@/components/AttachDoc';
import { DocRow } from '@/components/DocRow';
import { ItemIcon } from '@/components/ItemIcon';
import { WarrantyRing, STATE_STROKE } from '@/components/WarrantyRing';

const HEADLINE: Record<WarrantyState, (label: string) => string> = {
  covered: (l) => `${l} of cover left`,
  'ending-soon': (l) => `${l} of cover left`,
  expired: () => 'Cover has ended',
  unknown: () => 'No warranty recorded',
};

export function ItemDetail({
  item,
  onBack,
  onEdit,
  onDeleted,
}: {
  item: Item;
  onBack: () => void;
  onEdit: () => void;
  onDeleted: () => void;
}) {
  const docs = useLiveQuery(() => docsWithFiles(item.id), [item.id]) ?? [];
  const rooms = useLiveQuery(() => activeRooms(item.propertyId), [item.propertyId]) ?? [];
  const room = rooms.find((r) => r.id === item.roomId);

  const [confirming, setConfirming] = useState(false);
  const [attaching, setAttaching] = useState<DocKind | null>(null);
  const photo = usePhotoUrl(item.thumbBlobId);

  const state = warrantyState(item);
  const expiry = effectiveExpiry(item);

  const onDelete = async () => {
    await softDeleteItem(item.id);
    feedback('delete');
    onDeleted();
  };

  return (
    <>
      <header className="apphead">
        <button type="button" className="iconbtn" onClick={onBack} aria-label="Back">
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
          >
            <path d="M15 5l-7 7 7 7" />
          </svg>
        </button>
        <button type="button" className="minibtn ghost" onClick={onEdit}>
          Edit
        </button>
      </header>

      <div className="prodhero">
        {photo ? <img src={photo} alt="" /> : <ItemIcon item={item} size={54} />}
        <span className="badge">{item.thumbBlobId ? 'Photo on device' : 'No photo'}</span>
      </div>

      <h2 className="detail-title">{item.name}</h2>
      <p className="detail-meta">
        {[item.brand, item.model, room?.name].filter(Boolean).join(' · ') || 'No details recorded'}
      </p>

      <div className="warranty">
        <div className="bigring">
          <WarrantyRing size={62} stroke={5} progress={warrantyProgress(item)} state={state} />
          <span className="lbl" style={{ color: STATE_STROKE[state] }}>
            {ringLabel(item, state)}
          </span>
        </div>
        <div className="warranty-txt">
          <h4>{HEADLINE[state](warrantyLabel(item))}</h4>
          <p>{warrantySentence(item, expiry)}</p>
        </div>
      </div>

      {item.warranty?.phone || item.warranty?.url ? (
        <div className="chiprow">
          {item.warranty.phone && (
            <a className="pick" href={`tel:${item.warranty.phone}`}>
              Call {item.warranty.provider ?? 'provider'}
            </a>
          )}
          {item.warranty.url && (
            <a className="pick" href={item.warranty.url} target="_blank" rel="noreferrer">
              Warranty page
            </a>
          )}
        </div>
      ) : null}

      <div className="seclabel">
        <span>Details</span>
      </div>
      <dl className="facts">
        <Fact label="Purchased" value={formatDate(item.purchaseDate)} />
        <Fact
          label="Price"
          value={formatMoney(item.purchasePriceCents, item.currency ?? 'USD') || '—'}
        />
        <Fact label="Retailer" value={item.retailer ?? '—'} />
        <Fact label="Serial" value={item.serial ?? '—'} mono />
        <Fact label="Policy" value={item.warranty?.policyNumber ?? '—'} mono />
      </dl>

      {item.notes && <p className="notes-body">{item.notes}</p>}

      <div className="seclabel">
        <span>Documents</span>
        <span>{docs.length}</span>
      </div>

      {docs.length === 0 && !attaching && (
        <p className="hint">
          Nothing attached yet. The receipt and the warranty policy are the two a claim will ask
          for.
        </p>
      )}

      {docs.map((d) => (
        <DocRow key={d.id} doc={d} />
      ))}

      {attaching ? (
        <AttachDoc
          itemId={item.id}
          defaultKind={attaching}
          onDone={() => setAttaching(null)}
          onCancel={() => setAttaching(null)}
        />
      ) : (
        <div className="photoactions">
          <button type="button" className="minibtn" onClick={() => setAttaching('warranty')}>
            Add warranty
          </button>
          <button type="button" className="minibtn ghost" onClick={() => setAttaching('receipt')}>
            Add receipt
          </button>
          <button type="button" className="minibtn ghost" onClick={() => setAttaching('manual')}>
            Add manual
          </button>
        </div>
      )}

      {confirming ? (
        <div className="sheet">
          <h4>
            Delete {item.name}? It moves to the bin for 30 days, and deleting frees a free-tier slot
            straight away.
          </h4>
          <button type="button" className="choice danger" onClick={onDelete}>
            <b>Delete</b>
            <span>Recoverable for 30 days, then gone for good.</span>
          </button>
          <button type="button" className="btn ghost" onClick={() => setConfirming(false)}>
            Keep it
          </button>
        </div>
      ) : (
        <button
          type="button"
          className="btn ghost wide"
          aria-expanded={false}
          onClick={() => setConfirming(true)}
        >
          Delete item
        </button>
      )}
    </>
  );
}

function Fact({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="row">
      <dt>{label}</dt>
      <dd style={mono ? { fontFamily: 'var(--font-mono)', fontSize: 12 } : undefined}>{value}</dd>
    </div>
  );
}

/** Object URL for the item's photo, revoked on unmount. */
function usePhotoUrl(blobId?: string): string | undefined {
  const [url, setUrl] = useState<string>();
  useEffect(() => {
    if (!blobId) {
      setUrl(undefined);
      return;
    }
    let dead = false;
    let made: string | undefined;
    db.blobs.get(blobId).then((rec) => {
      if (!rec || dead) return;
      made = URL.createObjectURL(rec.data);
      setUrl(made);
    });
    return () => {
      dead = true;
      if (made) URL.revokeObjectURL(made);
    };
  }, [blobId]);
  return url;
}

/** The number inside the ring: days when it's close, years when it isn't. */
function ringLabel(item: Item, state: WarrantyState): string {
  if (state === 'unknown') return '—';
  if (state === 'expired') return '0';
  return warrantyLabel(item).replace(/ days?$/, '').replace(/\s/g, '');
}

function warrantySentence(item: Item, expiry: Date | null): string {
  if (!expiry) return 'Add a purchase date and warranty length and Nutsy will track it.';
  const months = item.warranty?.months;
  const term = months ? `${months}-month` : '';
  const provider = item.warranty?.provider ? ` from ${item.warranty.provider}` : '';
  const when = expiry.toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
  return `${term} warranty${provider} ends ${when}.`.replace(/^ /, '');
}

function formatDate(iso?: string): string {
  if (!iso) return '—';
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y!, (m ?? 1) - 1, d ?? 1).toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}
