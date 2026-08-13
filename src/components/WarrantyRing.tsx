import type { WarrantyState } from '@/lib/warranty';

export const STATE_STROKE: Record<WarrantyState, string> = {
  covered: 'var(--moss)',
  'ending-soon': 'var(--honey)',
  expired: 'var(--ember)',
  unknown: 'var(--slate-600)',
};

/**
 * Four, and the reason is arithmetic rather than taste. Each ring needs its
 * stroke plus a gap; at 50px across, a fifth leaves about a pixel and a half
 * per arc and the stack turns into a smudge. Items with more than four
 * policies draw their four soonest — which are the ones worth knowing about,
 * since the list is sorted by what ends first — and the item page has the
 * rest.
 */
export const MAX_RINGS = 4;

/**
 * Centre-to-centre distance between stacked arcs. Exported because the
 * thumbnail underneath has to give up exactly this much room per extra ring —
 * two numbers that disagree would put a photo corner over an arc.
 */
export const RING_STEP = 3.6;

export interface RingArc {
  /** 0..1 remaining. */
  progress: number;
  state: WarrantyState;
}

/**
 * Progress ring around a thumbnail — one arc per policy, outermost expiring
 * first. Rotation to 12 o'clock is done in CSS (`.ring`) so the dash maths
 * here stays readable.
 *
 * One policy draws exactly what it always did: a single ring at the given
 * stroke. The stack only appears when there's a stack to show, so the ordinary
 * item is untouched and the busy one says so at a glance.
 */
export function WarrantyRing({
  size,
  stroke,
  arcs,
}: {
  size: number;
  stroke: number;
  /** Soonest to lapse first. Only the first MAX_RINGS are drawn. */
  arcs: RingArc[];
}) {
  const shown = arcs.slice(0, MAX_RINGS);
  if (shown.length === 0) return null;

  // Thinner strokes once they're stacked, so four rings occupy roughly the
  // band one thick ring would. The gap is what keeps them countable.
  const w = shown.length > 1 ? Math.max(1.8, stroke * 0.72) : stroke;
  const step = RING_STEP;

  return (
    <svg className="ring" width={size} height={size} aria-hidden="true">
      {shown.map((arc, i) => {
        const r = (size - w) / 2 - i * step;
        if (r <= 0) return null;
        const c = 2 * Math.PI * r;
        // An expired or unknown policy draws track only — a stub of colour
        // reads as "a little cover left", which is exactly wrong.
        const p = arc.state === 'expired' || arc.state === 'unknown' ? 0 : arc.progress;

        return (
          <g key={i}>
            <circle className="track" cx={size / 2} cy={size / 2} r={r} strokeWidth={w} />
            {p > 0 && (
              <circle
                cx={size / 2}
                cy={size / 2}
                r={r}
                strokeWidth={w}
                stroke={STATE_STROKE[arc.state]}
                strokeDasharray={c}
                strokeDashoffset={c * (1 - p)}
              />
            )}
          </g>
        );
      })}
    </svg>
  );
}
