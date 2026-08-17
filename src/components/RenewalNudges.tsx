import type { Subscription } from '@/db/types';
import { daysUntilRenewal, dueReminders, renewalLabel } from '@/lib/subscriptions';
import { formatMoney } from '@/lib/warranty';
import { ServiceMark } from './ServiceMark';

/**
 * Subscriptions about to renew, on the home screen.
 *
 * This is the whole of "reminders" until there's a server. Nothing runs while
 * the app is closed, so opening it is the only moment anything can be said —
 * which means this card has to be the first thing on the dashboard, and the
 * setting that turns it on has to describe it honestly rather than as an
 * alert. Both of those are done: see the note on the subscription form.
 *
 * Only shows what was actually asked for. A subscription with no reminder set
 * never appears here however close its renewal is, because the alternative is
 * an app that decides for you which charges are worth worrying about.
 */
export function RenewalNudges({
  subs,
  onOpen,
}: {
  subs: Subscription[];
  onOpen: () => void;
}) {
  const due = dueReminders(subs);
  if (due.length === 0) return null;

  return (
    <div className="renewbar">
      {due.slice(0, 3).map((s) => {
        const days = daysUntilRenewal(s);
        return (
          <button key={s.id} type="button" className="renewcard" onClick={onOpen}>
            <ServiceMark serviceId={s.serviceId} logoBlobId={s.logoBlobId} name={s.name} size={32} />
            <span className="renewtxt">
              <strong>{s.name}</strong>
              <small>
                {renewalLabel(days)} · {formatMoney(s.amountCents, s.currency)}
              </small>
            </span>
            {/* Today and tomorrow are the ones worth a colour. Anything
                further out is information, not urgency. */}
            {days !== null && days <= 1 && <i className="renewsoon" aria-hidden="true" />}
          </button>
        );
      })}

      {due.length > 3 && (
        <button type="button" className="linkish morelink" onClick={onOpen}>
          {due.length - 3} more renewing soon
        </button>
      )}
    </div>
  );
}
