import { useEffect, useMemo, useRef, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeSubscriptions, deleteSubscription } from '@/db/repo';
import type { Subscription } from '@/db/types';
import { formatMoney } from '@/lib/warranty';
import {
  CADENCE_LABEL,
  daysUntilRenewal,
  monthlyCents,
  nextRenewal,
  heaviest,
  ordinal,
  renewalsInMonth,
  spendByMonth,
  spread,
  totalMonthlyCents,
  totalYearlyCents,
  type MonthSpend,
} from '@/lib/subscriptions';
import { feedback } from '@/lib/feedback';
import { ConfirmDelete } from '@/components/ConfirmDelete';
import { Scout } from '@/components/Scout';
import { SwipeRow } from '@/components/SwipeRow';
import { ServiceMark } from '@/components/ServiceMark';

const WEEKDAYS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/**
 * Everything you pay for on a repeating basis.
 *
 * A tab of its own rather than a segment on Items, because a subscription
 * isn't a thing in a room — it has no photo, no warranty and no paperwork, and
 * the questions you ask of it ("what am I spending", "what renews this week")
 * are not questions you ask of a kettle.
 *
 * The calendar is the reason this screen exists rather than being a list. A
 * list tells you what you pay for; a month grid tells you the 3rd is expensive
 * and the back half of the month is quiet, which is the thing you can actually
 * act on.
 */
