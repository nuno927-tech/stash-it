import type { Item } from '@/db/types';
import { phoneHref } from '@/lib/format';
import {
  coverageLabel,
  coverageParts,
  coverageSchedule,
  coverageState,
  coverageTermLabel,
  type WarrantyState,
} from '@/lib/warranty';

/**
 * Every policy on the item, soonest to lapse at the top.
 *
 * The order is the point. A couch with a lifetime frame and twelve months on
 * the fabric is not "covered for life" in any sense its owner cares about —
 * what will actually go wrong and stop being covered is the fabric, and it's
 * three months away. Sorted this way, the answer is the first line.
 *
 * Lifetime sits at the bottom with no number. It never counts down and never
 * warns, but it's a real promise and belongs in the list a claim is read from.
 */

const TONE: Record<WarrantyState, string> = {
  covered: 'ok',
  'ending-soon': 'warn',
  expired: 'dead',
  unknown: 'none',
};

export function CoverList({ item }: { item: Item }) {
  const schedule = coverageSchedule(item);
  if (schedule.length === 0) return null;

  return (
    <>
      <div className="seclabel">
        <span>Cover</span>
        {schedule.length > 1 && <span>{schedule.length} policies</span>}
      </div>

      {schedule.map((d) => {
        const c = d.coverage;
        const left = coverageParts(d);
        const lapsed = d.daysLeft !== null && d.daysLeft < 0;
        // Lifetime is 'covered' as a state but shouldn't wear the green a
        // running countdown earns — there's nothing counting.
        const tone = d.end ? TONE[coverageState(d, item)] : TONE.unknown;

        return (
          <div key={c.id} className={`cov${lapsed ? ' lapsed' : ''}`}>
            <span className="cov-txt">
              <b>{coverageLabel(c)}</b>
              <s>{[coverageTermLabel(c), c.provider].filter(Boolean).join(' · ')}</s>
              {/* What it actually pays for. The line nobody remembers three
                  years later, and the one a claim turns on. */}
              {c.covers && <em>{c.covers}</em>}

              {(c.phone || c.url) && (
                <span className="covlinks">
                  {c.phone && (
                    <a className="pick" href={`tel:${phoneHref(c.phone)}`}>
                      Call {c.provider ?? 'provider'}
                    </a>
                  )}
                  {c.url && (
                    <a className="pick" href={c.url} target="_blank" rel="noreferrer">
                      Policy page
                    </a>
                  )}
                  {c.policyNumber && <span className="covpolicy">{c.policyNumber}</span>}
                </span>
              )}
            </span>

            <span className={`timeleft ${tone}${/^\d+$/.test(left.value) ? '' : ' wordy'}`}>
              <strong>{left.value}</strong>
              <small>{left.unit}</small>
            </span>
          </div>
        );
      })}
    </>
  );
}
