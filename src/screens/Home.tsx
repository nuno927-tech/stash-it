import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItems } from '@/db/repo';
import type { Item } from '@/db/types';
import { metricsFor, type Metrics } from '@/lib/dashboard';
import { formatMoney, warrantyLabel, warrantyState, type WarrantyState } from '@/lib/warranty';
import { ItemIcon } from '@/components/ItemIcon';
import { Scout } from '@/components/Scout';
import { useThumbUrl } from '@/components/useThumbUrl';

/**
 * The dashboard. Home answers the questions you'd ask about the collection as
 * a whole; Items answers "what do I own".
 *
 * The hierarchy is deliberate: one number matters most — how much of your
 * stuff is still covered — so it gets a ring and the largest type on the
 * screen. Everything else is support.
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

  return (
    <>
      <header className="apphead">
        <div className="apptitle">
          Stash<span>&nbsp;it</span>
        </div>
        <div className="avatar">
          <Scout pose="avatar" height={36} alt="Scout" />
        </div>
      </header>

      {m.endingSoon > 0 && (
        <button type="button" className="alert" onClick={() => onBrowse('ending')}>
          <Scout pose="alert" height={54} motion={['alert']} />
          <span className="alert-txt">
            <h4>
              {m.endingSoon} warrant{m.endingSoon === 1 ? 'y ends' : 'ies end'} soon
            </h4>
            <p>Check {m.endingSoon === 1 ? 'it' : 'them'} before the window closes.</p>
          </span>
        </button>
      )}

      <CoverCard metrics={m} onBrowse={onBrowse} />

      <div className="bigmetrics">
        <div className="bigmetric">
          <strong>{m.total}</strong>
          <span>{m.total === 1 ? 'item stashed' : 'items stashed'}</span>
        </div>
        <div className="bigmetric">
          <strong>{m.valueByCurrency[0] ? shortMoney(m.valueByCurrency[0]) : '—'}</strong>
          <span>
            recorded value
            {m.valueByCurrency.length > 1 ? ` · ${m.valueByCurrency[0]!.currency}` : ''}
          </span>
        </div>
      </div>

      {m.nextToExpire && (
        <button
          type="button"
          className="nextup"
          onClick={() => onOpenItem(m.nextToExpire!.item.id)}
        >
          <span className="nextup-txt">
            <span className="fieldlabel">Next to expire</span>
            <strong>{m.nextToExpire.item.name}</strong>
            <small>{warrantyLabel(m.nextToExpire.item)} of cover left</small>
          </span>
          <span className={`chip ${CHIP[warrantyState(m.nextToExpire.item)]}`}>
            {warrantyLabel(m.nextToExpire.item)}
          </span>
        </button>
      )}

      {m.missingPaperwork > 0 && (
        <button type="button" className="navrow" onClick={() => onBrowse('nopaperwork')}>
          <span>
            <h4>
              {m.missingPaperwork} {m.missingPaperwork === 1 ? 'item has' : 'items have'} no proof
              of purchase
            </h4>
            <p>A claim asks for the receipt or the policy. These have neither.</p>
          </span>
          <Chevron />
        </button>
      )}

      <div className="seclabel" style={{ marginTop: 28 }}>
        <span>Recently added</span>
        <button type="button" className="linkish" onClick={() => onBrowse()}>
          See all
        </button>
      </div>

      {/* Horizontal, and photo-first. A grid of three text boxes was the least
          interesting thing on the screen, and these are the items the user
          most recently held in their hands. */}
      <div className="recentstrip">
        {m.recent.map((item) => (
          <RecentCard key={item.id} item={item} onOpen={onOpenItem} />
        ))}
      </div>
    </>
  );
}

const CHIP: Record<WarrantyState, string> = {
  covered: 'ok',
  'ending-soon': 'warn',
  expired: 'dead',
  unknown: 'none',
};

/**
 * The headline. A ring rather than a bar: it holds a number in the middle,
 * which a 9px bar can't, and the number is the point.
 *
 * The ring is wide and deliberately hairline. A thick donut spends its area on
 * the band, which carries no information beyond the arc lengths — pushing the
 * same arcs out to a larger radius makes the proportions easier to read while
 * leaving a real hole for the number to sit in. The type is light for the same
 * reason: at 60px, weight is just ink.
 */
