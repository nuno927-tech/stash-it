import { useEffect, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItems, activePapers, activeSubscriptions } from '@/db/repo';
import type { Doc, Item, Subscription } from '@/db/types';
import { gapsFor, metricsFor, type GapKind } from '@/lib/dashboard';
import { greeting } from '@/lib/greeting';
import {
  clearNudgePreview,
  dueNudges,
  nudgePreviewArmed,
  sampleNudges,
  type NudgeKind,
} from '@/lib/nudges';
import { prefsFrom } from '@/lib/prefs';
import { dailyCents, totalMonthlyCents, totalYearlyCents } from '@/lib/subscriptions';
import {
  buildTimeline,
  datedTally,
  whenLabel,
  type DatedTally,
  type Entry,
  type Urgency,
} from '@/lib/timeline';
import { coverageArcs, formatMoney, warrantyDateLabel } from '@/lib/warranty';
import type { ItemsFilter } from '@/screens/Items';
import { ItemIcon } from '@/components/ItemIcon';
import { NudgeBar } from '@/components/NudgeBar';
import { Scout } from '@/components/Scout';
import { WarrantyRing } from '@/components/WarrantyRing';
import { useThumbUrl } from '@/components/useThumbUrl';

/**
 * The dashboard. Home answers the questions you'd ask about the collection as
 * a whole; Items answers "what do I own".
 *
 * ── One hub, not three dashboards ────────────────────────────────────────
 * It used to be the same four-part block three times over — a headline
 * visual, two metrics, a "next up" row and a jobs card, once for items, once
 * for subscriptions, once for documents. Sixteen blocks, and answering "what
 * needs me" meant scrolling past everything twice while three separate
 * next-up rows each sorted only against their own kind.
 *
 * Now: what state everything is in, what it costs to run, what is coming, and
 * what needs a minute. The ranking that makes the third of those work lives in
 * lib/timeline.
 */
