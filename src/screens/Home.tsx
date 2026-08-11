import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItems } from '@/db/repo';
import { coverShare, metricsFor } from '@/lib/dashboard';
import { formatMoney, warrantyLabel } from '@/lib/warranty';
import { ItemIcon } from '@/components/ItemIcon';
import { Nutsy } from '@/components/Nutsy';

/**
 * The dashboard. Home used to be a second copy of the item list; now it answers
 * the questions you'd ask about the collection as a whole, and hands you off to
 * Items when you want the list itself.
 */
export function Home({
  propertyId,
  onAdd,
  onOpenItem,
  onBrowse,
}: {
  propertyId: string;
  onAdd: () => void;
  onOpenItem: (id: string) => void;
  onBrowse: (filter?: 'ending' | 'expired' | 'nopaperwork') => void;
}) {
  const items = useLiveQuery(() => activeItems(propertyId), [propertyId]);
  const docs = useLiveQuery(() => db.docs.toArray(), []);

  if (!items || !docs) return null;
  if (items.length === 0) return <EmptyHome onAdd={onAdd} />;

  const m = metricsFor(items, docs);
  const share = coverShare(m);

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

      {m.endingSoon > 0 && (
        <button type="button" className="alert" onClick={() => onBrowse('ending')}>
          <Nutsy pose="alert" height={54} motion={['alert']} />
          <span className="alert-txt">
            <h4>
              {m.endingSoon} warrant{m.endingSoon === 1 ? 'y ends' : 'ies end'} soon
            </h4>
            <p>Check {m.endingSoon === 1 ? 'it' : 'them'} before the window closes.</p>
          </span>
        </button>
      )}

      <div className="metrics">
        <Metric value={String(m.total)} label={m.total === 1 ? 'item' : 'items'} />
        <Metric value={String(m.covered)} label="still covered" tone="moss" />
        <Metric value={String(m.expired)} label="lapsed" tone={m.expired ? 'ember' : undefined} />
      </div>

      {/* One bar rather than a pie: the only comparison that matters is
          covered against not, and a bar reads at a glance on a phone. */}
      <div className="coverbar" role="img" aria-label={`${Math.round(share * 100)} percent still covered`}>
        <span style={{ width: `${(m.covered / Math.max(1, m.total)) * 100}%` }} className="seg-moss" />
        <span
          style={{ width: `${(m.endingSoon / Math.max(1, m.total)) * 100}%` }}
          className="seg-honey"
        />
        <span style={{ width: `${(m.expired / Math.max(1, m.total)) * 100}%` }} className="seg-ember" />
        <span
          style={{ width: `${(m.untracked / Math.max(1, m.total)) * 100}%` }}
          className="seg-none"
        />
      </div>
      <div className="coverkey">
        <span>
          <i className="dot moss" />
          Covered
        </span>
        <span>
          <i className="dot honey" />
          Ending soon
        </span>
        <span>
          <i className="dot ember" />
          Lapsed
        </span>
        <span>
          <i className="dot none" />
          No warranty
        </span>
      </div>

      {m.nextToExpire && (
        <button
          type="button"
          className="nextup"
          onClick={() => onOpenItem(m.nextToExpire!.item.id)}
        >
          <span className="fieldlabel">Next to expire</span>
          <strong>{m.nextToExpire.item.name}</strong>
          <small>{warrantyLabel(m.nextToExpire.item)} of cover left</small>
        </button>
      )}

      <div className="seclabel">
        <span>What you own</span>
      </div>
      <dl className="facts">
        {m.valueByCurrency.map((v) => (
          <div className="row" key={v.currency}>
            <dt>Recorded value{m.valueByCurrency.length > 1 ? ` (${v.currency})` : ''}</dt>
            <dd>{formatMoney(v.cents, v.currency)}</dd>
          </div>
        ))}
        <div className="row">
          <dt>Documents kept</dt>
          <dd>{m.documents}</dd>
        </div>
      </dl>

      {m.missingPaperwork > 0 && (
        <button type="button" className="navrow" onClick={() => onBrowse('nopaperwork')}>
          <span>
            <h4>
              {m.missingPaperwork} {m.missingPaperwork === 1 ? 'item has' : 'items have'} no proof
              of purchase
            </h4>
            <p>A claim asks for the receipt or the policy. These have neither.</p>
          </span>
          <svg
            width="17"
            height="17"
            viewBox="0 0 24 24"
            fill="none"
            stroke="var(--muted)"
            strokeWidth="2.4"
            strokeLinecap="round"
          >
            <path d="M9 5l7 7-7 7" />
          </svg>
        </button>
      )}

      <div className="seclabel" style={{ marginTop: 26 }}>
        <span>Recently added</span>
        <button type="button" className="linkish" onClick={() => onBrowse()}>
          See all
        </button>
      </div>

      <div className="recentrow">
        {m.recent.map((item) => (
          <button
            key={item.id}
            type="button"
            className="recentcard"
            onClick={() => onOpenItem(item.id)}
          >
            <ItemIcon item={item} size={24} />
            <strong>{item.name}</strong>
            <small>{warrantyLabel(item)}</small>
          </button>
        ))}
      </div>
    </>
  );
}

function Metric({
  value,
  label,
  tone,
}: {
  value: string;
  label: string;
  tone?: 'moss' | 'ember';
}) {
  return (
    <div className="metric">
      <strong style={tone ? { color: `var(--${tone})` } : undefined}>{value}</strong>
      <span>{label}</span>
    </div>
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
    </div>
  );
}
