import { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { activeRooms, softDeleteItem } from '@/db/repo';
import type { Item } from '@/db/types';
import { feedback } from '@/lib/feedback';
import { docsWithFiles } from '@/lib/docs';
import {
  coverageLabel,
  coveragesOf,
  coverageTermLabel,
  effectiveExpiry,
  formatMoney,
  hasLifetime,
  nextToLapse,
  warrantyLabel,
  warrantyProgress,
  warrantyState,
  type WarrantyState,
} from '@/lib/warranty';
import { ConfirmDelete } from '@/components/ConfirmDelete';
import { CoverList } from '@/components/CoverList';
import { DocRow } from '@/components/DocRow';
import { ItemIcon } from '@/components/ItemIcon';
import { PhotoViewer } from '@/components/PhotoViewer';
import { StashThePaper } from '@/components/StashThePaper';
import { useItemPhotos } from '@/components/useItemPhotos';
import { WarrantyRing, STATE_STROKE } from '@/components/WarrantyRing';

const HEADLINE: Record<WarrantyState, (label: string) => string> = {
  covered: (l) => `${l} of cover left`,
  'ending-soon': (l) => `${l} of cover left`,
  expired: () => 'Cover has ended',
  unknown: () => 'No warranty recorded',
};

export function ItemDetail({
  item,
  justSaved = false,
  onBack,
  onEdit,
  onDeleted,
}: {
  item: Item;
  /** True only when you arrived here by creating this item a second ago. */
  justSaved?: boolean;
  onBack: () => void;
  onEdit: () => void;
  onDeleted: () => void;
}) {
  const docs = useLiveQuery(() => docsWithFiles(item.id), [item.id]) ?? [];
  const rooms = useLiveQuery(() => activeRooms(item.propertyId), [item.propertyId]) ?? [];
  const room = rooms.find((r) => r.id === item.roomId);

  /*
    Latched from the prop rather than read from it, so dismissing sticks. The
    prop stays true for as long as this screen is on the stack — reading it
    directly would put the dialog back on the next render.
  */
  const [paperOpen, setPaperOpen] = useState(justSaved);

  const [confirming, setConfirming] = useState(false);
  const [viewing, setViewing] = useState<number | null>(null);
  const shots = useItemPhotos(item);

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


      {/* Tapping the photo opens it full screen. A receipt shot at arm's
          length is unreadable at this size, so the hero has to be a door. */}
      {shots.length > 0 ? (
        <button
          type="button"
          className="prodhero tappable"
          onClick={() => setViewing(0)}
          aria-label={shots.length > 1 ? `View ${shots.length} photos` : 'View the photo'}
        >
          <img src={shots[0]!.url} alt="" />
          <span className="badge">
            {shots.length > 1 ? `${shots.length} photos` : 'Tap to enlarge'}
          </span>
        </button>
      ) : (
        <div className="prodhero">
          <ItemIcon item={item} size={54} />
          <span className="badge">No photo</span>
        </div>
      )}

      {shots.length > 1 && (
        <div className="thumbstrip">
          {shots.map((s, i) => (
            <button
              key={s.id}
              type="button"
              className="thumbstrip-item"
              onClick={() => setViewing(i)}
              aria-label={`Photo ${i + 1}`}
            >
              <img src={s.url} alt="" />
            </button>
          ))}
        </div>
      )}

      {viewing !== null && (
        <PhotoViewer shots={shots} startAt={viewing} onClose={() => setViewing(null)} />
      )}

      <h2 className="detail-title">{item.name}</h2>
      <p className="detail-meta">
        {[item.brand, item.model, room?.name].filter(Boolean).join(' · ') || 'No details recorded'}
      </p>

      <div className="warranty">
        <div className="bigring">
          {/* The big ring keeps to one arc. The stack belongs on the list,
              where it answers "which of these has more than one"; here the
              question is already answered by the Cover list a few lines
              down, and four arcs at 62px would be decoration. */}
          <WarrantyRing
            size={62}
            stroke={5}
            arcs={[{ progress: warrantyProgress(item), state }]}
          />
          <span className="lbl" style={{ color: STATE_STROKE[state] }}>
            {ringLabel(item, state)}
          </span>
        </div>
        <div className="warranty-txt">
          <h4>{HEADLINE[state](warrantyLabel(item))}</h4>
          <p>{warrantySentence(item, expiry)}</p>
        </div>
      </div>

      <CoverList item={item} />

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
      </dl>

      {item.notes && <p className="notes-body">{item.notes}</p>}

      <div className="seclabel">
        <span>Documents</span>
        <span>{docs.length}</span>
      </div>

      {docs.map((d) => (
        <DocRow key={d.id} doc={d} />
      ))}

      {/*
        No attach controls here. This is a page for reading an item, and five
        upload tiles plus a link button sat on it permanently — a row of empty
        actions under a list of documents, offered whether or not you came here
        to add anything. Attaching lives on the form, behind Edit, which is
        also the only place it can be undone before it's written.
      */}
      {docs.length === 0 && (
        <p className="hint">
          Nothing attached yet. Edit the item to add a receipt or a warranty — the two a claim
          will ask for.
        </p>
      )}

      <button
        type="button"
        className="btn ghost wide"
        aria-haspopup="dialog"
        aria-expanded={confirming}
        onClick={() => setConfirming(true)}
      >
        Delete item
      </button>

      {confirming && (
        <ConfirmDelete
          name={item.name}
          onConfirm={onDelete}
          onCancel={() => setConfirming(false)}
        />
      )}

      {/* Last in the tree, first on the screen — it portals to the body, so
          where it sits here only decides what it reads after in the DOM. */}
      {paperOpen && <StashThePaper onClose={() => setPaperOpen(false)} />}
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

/** The number inside the ring: days when it's close, years when it isn't. */
function ringLabel(item: Item, state: WarrantyState): string {
  if (state === 'unknown') return '—';
  if (state === 'expired') return '0';
  return warrantyLabel(item).replace(/ days?$/, '').replace(/\s/g, '');
}

/**
 * The line under the headline. It describes the policy the countdown belongs
 * to — not "the warranty", which on an item with five of them is a sentence
 * about nothing in particular.
 */
function warrantySentence(item: Item, expiry: Date | null): string {
  const all = coveragesOf(item);
  if (all.length === 0) return 'Add a warranty length and Scout will track it.';

  const next = nextToLapse(item);
  if (!next) {
    if (hasLifetime(item)) return 'Covered for as long as you own it.';
    if (!expiry) return 'Add a purchase date and Scout can work out when this ends.';
    return 'Everything on this item has run out.';
  }

  const label = coverageLabel(next.coverage).toLowerCase();
  const provider = next.coverage.provider ? ` from ${next.coverage.provider}` : '';
  const when = next.end!.toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });

  const rest = all.length - 1;
  const others = rest > 0 ? ` ${rest} other ${rest === 1 ? 'policy runs' : 'policies run'} longer.` : '';
  return `${coverageTermLabel(next.coverage)} ${label}${provider} ends ${when}.${others}`;
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