export function Home({
  propertyId,
  onAdd,
  onOpenItem,
  onBrowse,
  onSettings,
  onSubs,
  onOpenSub,
  onOpenPaper,
}: {
  propertyId: string;
  onAdd: () => void;
  onOpenItem: (id: string) => void;
  onBrowse: (filter?: ItemsFilter) => void;
  /** Where every nudge sends you — each one is answered in Settings. */
  onSettings: () => void;
  /** The running-cost card. Documents have no card of their own any more —
      they live in the timeline, which opens the record itself. */
  onSubs: () => void;
  /* The timeline mixes all three kinds, so a row has to open the actual
     record. Sending a tap on Netflix to "the subscriptions tab" would be the
     merged list handing the user back the sorting job it just did for them. */
  onOpenSub: (id: string) => void;
  onOpenPaper: (id: string) => void;
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
  const papers = useLiveQuery(() => activePapers(propertyId), [propertyId]) ?? [];

  if (!items || !docs) return null;
  if (items.length === 0) return <EmptyHome onAdd={onAdd} />;

  const m = metricsFor(items, docs);
  const tally = datedTally(items, papers);
  const timeline = buildTimeline(items, subs, papers);

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

      {/*
        The only banner left, and it survives because it is about the app
        rather than about your things: a backup overdue, the item cap. Four
        others used to stack here — renewals, documents, warranties, nudges —
        each announcing something the list further down was about to list
        again. The timeline leads with what is overdue, so a card above it
        saying "4 things need you" was the same sentence twice.
      */}
      <NudgeBar
        nudges={nudges}
        preview={previewing}
        onAct={(n) => (n.kind === 'warranty' ? onBrowse('ending') : onSettings())}
        onDismiss={(n) => setHidden((h) => [...h, n.kind])}
      />

      <CoverCard tally={tally} onBrowse={onBrowse} />

      {/* The running cost, above the timeline: it frames the renewals in it
          rather than trailing them as a footnote. The six-month chart lives on
          the subscriptions tab now — it answers a question about that tab. */}
      <RunningCost subs={subs} currency={settings?.currency ?? 'USD'} onOpen={onSubs} />

      <ComingUp
        entries={timeline}
        onOpenItem={onOpenItem}
        onOpenSub={onOpenSub}
        onOpenPaper={onOpenPaper}
      />

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
  tally,
  onBrowse,
}: {
  tally: DatedTally;
  onBrowse: (filter?: ItemsFilter) => void;
}) {
  /*
    THREE ARCS, NOT FOUR. Undated records aren't drawn and aren't in the
    divisor — see datedTally for the argument. Drawing a grey wedge that the
    percentage ignores would leave the picture and the number disagreeing, and
    putting it in the divisor would drop your score for adding a record. It's
    reported beside the ring instead, where it reads as a job rather than a
    failure.
  */
  const slices = [
    { n: tally.inDate, colour: 'var(--moss)' },
    { n: tally.needsStarting, colour: 'var(--honey)' },
    { n: tally.lapsed, colour: 'var(--ember)' },
  ].filter((s) => s.n > 0);
  const tracked = tally.inDate + tally.needsStarting + tally.lapsed;

  // Smaller than it was alone, because Scout now stands beside it rather than
  // perching in a corner. A 208 ring and a mascot worth looking at don't both
  // fit across a phone, and a mascot too small to read is just clutter.
  const size = 176;
  const stroke = 6;
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;

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
              const share = s.n / Math.max(1, tracked);
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
              {tally.percent}
              <i>%</i>
            </strong>
            <span>still in date</span>
          </div>
        </div>

        <Scout pose="report" height={148} motion={['breathe']} alt="" />
      </div>

      {/*
        The three you can act on are buttons; "in date" is not, because there
        is nothing to do about something that is fine.

        THEY LAND ON THE ITEMS LIST, and that is worth knowing about. Each
        count spans two kinds — a lapsed warranty and an expired passport both
        sit in "lapsed" — while the filters they open are items only, so the
        chip you arrive at can read a smaller number than the one you tapped.
        The alternative was leaving them dead, which was the previous answer
        and a worse one: a number you can see needs dealing with and cannot
        touch. Documents in the same state are sorted to the top of their own
        tab, which is where the timeline above sends them.
      */}
      <div className="coverstats">
        <Stat n={tally.inDate} label="in date" tone="moss" />
        <Stat
          n={tally.needsStarting}
          label="action needed"
          tone="honey"
          onClick={() => onBrowse('ending')}
        />
        <Stat n={tally.lapsed} label="lapsed" tone="ember" onClick={() => onBrowse('expired')} />
        <Stat n={tally.noDate} label="no date" tone="none" onClick={() => onBrowse('nowarranty')} />
      </div>

      <p className="coverfoot">
        Across <b>{tally.items}</b> {tally.items === 1 ? 'item' : 'items'} and <b>{tally.papers}</b>{' '}
        {tally.papers === 1 ? 'document' : 'documents'}
        {/* Subscriptions are counted nowhere in this ring, on purpose: one
            cannot lapse, so nine of them would be nine units of health the app
            was never at risk of losing. */}
      </p>
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

/**
 * A recently-added item: the ring says how it's doing, the line underneath
 * says until when.
 *
 * THE PROBLEM THIS SOLVES, on its third attempt. The countdown was a chip
 * lying on the photograph — first a 10px one on a translucent wash, then a
 * 12px one on an opaque base — and neither was legible. The second attempt
 * fixed the contrast and missed the rest of it: the string it was rendering
 * was "2y 4m", an abbreviation that exists purely because the chip was small.
 * Four characters of jargon over a picture of a fridge give the eye nothing to
 * recover from, at any contrast.
 *
 * So nothing on the photo is words any more. The ring carries the state — the
 * same ring, drawn by the same component, as every row of the items list, so
 * it needs no learning — and the sentence moved down onto the solid card
 * where nothing can wash it out. On a dark disc, because a ring on a
 * translucent wash has the same problem the chip had.
 *
 * The brand and the year went to make room. You can generally see the brand in
 * the photograph, and the year of purchase was never why anyone tapped a tile.
 */
function RecentCard({ item, onOpen }: { item: Item; onOpen: (id: string) => void }) {
  const thumb = useThumbUrl(item.thumbBlobId);

  return (
    <button type="button" className="recenttile" onClick={() => onOpen(item.id)}>
      <span className="recentart">
        {thumb ? <img src={thumb} alt="" /> : <ItemIcon item={item} size={34} />}
        <span className="recentring">
          {/* 28 inside a 34 disc — see .recentring, which insets it so the
              outermost arc doesn't graze the rim. */}
          <WarrantyRing size={28} stroke={3} arcs={coverageArcs(item)} />
        </span>
      </span>
      <strong>{item.name}</strong>
      <small>{warrantyDateLabel(item)}</small>
    </button>
  );
}

/**
 * Everything with a date on it, in one list, worst first.
 *
 * This replaces three separate "next up" rows — one per kind, each sorted only
 * against its own. The ranking lives in lib/timeline; all this does is draw it
 * and decide how much of it to show.
 *
 * FIVE, THEN THE REST BEHIND A TAP. Long enough that the flagged rows are
 * always visible on a normal week, short enough that nine monthly
 * subscriptions can't push the recently-added strip off the bottom of the
 * world. There is no "see all" link because there is nowhere to send you: this
 * list spans three tabs and exists only here.
 */
const SHOWN = 5;

const URGENCY_TONE: Record<Urgency, string> = {
  overdue: 'dead',
  now: 'warn',
  soon: 'gold',
  later: 'ok',
};

function ComingUp({
  entries,
  onOpenItem,
  onOpenSub,
  onOpenPaper,
}: {
  entries: Entry[];
  onOpenItem: (id: string) => void;
  onOpenSub: (id: string) => void;
  onOpenPaper: (id: string) => void;
}) {
  const [expanded, setExpanded] = useState(false);

  if (entries.length === 0) return <AllClear />;

  const shown = expanded ? entries : entries.slice(0, SHOWN);
  const rest = entries.length - shown.length;
  const open = (e: Entry) =>
    e.kind === 'item' ? onOpenItem(e.id) : e.kind === 'subscription' ? onOpenSub(e.id) : onOpenPaper(e.id);

  return (
    <>
      <div className="seclabel" style={{ marginTop: 24 }}>
        <span>Coming up</span>
      </div>

      <ul className="duelist">
        {shown.map((e) => (
          <li key={e.key}>
            <button
              type="button"
              className={`duerow${e.flagged ? ' flagged' : ''}`}
              onClick={() => open(e)}
            >
              <i className={`dot ${URGENCY_TONE[e.urgency]}`} aria-hidden="true" />
              <span className="duetxt">
                <strong>{e.title}</strong>
                <small>{e.detail}</small>
              </span>
              <span className={`duewhen ${URGENCY_TONE[e.urgency]}`}>{whenLabel(e)}</span>
            </button>
          </li>
        ))}
      </ul>

      {rest > 0 && (
        <button type="button" className="duemore" onClick={() => setExpanded(true)}>
          Show {rest} more
        </button>
      )}
    </>
  );
}


/**
 * Nothing due, which is the one state the old dashboard never drew.
 *
 * It had three "next up" rows and each of them always had something in it, so
 * there was no moment where the app got to say you were finished. Scout asleep
 * is that moment.
 */
function AllClear() {
  return (
    <>
      <div className="seclabel" style={{ marginTop: 24 }}>
        <span>Coming up</span>
      </div>
      <div className="card allclear">
        <Scout pose="resting" height={96} motion={['breathe']} alt="" />
        <span>
          <strong>Nothing needs a date watched</strong>
          <small>
            No warranty, renewal or document is close enough to worry about. Scout will say
            something before anything lapses.
          </small>
        </span>
      </div>
    </>
  );
}

/**
 * What the subscriptions cost, in one line.
 *
 * Above the timeline rather than below it, so it frames the renewals in the
 * list instead of trailing them as a footnote. The six-month chart that used
 * to sit here has moved to the subscriptions tab — it answers a question about
 * that tab, and the dashboard is not where anyone goes to study November.
 */
function RunningCost({
  subs,
  currency,
  onOpen,
}: {
  subs: Subscription[];
  currency: string;
  onOpen: () => void;
}) {
  if (subs.length === 0) return null;
  const perDay = dailyCents(subs);

  return (
    <div className="runcost">
      {/*
        Only the count is a button. It is the one that has somewhere to go —
        the subscriptions tab is the list of those services. The two money
        tiles have no destination of their own: tapping "$135 a month" would
        land you on the same list, and three routes to one screen is three
        chances to wonder whether they differ.
      */}
      <button type="button" className="runtile" onClick={onOpen}>
        <strong>{subs.length}</strong>
        <span>{subs.length === 1 ? 'service' : 'services'}</span>
      </button>

      <div className="runtile">
        <strong>{formatMoney(totalMonthlyCents(subs), currency)}</strong>
        <span>a month</span>
      </div>

      {/*
        The two framings of the same money, together in the third tile. A day
        rate is a coffee and a yearly total is a holiday; they belong to each
        other, and neither is the headline.
      */}
      <div className="runtile">
        <strong className="runsmall">{formatMoney(Math.round(perDay), currency)}</strong>
        <span>a day</span>
        <strong className="runsmall">{formatMoney(totalYearlyCents(subs), currency)}</strong>
        <span>a year</span>
      </div>
    </div>
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
