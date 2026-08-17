import { useMemo, useState } from 'react';
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
  ordinal,
  renewalsInMonth,
  totalMonthlyCents,
  totalYearlyCents,
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
  const [confirming, setConfirming] = useState<Subscription | null>(null);
  const now = new Date();
  const shown = new Date(now.getFullYear(), now.getMonth() + offset, 1);

  const marks = useMemo(
    () => (subs ? renewalsInMonth(subs, shown.getFullYear(), shown.getMonth(), now) : []),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [subs, offset],
  );

  if (!subs) return null;

  const monthly = totalMonthlyCents(subs);
  const yearly = totalYearlyCents(subs);
  const soonest = [...subs].sort(
    (a, b) => (daysUntilRenewal(a, now) ?? 999) - (daysUntilRenewal(b, now) ?? 999),
  )[0];

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
          {/* What it costs, which is the question this screen mainly answers. */}
          <div className="subtotals">
            <div className="subtotal">
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
          </div>

          {/*
            Scout with the calendar, beside the calendar. He's the only thing
            on this screen that isn't a number, which is most of why he's here.
          */}
          <div className="calwrap">
            <div className="calmark">
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
                      subs={marks.find((m) => m.day === day)?.subs ?? []}
                      currency={currency}
                    />
                  ),
                )}
              </div>
            </div>
          </div>

          {soonest && (
            <p className="hint calnote">
              Next up: <b>{soonest.name}</b> on the{' '}
              {ordinal(nextRenewal(soonest, now)?.getDate() ?? 1)},{' '}
              {formatMoney(soonest.amountCents, soonest.currency)}.
            </p>
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
                      className="subrow"
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

function Cell({
  day,
  today,
  subs,
  currency,
}: {
  day: number;
  today: boolean;
  subs: Subscription[];
  currency: string;
}) {
  const total = subs.reduce((sum, s) => sum + s.amountCents, 0);
  const classes = ['calcell', subs.length ? 'has' : '', today ? 'today' : ''].filter(Boolean);

  return (
    <span
      className={classes.join(' ')}
      title={subs.length ? `${subs.map((s) => s.name).join(', ')} — ${formatMoney(total, currency)}` : undefined}
    >
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
    </span>
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