export function Subs({
  propertyId,
  onOpen,
}: {
  propertyId: string;
  onOpen: (id: string) => void;
}) {
  const subs = useLiveQuery(() => activeSubscriptions(propertyId), [propertyId]);
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const currency = settings?.currency ?? 'USD';

  // The month being looked at, as an offset from this one. Kept as a number so
  // stepping across a year boundary is arithmetic rather than date handling.
  const [offset, setOffset] = useState(0);
  // One row open at a time, and a confirmation before anything goes.
  const [swiped, setSwiped] = useState<string | null>(null);
  /*
    A day tapped on the calendar, as a day number in the month on screen.

    The grid answers "when", and until now that was the end of it — you could
    see the 3rd was expensive and had to go hunting for what was on it. Tapping
    a day picks out the rows below, which is the question the dot was always
    provoking.
  */
  const [picked, setPicked] = useState<number | null>(null);
  const [confirming, setConfirming] = useState<Subscription | null>(null);
  /*
    The first highlighted row, so a pick that lands below the fold is scrolled
    to. `block: 'nearest'` on purpose: a row already on screen must not move,
    because the calendar you just tapped is directly above it and shoving that
    off the top to centre a row you can already see is the app taking the
    screen away as a reward for using it.
  */
  const firstPicked = useRef<HTMLButtonElement>(null);
  const now = new Date();
  const shown = new Date(now.getFullYear(), now.getMonth() + offset, 1);

  const marks = useMemo(
    () => (subs ? renewalsInMonth(subs, shown.getFullYear(), shown.getMonth(), now) : []),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [subs, offset],
  );

  // Paging the month clears the pick: day 3 of September is not the day you
  // selected, and leaving the highlight behind would claim otherwise.
  useEffect(() => setPicked(null), [offset]);

  // Bring the first highlighted row up only if it isn't already visible.
  useEffect(() => {
    if (picked === null) return;
    firstPicked.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }, [picked]);

  /*
    What the month on screen actually costs — the fourth figure.

    It follows the calendar rather than staying on today, so paging forward
    answers "and what about November". `shown` is the 1st of that month and
    spendByMonth reads whole calendar months from wherever it's pointed.

    NULL FOR ANY MONTH ALREADY GONE, and this is the important part. Pointed at
    June it returns $0.00, because an anchor date is one real renewal — usually
    the next one — and says nothing whatever about whether you were paying for
    Netflix in June. A confident "$0.00" there is the app claiming to know
    something it has no record of, and the grid underneath is blank for past
    months for exactly the same reason.
  */
  const thisMonth = useMemo(
    () => (subs && offset >= 0 ? spendByMonth(subs, 1, shown)[0]!.cents : null),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [subs, offset],
  );

  if (!subs) return null;

  const monthly = totalMonthlyCents(subs);
  const yearly = totalYearlyCents(subs);
  const soonest = [...subs].sort(
    (a, b) => (daysUntilRenewal(a, now) ?? 999) - (daysUntilRenewal(b, now) ?? 999),
  )[0];

  const pickedSubs = picked === null ? [] : (marks.find((m) => m.day === picked)?.subs ?? []);
  const pickedIds = new Set(pickedSubs.map((s) => s.id));

  return (
    <>
      <header className="apphead">
        <div className="apptitle">Subscriptions</div>
      </header>

      {subs.length === 0 ? (
        <div className="empty">
          <Scout pose="calendar" height={170} motion={['float']} shadow alt="" />
          <h3>Nothing tracked yet</h3>
          <p>
            Netflix, the gym, the phone plan. Tap <b>Stash it</b> and choose Subscription, and
            Scout will tell you what it costs a month and what's coming up.
          </p>
        </div>
      ) : (
        <>
          {/*
            The masthead: four figures on the left, Scout on the right — the
            same arrangement as Items and Settings.

            He stood beside the calendar before, which was the better joke (he
            is holding one) and the worse screen. It introduced the tab halfway
            down the page, where the other two do it at the top, and it cost
            the calendar a third of its width on the one screen with a
            seven-column grid to fit.

            Three figures across was also narrow enough to clip a four-figure
            total. Two by two gives each one room, and squares the block off
            against his height.
          */}
          <div className="subshead">
            <div className="subtotals">
              {/* `lead` is the gold one. What a month costs is what the tab is
                  about; the other three are context for it. */}
              <div className="subtotal lead">
                <strong>{formatMoney(monthly, currency)}</strong>
                <small>a month</small>
              </div>
              <div className="subtotal">
                <strong>{formatMoney(yearly, currency)}</strong>
                <small>a year</small>
              </div>
              <div className="subtotal">
                <strong>{subs.length}</strong>
                <small>{subs.length === 1 ? 'service' : 'services'}</small>
              </div>
              {/*
                The new one, and the only figure here that isn't an average:
                what the month on screen actually costs, at full price on the
                real dates. It totals the calendar directly beneath it, and in
                a month holding an annual renewal it will disagree with the
                figure two along. That disagreement is the point — see
                dueWithin and totalMonthlyCents.

                "charges", not "due": by the 20th, most of the month's money
                has already gone, and the number counts it either way.
              */}
              <div className="subtotal">
                <strong>{thisMonth === null ? '—' : formatMoney(thisMonth, currency)}</strong>
                <small>
                  {thisMonth === null ? 'no record for ' : ''}
                  {shown.toLocaleDateString(undefined, { month: 'long' })}
                  {thisMonth === null ? '' : ' charges'}
                </small>
              </div>
            </div>

            <Scout pose="calendar" height={104} motion={['breathe']} alt="" />
          </div>

          <div className="calendar">
            <div className="calhead">
              <button
                type="button"
                className="iconbtn small"
                aria-label="Previous month"
                onClick={() => setOffset((o) => o - 1)}
              >
                <Chevron dir="left" />
              </button>
              <span>
                {shown.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}
              </span>
              <button
                type="button"
                className="iconbtn small"
                aria-label="Next month"
                onClick={() => setOffset((o) => o + 1)}
              >
                <Chevron dir="right" />
              </button>
            </div>

            <div className="calgrid">
              {WEEKDAYS.map((d, i) => (
                <span key={i} className="caldow">
                  {d}
                </span>
              ))}
              {buildMonth(shown).map((day, i) =>
                day === null ? (
                  <span key={`x${i}`} className="calcell empty" />
                ) : (
                  <Cell
                    key={day}
                    day={day}
                    today={isToday(shown, day, now)}
                    picked={picked === day}
                    subs={marks.find((m) => m.day === day)?.subs ?? []}
                    currency={currency}
                    onPick={() => {
                      feedback('tap');
                      setPicked((p) => (p === day ? null : day));
                    }}
                  />
                ),
              )}
            </div>
          </div>

          {/*
            The note answers whichever question is live. Tap a day and it is
            about that day; otherwise it is the standing "what's next". Two
            lines, one saying the same thing twice, would be worse than either.
          */}
          {pickedSubs.length > 0 ? (
            <p className="hint calnote">
              The {ordinal(picked!)}: <b>{pickedSubs.map((s) => s.name).join(', ')}</b> —{' '}
              {formatMoney(
                pickedSubs.reduce((n, s) => n + s.amountCents, 0),
                currency,
              )}
              .{' '}
              <button type="button" className="linkish" onClick={() => setPicked(null)}>
                Clear
              </button>
            </p>
          ) : (
            soonest && (
              <p className="hint calnote">
                Next up: <b>{soonest.name}</b> on the{' '}
                {ordinal(nextRenewal(soonest, now)?.getDate() ?? 1)},{' '}
                {formatMoney(soonest.amountCents, soonest.currency)}.
              </p>
            )
          )}

          <div className="seclabel">
            <span>Everything you pay for</span>
          </div>

          <ul className="sublist">
            {[...subs]
              .sort((a, b) => (daysUntilRenewal(a, now) ?? 999) - (daysUntilRenewal(b, now) ?? 999))
              .map((s) => (
                <li key={s.id}>
                  {/*
                    Same gesture as the items list, but the button asks first:
                    a subscription is hard-deleted, so there is no bin behind a
                    mis-tap the way there is for an item.
                  */}
                  <SwipeRow
                    open={swiped === s.id}
                    onOpenChange={(o) => setSwiped(o ? s.id : null)}
                    deleteLabel={`Delete ${s.name}`}
                    onDelete={() => setConfirming(s)}
                  >
                    <button
                      type="button"
                      className={`subrow${pickedIds.has(s.id) ? ' picked' : ''}`}
                      ref={pickedIds.has(s.id) ? firstPicked : undefined}
                      onClick={() => (swiped === s.id ? setSwiped(null) : onOpen(s.id))}
                    >
                      <ServiceMark
                        serviceId={s.serviceId}
                        logoBlobId={s.logoBlobId}
                        name={s.name}
                        size={36}
                      />
                      <span className="subtxt">
                        <strong>{s.name}</strong>
                        <small>
                          {/* No reminder state here. Reminders are a home-screen
                              thing — this screen is what you pay and when, and a
                              second place showing the same setting is a second
                              place for it to look wrong. */}
                          {CADENCE_LABEL[s.cadence]} · {ordinal(nextRenewal(s, now)?.getDate() ?? 1)}
                        </small>
                      </span>
                      <span className="subcost">
                        <strong>{formatMoney(s.amountCents, s.currency)}</strong>
                        {s.cadence !== 'monthly' && (
                          <small>{formatMoney(monthlyCents(s), s.currency)}/mo</small>
                        )}
                      </span>
                    </button>
                  </SwipeRow>
                </li>
              ))}
          </ul>

          {/*
            Last, and titled.

            It was on the dashboard, which answers "is anything wrong" — this
            answers "which month should I brace for", a question you only ask
            once you are already on this tab. And it sits below the list rather
            than above it: the pills and the calendar are about now, the list is
            what you pay for, and the year ahead is what you look at after all
            of that rather than before any of it.
          */}
          <div className="seclabel" style={{ marginTop: 26 }}>
            <span>The year ahead</span>
          </div>
          <SpendChart subs={subs} currency={currency} />
        </>
      )}

      {confirming && (
        <ConfirmDelete
          name={confirming.name}
          permanent
          onConfirm={() => {
            void deleteSubscription(confirming.id).then(() => feedback('delete'));
            setConfirming(null);
            setSwiped(null);
          }}
          onCancel={() => setConfirming(null)}
        />
      )}
    </>
  );
}

