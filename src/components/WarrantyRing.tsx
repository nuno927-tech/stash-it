import type { WarrantyState } from '@/lib/warranty';

export const STATE_STROKE: Record<WarrantyState, string> = {
  covered: 'var(--moss)',
  'ending-soon': 'var(--honey)',
  expired: 'var(--ember)',
  unknown: 'var(--slate-600)',
};

/**
 * Progress ring around a thumbnail. Rotation to 12 o'clock is done in CSS
 * (`.ring`) so the dash maths here stays readable.
 */
export function WarrantyRing({
  size,
  stroke,
  progress,
  state,
}: {
  size: number;
  stroke: number;
  /** 0..1 remaining. */
  progress: number;
  state: WarrantyState;
}) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  // An expired or unknown item draws track only — a stub of colour reads as
  // "a little cover left", which is exactly wrong.
  const shown = state === 'expired' || state === 'unknown' ? 0 : progress;

  return (
    <svg className="ring" width={size} height={size} aria-hidden="true">
      <circle className="track" cx={size / 2} cy={size / 2} r={r} strokeWidth={stroke} />
      {shown > 0 && (
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          strokeWidth={stroke}
          stroke={STATE_STROKE[state]}
          strokeDasharray={c}
          strokeDashoffset={c * (1 - shown)}
        />
      )}
    </svg>
  );
}
