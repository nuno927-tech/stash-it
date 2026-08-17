import { useEffect, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItems, activeSubscriptions } from '@/db/repo';
import type { Doc, Item, Subscription } from '@/db/types';
import { gapsFor, metricsFor, type GapKind, type Metrics } from '@/lib/dashboard';
import { greeting } from '@/lib/greeting';
import {
  clearNudgePreview,
  dueNudges,
  nudgePreviewArmed,
  sampleNudges,
  type NudgeKind,
} from '@/lib/nudges';
import { prefsFrom } from '@/lib/prefs';
import {
  dailyCents,
  daysUntilRenewal,
  heaviest,
  nextRenewal,
  spendByMonth,
  spread,
  subGaps,
  totalMonthlyCents,
  totalYearlyCents,
  type MonthSpend,
} from '@/lib/subscriptions';
import {
  effectiveExpiry,
  formatMoney,
  warrantyLabel,
  warrantyState,
  type WarrantyState,
} from '@/lib/warranty';
import type { ItemsFilter } from '@/screens/Items';
import { ItemIcon } from '@/components/ItemIcon';
import { NudgeBar } from '@/components/NudgeBar';
import { RenewalNudges } from '@/components/RenewalNudges';
import { ServiceMark } from '@/components/ServiceMark';
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
  onSettings,
  onSubs,
}: {
  propertyId: string;
  onAdd: () => void;
  onOpenItem: (id: string) => void;
  onBrowse: (filter?: ItemsFilter) => void;
  /** Where every nudge sends you — each one is answered in Settings. */
  onSettings: () => void;
  onSubs: () => void;
}) {
  const [hidden, setHidden] = useState<NudgeKind[]>([]);

  /*
    The developer preview, if it was armed before we got here. Read into state
    on mount rather than on every render: the flag is cleared when this screen
    unmounts, and a later re-render — dismissing one of the cards, say — would
    otherwise re-read it as false and take all three away mid-interaction.
  */
  const [previewing] = useState(() => nudgePreviewArmed());
  useEffect(() => () => clearNudgePreview(), []);
  const items = useLiveQuery(() => activeItems(propertyId), [propertyId]);
  const docs = useLiveQuery(() => db.docs.toArray(), []);
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const subs = useLiveQuery(() => activeSubscriptions(propertyId), [propertyId]) ?? [];

  if (!items || !docs) return null;
  if (items.length === 0) return <EmptyHome onAdd={onAdd} />;

  const m = metricsFor(items, docs);

  // The reminders, such as they are. No push notification exists to deliver
  // these — see src/lib/nudges.ts — so the next time the app is opened is the
  // only moment there is to say anything.
  const nudges = (
    previewing
      ? sampleNudges()
      : dueNudges({ settings, itemCount: items.length, endingSoon: m.endingSoon })
  ).filter((n) => !hidden.includes(n.kind));

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

      <NudgeBar
        nudges={nudges}
        preview={previewing}
        onAct={(n) => (n.kind === 'warranty' ? onBrowse('ending') : onSettings())}
        onDismiss={(n) => setHidden((h) => [...h, n.kind])}
      />

      {/*
        Renewals, and the only place they can be said. There is no push
        notification — nothing runs while the app is closed — so opening the
        app is the entire delivery mechanism, and the wording on the
        subscription form says exactly that rather than promising an alert.
      */}
      <RenewalNudges subs={subs} onOpen={onSubs} />

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

      {/*
        Money last. Everything above is about the things you own, which is what
        the app is for; this is the running cost underneath it, and it reads
        better as the note the dashboard finishes on than as an interruption
        between the collection and the recent additions.
      */}
      <SubsBlock subs={subs} currency={settings?.currency ?? 'USD'} onOpen={onSubs} />
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

/**
 * The subscription half of the dashboard, built to the same plan as the item
 * half above it: a picture, then the two numbers, then the one thing next, then
 * the jobs.
 *
 * It used to be a single card with a big number and two rows of context. That
 * gave the running cost of your life the same weight as a "recently added"
 * strip, and it answered exactly one question — how much — which is the
 * question you already know the answer to within about twenty percent.
 */
function SubsBlock({
  subs,
  currency,
  onOpen,
}: {
  subs: Subscription[];
  currency: string;
  onOpen: () => void;
}) {
  if (subs.length === 0) return null;

  const now = new Date();
  const soonest = [...subs].sort(
    (a, b) => (daysUntilRenewal(a, now) ?? 999) - (daysUntilRenewal(b, now) ?? 999),
  )[0]!;
  const left = daysUntilRenewal(soonest, now);
  const jobs = subGaps(subs, now);

  return (
    <>
      <div className="seclabel" style={{ marginTop: 28 }}>
        <span>Subscriptions</span>
        <button type="button" className="linkish" onClick={onOpen}>
          See all
        </button>
      </div>

      <SpendCard subs={subs} currency={currency} onOpen={onOpen} />

      {/* The same two tiles as the items above, in the same type. */}
      <div className="bigmetrics">
        <div className="bigmetric">
          <strong>{shortMoney({ currency, cents: totalYearlyCents(subs) })}</strong>
          <span>a year</span>
        </div>
        <div className="bigmetric">
          <strong>{formatMoney(Math.round(dailyCents(subs)), currency)}</strong>
          <span>a day, on average</span>
        </div>
      </div>

      {/* "Next to expire" has a twin. Same row, same countdown on the right. */}
      <button type="button" className="nextup" onClick={onOpen}>
        <ServiceMark
          serviceId={soonest.serviceId}
          logoBlobId={soonest.logoBlobId}
          name={soonest.name}
          size={40}
        />
        <span className="nextup-txt">
          <span className="fieldlabel">Next to renew</span>
          <strong>{soonest.name}</strong>
          <small>
            {renewsOn(soonest)} · {formatMoney(soonest.amountCents, soonest.currency)}
          </small>
        </span>
        <span className={`renewin${left !== null && left <= 7 ? ' close' : ''}`}>
          <strong>{left ?? '—'}</strong>
          <small>{left === 1 ? 'day' : 'days'}</small>
        </span>
      </button>

      {jobs.length > 0 && (
        <div className="card needscard subneeds">
          <div className="needsbody">
            {/*
              Not "Needs a minute" — that heading already belongs to the item
              gaps a few hundred pixels up, and two identical headings meaning
              two different things is worse than either name being imperfect.
              This one is about money leaving, so it says so.
            */}
            <div className="cardhead">
              <h3>Money about to move</h3>
              <span className="countpill">
                {formatMoney(
                  jobs.reduce((n, g) => n + g.cents, 0),
                  currency,
                )}
              </span>
            </div>

            {jobs.map((gap) => (
              <button key={gap.kind} type="button" className="needrow" onClick={onOpen}>
                <span className="needcount">{gap.count}</span>
                <span className="needtxt">
                  <strong>{gap.label}</strong>
                  <small>{gap.why}</small>
                </span>
                <Chevron />
              </button>
            ))}
          </div>
        </div>
      )}
    </>
  );
}

/**
 * Six months of real charges, as bars.
 *
 * THE POINT OF DRAWING THIS. Every other figure on the screen is an average,
 * and an average hides the only thing about subscription spending that ever
 * catches anyone out: it isn't level. Three annual plans that happen to renew
 * in the same month make that month cost four times its neighbours, and no
 * amount of looking at "$94 a month" will tell you which month to brace for.
 *
 * THE DASHED LINE is the monthly average, drawn across the actual bars. It's
 * there to be disagreed with. The gap between the line and the tall bar is the
 * difference between the two numbers this app keeps carefully apart — what
 * subscriptions cost you, and what actually leaves in March — and one glance
 * at it explains that better than the sentence you're reading.
 */
function SpendCard({
  subs,
  currency,
  onOpen,
}: {
  subs: Subscription[];
  currency: string;
  onOpen: () => void;
}) {
  const now = new Date();
  const spend = spendByMonth(subs, 6, now);
  const monthly = totalMonthlyCents(subs);
  const peak = Math.max(monthly, ...spend.map((m) => m.cents));

  // Everything is drawn against the taller of the peak month and the average
  // line, so the line can never fall off the top of its own chart.
  const height = (cents: number) => (peak === 0 ? 0 : (cents / peak) * 100);

  return (
    <button type="button" className="spendcard" onClick={onOpen}>
      <span className="spendhero">
        <strong>{formatMoney(monthly, currency)}</strong>
        <span>
          a month across {subs.length} {subs.length === 1 ? 'service' : 'services'}
        </span>
      </span>

      <span className="spendchart">
        <i className="spendavg" style={{ bottom: `${height(monthly)}%` }} aria-hidden="true" />
        {spend.map((m, i) => (
          <span
            key={`${m.year}-${m.month}`}
            className={`spendcol${i === 0 ? ' now' : ''}`}
            title={`${monthName(m, 'long')} — ${formatMoney(m.cents, currency)}, ${m.count} ${
              m.count === 1 ? 'charge' : 'charges'
            }`}
          >
            <i style={{ height: `${height(m.cents)}%` }} />
            <em>{monthName(m, 'short')}</em>
          </span>
        ))}
      </span>

      <span className="spendnote">{spendNote(spend, currency)}</span>
    </button>
  );
}

/**
 * One sentence about the chart, and only when there's a sentence to write.
 *
 * The threshold matters more than the wording. Naming a "heaviest month" that
 * costs four percent more than its neighbours is the dashboard inventing a
 * finding, and a reader who checks one of those and finds nothing there stops
 * reading all of them.
 */
function spendNote(spend: MonthSpend[], currency: string): string {
  const top = heaviest(spend);
  const last = spend[spend.length - 1];
  if (!top || !last) return 'Nothing due in the next six months.';

  if (spread(spend) < 1.4) {
    return `Level from here to ${monthName(last, 'long')} — no month stands out.`;
  }

  return `${monthName(top, 'long')} is the heavy one: ${formatMoney(top.cents, currency)} across ${
    top.count
  } ${top.count === 1 ? 'charge' : 'charges'}.`;
}

function monthName(m: MonthSpend, length: 'short' | 'long'): string {
  return new Date(m.year, m.month, 1).toLocaleDateString(undefined, { month: length });
}

/** "Renews 20 Feb" — the date the countdown on the right doesn't carry. */
function renewsOn(sub: Subscription): string {
  const at = nextRenewal(sub);
  if (!at) return 'No renewal date';
  return `Renews ${at.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })}`;
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