/**
 * Six months of real charges, as bars.
 *
 * THE POINT OF DRAWING THIS. Every other figure on this screen is an average,
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
 *
 * No hero figure on it any more: the four pills at the top of this screen
 * already say what a month costs, and saying it twice on one screen is worse
 * than saying it once anywhere.
 */
function SpendChart({ subs, currency }: { subs: Subscription[]; currency: string }) {
  const now = new Date();
  const spend = spendByMonth(subs, 6, now);
  const monthly = totalMonthlyCents(subs);
  const peak = Math.max(monthly, ...spend.map((m) => m.cents));

  // Everything is drawn against the taller of the peak month and the average
  // line, so the line can never fall off the top of its own chart.
  const height = (cents: number) => (peak === 0 ? 0 : (cents / peak) * 100);

  return (
    <div className="spendcard">
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
    </div>
  );
}

/**
 * One sentence about the chart, and only when there's a sentence to write.
 *
 * The threshold matters more than the wording. Naming a "heaviest month" that
 * costs four percent more than its neighbours is the screen inventing a
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

/** Leading blanks so the 1st lands under the right weekday, Monday first. */
function buildMonth(month: Date): (number | null)[] {
  const first = new Date(month.getFullYear(), month.getMonth(), 1);
  const lead = (first.getDay() + 6) % 7;
  const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  return [...Array(lead).fill(null), ...Array.from({ length: days }, (_, i) => i + 1)];
}