function CoverCard({
  metrics: m,
  onBrowse,
}: {
  metrics: Metrics;
  onBrowse: (filter?: 'ending' | 'expired' | 'nopaperwork') => void;
}) {
  const tracked = m.covered + m.endingSoon + m.expired;
  const pct = tracked === 0 ? 0 : Math.round(((m.covered + m.endingSoon) / tracked) * 100);

  const size = 208;
  const stroke = 6;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;

  // Drawn as one ring of consecutive arcs, so the proportions read directly.
  const slices = [
    { n: m.covered, colour: 'var(--moss)' },
    { n: m.endingSoon, colour: 'var(--honey)' },
    { n: m.expired, colour: 'var(--ember)' },
    { n: m.untracked, colour: 'var(--line)' },
  ].filter((s) => s.n > 0);

  let offset = 0;

  return (
    <div className="covercard">
      <div className="coverring">
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} aria-hidden="true">
          <g transform={`rotate(-90 ${size / 2} ${size / 2})`}>
            <circle
              cx={size / 2}
              cy={size / 2}
              r={r}
              fill="none"
              stroke="var(--slate-600)"
              strokeWidth={stroke}
            />
            {slices.map((s, i) => {
              const share = s.n / Math.max(1, m.total);
              const dash = share * c;
              // The gap between arcs is a hair under the stroke, so round caps
              // meet without overlapping — at this weight a 3px gap read as a
              // break in the ring rather than a division of it.
              const el = (
                <circle
                  key={i}
                  cx={size / 2}
                  cy={size / 2}
                  r={r}
                  fill="none"
                  stroke={s.colour}
                  strokeWidth={stroke}
                  strokeDasharray={`${Math.max(0, dash - 5)} ${c}`}
                  strokeDashoffset={-offset}
                  strokeLinecap="round"
                />
              );
              offset += dash;
              return el;
            })}
          </g>
        </svg>
        <div className="coverring-mid">
          <strong>
            {pct}
            <i>%</i>
          </strong>
          <span>still covered</span>
        </div>
      </div>

      <div className="coverstats">
        <Stat n={m.covered} label="covered" tone="moss" />
        <Stat n={m.endingSoon} label="ending soon" tone="honey" onClick={() => onBrowse('ending')} />
        <Stat n={m.expired} label="lapsed" tone="ember" onClick={() => onBrowse('expired')} />
        <Stat n={m.untracked} label="no warranty" tone="none" />
      </div>
    </div>
  );
}

function Stat({
  n,
  label,
  tone,
  onClick,
}: {
  n: number;
  label: string;
  tone: 'moss' | 'honey' | 'ember' | 'none';
  onClick?: () => void;
}) {
  const body = (
    <>
      <b>{n}</b>
      <span>
        <i className={`dot ${tone}`} />
        {label}
      </span>
    </>
  );

  // Only the actionable ones become buttons; a stat you can't do anything with
  // shouldn't look tappable.
  return onClick && n > 0 ? (
    <button type="button" className="coverstat" onClick={onClick}>
      {body}
    </button>
  ) : (
    <div className="coverstat">{body}</div>
  );
}

function RecentCard({ item, onOpen }: { item: Item; onOpen: (id: string) => void }) {
  const thumb = useThumbUrl(item.thumbBlobId);
  const state = warrantyState(item);

  return (
    <button type="button" className="recenttile" onClick={() => onOpen(item.id)}>
      <span className="recentart">
        {thumb ? <img src={thumb} alt="" /> : <ItemIcon item={item} size={34} />}
        <span className={`chip ${CHIP[state]}`}>{warrantyLabel(item)}</span>
      </span>
      <strong>{item.name}</strong>
      <small>{[item.brand, item.purchaseDate?.slice(0, 4)].filter(Boolean).join(' · ') || ' '}</small>
    </button>
  );
}

function Chevron() {
  return (
    <svg
      width="17"
      height="17"
      viewBox="0 0 24 24"
      fill="none"
      stroke="var(--muted)"
      strokeWidth="2.4"
      strokeLinecap="round"
      aria-hidden="true"
    >
      <path d="M9 5l7 7-7 7" />
    </svg>
  );
}

/**
 * "$12.4K" once the number gets long. The exact figure belongs in a report;
 * a tile this size needs to be read at a glance, and Intl already knows how
 * every locale abbreviates.
 */
function shortMoney({ currency, cents }: { currency: string; cents: number }): string {
  const units = cents / 100;
  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency,
      notation: units >= 10_000 ? 'compact' : 'standard',
      maximumFractionDigits: units >= 10_000 ? 1 : 0,
    }).format(units);
  } catch {
    return formatMoney(cents, currency);
  }
}

function EmptyHome({ onAdd }: { onAdd: () => void }) {
  return (
    <div className="empty">
      <Scout pose="wave" height={210} motion={['float', 'pop']} shadow alt="Scout waving" />
      <h3>Nothing stashed yet</h3>
      <p>Add your first item and Scout will keep track of the warranty for you.</p>
      <button type="button" className="btn" onClick={onAdd}>
        Add an item
      </button>
    </div>
  );
}
