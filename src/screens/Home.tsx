import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItems } from '@/db/repo';
import type { Doc, Item } from '@/db/types';
import { gapsFor, metricsFor, type GapKind, type Metrics } from '@/lib/dashboard';
import { greeting } from '@/lib/greeting';
import { prefsFrom } from '@/lib/prefs';
import {
  effectiveExpiry,
  formatMoney,
  warrantyLabel,
  warrantyState,
  type WarrantyState,
} from '@/lib/warranty';
import type { ItemsFilter } from '@/screens/Items';
import { ItemIcon } from '@/components/ItemIcon';
import { Scout } from '@/components/Scout';
import { TimeLeft } from '@/components/TimeLeft';
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
  onBrowse: (filter?: ItemsFilter) => void;
}) {
  const items = useLiveQuery(() => activeItems(propertyId), [propertyId]);
  const docs = useLiveQuery(() => db.docs.toArray(), []);
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);

  if (!items || !docs) return null;
  if (items.length === 0) return <EmptyHome onAdd={onAdd} />;

  const m = metricsFor(items, docs);

  return (
    <>
      <header className="apphead greethead">
        <div className="greet">
          <span className="greet-mark">
            Stash<span>&nbsp;it</span>
          </span>
          <h1>{greeting(prefsFrom(settings).displayName)}</h1>
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
            {/* The date, not the countdown again. The countdown is on the
                right in the same type the Items list uses; saying it twice in
                two different formats was the whole confusion. */}
            <small>{endsOn(m.nextToExpire.item)}</small>
          </span>
          <TimeLeft item={m.nextToExpire.item} />
        </button>
      )}

      <NeedsCard items={items} docs={docs} onBrowse={onBrowse} />

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
  onBrowse: (filter?: ItemsFilter) => void;
}) {
  const tracked = m.covered + m.endingSoon + m.expired;
  const pct = tracked === 0 ? 0 : Math.round(((m.covered + m.endingSoon) / tracked) * 100);

  // Smaller than it was alone, because Scout now stands beside it rather than
  // perching in a corner. A 208 ring and a mascot worth looking at don't both
  // fit across a phone, and a mascot too small to read is just clutter.
  const size = 176;
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
      {/* Scout presenting the figures, standing at the ring's shoulder. It's a
          field report — his, about your house — and the pose is the only thing
          on the card saying the numbers were gathered rather than displayed. */}
      <div className="coverrow">
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

        <Scout pose="report" height={148} motion={['breathe']} alt="" />
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

/**
 * What's unfinished, and what it costs to leave it that way.
 *
 * This replaces a single "no proof of purchase" row. The point isn't the
 * count — it's that each line is a job with an end, and tapping it lands on
 * exactly the items that need doing rather than on the whole list.
 *
 * Ordered by consequence, not by count: a missing receipt can't be recreated
 * later, a missing photo can be taken this afternoon. Sorting by size would
 * put the cheap problem first on most people's data.
 */
function NeedsCard({
  items,
  docs,
  onBrowse,
}: {
  items: Item[];
  docs: Doc[];
  onBrowse: (filter?: ItemsFilter) => void;
}) {
  const gaps = gapsFor(items, docs);

  // Nothing missing is worth saying out loud, once. It's the only state in the
  // app that's finished, and a card that vanishes silently reads like a bug.
  if (gaps.length === 0) {
    return (
      <div className="card needscard done">
        {/* Asleep, because there is nothing to do. The pose carries the state
            faster than the heading does, and it's the only place in the app
            that gets to say "finished". */}
        <div className="needsaside">
          <Scout pose="resting" height={104} motion={['breathe']} alt="" />
        </div>
        <div className="needsdone-txt">
          <h3>Nothing needs you</h3>
          <p>Every item has a receipt, a warranty length, a date and a photo.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="card needscard">
      {/* Ears up, down the left of the card. Same card, opposite posture — the
          difference between the two states should be legible before a word
          is read. */}
      <div className="needsaside">
        <Scout pose="alert" height={124} motion={['alert']} alt="" />
      </div>

      <div className="needsbody">
        <div className="cardhead">
          <h3>Needs a minute</h3>
          <span className="countpill">{gaps.reduce((n, g) => n + g.count, 0)}</span>
        </div>

        {gaps.map((gap) => (
          <button
            key={gap.kind}
            type="button"
            className="needrow"
            onClick={() => onBrowse(GAP_FILTER[gap.kind])}
          >
            <span className="needcount">{gap.count}</span>
            <span className="needtxt">
              <strong>{gap.label.replace(/^\d+ /, '')}</strong>
              <small>{gap.why}</small>
            </span>
            <Chevron />
          </button>
        ))}
      </div>
    </div>
  );
}

const GAP_FILTER: Record<GapKind, ItemsFilter> = {
  receipt: 'noreceipt',
  warranty: 'nowarranty',
  date: 'nodate',
  photo: 'nophoto',
};

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

/** "Ends 14 Mar 2027" — the fact the countdown on the right doesn't carry. */
function endsOn(item: Item): string {
  const end = effectiveExpiry(item);
  if (!end) return 'No warranty recorded';
  return `Ends ${end.toLocaleDateString(undefined, {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  })}`;
}

function EmptyHome({ onAdd }: { onAdd: () => void }) {
  return (
    <div className="empty">
      <Scout pose="acorn" height={200} motion={['float', 'pop']} shadow alt="" />
      <h3>Nothing stashed yet</h3>
      <p>Add your first item and Scout will keep track of the warranty for you.</p>
      <button type="button" className="btn" onClick={onAdd}>
        Add an item
      </button>
    </div>
  );
}
