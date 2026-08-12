import { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { activeRooms, softDeleteItem } from '@/db/repo';
import type { DocKind, Item } from '@/db/types';
import { feedback } from '@/lib/feedback';
import { attachFile, docsWithFiles, DocError } from '@/lib/docs';
import { phoneHref } from '@/lib/format';
import {
  effectiveExpiry,
  formatMoney,
  warrantyLabel,
  warrantyProgress,
  warrantyState,
  type WarrantyState,
} from '@/lib/warranty';
import { DocRow } from '@/components/DocRow';
import { DocTiles } from '@/components/DocTiles';
import { ItemIcon } from '@/components/ItemIcon';
import { LinkDoc } from '@/components/LinkDoc';
import { PhotoViewer } from '@/components/PhotoViewer';
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
  const [linking, setLinking] = useState(false);
  const [docError, setDocError] = useState<string>();
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
            <a className="pick" href={`tel:${phoneHref(item.warranty.phone)}`}>
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

      {docs.map((d) => (
        <DocRow key={d.id} doc={d} />
      ))}

      {/* The same tiles as the add form: one tap says what it is and opens the
          picker, and the file's own name becomes the title. Nothing to fill
          in — the sheet that used to be here asked for the kind you'd already
          chosen, then a source, then a title, before it would take the file. */}
      <DocTiles
        raised
        onFiles={(kind, files) => {
          setDocError(undefined);
          void attachAll(item.id, kind, files).catch((e: unknown) => {
            feedback('error');
            setDocError(e instanceof DocError ? e.message : (e as Error).message);
          });
        }}
      />

      {docError && <div className="notice bad">{docError}</div>}

      {docs.length === 0 && (
        <p className="hint">
          Nothing attached yet. The receipt and the warranty are the two a claim will ask for.
        </p>
      )}

      <button type="button" className="linkish morelink" onClick={() => setLinking(true)}>
        Link to one on the web
      </button>

      {linking && (
        <LinkDoc
          itemId={item.id}
          onDone={() => setLinking(false)}
          onCancel={() => setLinking(false)}
        />
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

/**
 * Writes a whole selection. Several files from one tap are pages of one
 * document — a three-page warranty photographed page by page — so they're
 * numbered in the order they were picked. A single file keeps whatever
 * `attachFile` makes of its filename.
 */
async function attachAll(itemId: string, kind: DocKind, files: File[]): Promise<void> {
  for (const [i, file] of files.entries()) {
    await attachFile(itemId, kind, file, files.length > 1 ? `Page ${i + 1}` : undefined);
  }
  feedback('attach');
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

function warrantySentence(item: Item, expiry: Date | null): string {
  if (!expiry) return 'Add a purchase date and warranty length and Scout will track it.';
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