function isToday(month: Date, day: number, now: Date): boolean {
  return (
    month.getFullYear() === now.getFullYear() &&
    month.getMonth() === now.getMonth() &&
    day === now.getDate()
  );
}

/**
 * One day of the month.
 *
 * A day with something on it is a button; an empty one is not. The grid was
 * read-only before, which made the dots a tease — you could see the 3rd was
 * busy and then had to go and find out what was on it yourself. A day you
 * can't act on shouldn't offer a tap target, so the two cases are genuinely
 * different elements rather than one element with a disabled state.
 */
function Cell({
  day,
  today,
  picked,
  subs,
  currency,
  onPick,
}: {
  day: number;
  today: boolean;
  picked: boolean;
  subs: Subscription[];
  currency: string;
  onPick: () => void;
}) {
  const total = subs.reduce((sum, s) => sum + s.amountCents, 0);
  const classes = [
    'calcell',
    subs.length ? 'has' : '',
    today ? 'today' : '',
    picked ? 'picked' : '',
  ].filter(Boolean);

  const inside = (
    <>
      {day}
      {subs.length > 0 && (
        <span className="caldots">
          {/* Three at most. A day with five renewals is a day with a lot on it,
              not a day that needs five dots in a 30px box. */}
          {subs.slice(0, 3).map((s) => (
            <i key={s.id} />
          ))}
        </span>
      )}
    </>
  );

  if (subs.length === 0) return <span className={classes.join(' ')}>{inside}</span>;

  return (
    <button
      type="button"
      className={classes.join(' ')}
      aria-pressed={picked}
      aria-label={`${day}: ${subs.map((s) => s.name).join(', ')}`}
      title={`${subs.map((s) => s.name).join(', ')} — ${formatMoney(total, currency)}`}
      onClick={onPick}
    >
      {inside}
    </button>
  );
}

function Chevron({ dir }: { dir: 'left' | 'right' }) {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.2"
      strokeLinecap="round"
      aria-hidden="true"
    >
      <path d={dir === 'left' ? 'M15 5l-7 7 7 7' : 'M9 5l7 7-7 7'} />
    </svg>
  );
}
