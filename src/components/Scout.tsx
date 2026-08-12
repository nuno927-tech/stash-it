import acorn from '@/assets/mascot/scout-acorn.webp';
import alert from '@/assets/mascot/scout-alert.webp';
import receipt from '@/assets/mascot/scout-receipt.webp';
import report from '@/assets/mascot/scout-report.webp';
import resting from '@/assets/mascot/scout-resting.webp';
import settings from '@/assets/mascot/scout-settings.webp';
import waving from '@/assets/mascot/scout-waving.webp';

/**
 * Scout, the mascot. Poses are imported rather than referenced from /public so
 * the single-file build can inline them — see `npm run build:single`.
 *
 * Each pose means something, and the meaning is the point of having eight of
 * them rather than one. Scout asleep on a card with nothing left to do says
 * "you're finished" more plainly than the sentence next to it does.
 *
 *   acorn     guarding the thing itself — launch, install
 *   waving    hello — first run, and only first run
 *   report    presenting your numbers — the dashboard
 *   receipt   holding the paperwork — items
 *   settings  at a control desk — settings
 *   alert     ears up, something needs you
 *   resting   curled up, nothing does
 *
 * Cut from paired renders — see scripts/mascot.mjs. Every pose has a real
 * alpha channel including its contact shadow, so they sit on cream and on
 * slate without a plate behind them.
 *
 * Motion rule from the concept: combine at most two primitives. Float plus
 * breathe reads alive; adding a third reads seasick.
 */

export type ScoutPose =
  | 'acorn'
  | 'waving'
  | 'report'
  | 'receipt'
  | 'settings'
  | 'alert'
  | 'resting';

export type ScoutMotion = 'float' | 'breathe' | 'alert' | 'pop' | 'none';

const SRC: Record<ScoutPose, string> = {
  acorn,
  waving,
  report,
  receipt,
  settings,
  alert,
  resting,
};

const MOTION_CLASS: Record<ScoutMotion, string> = {
  float: 'm-float',
  breathe: 'm-breathe',
  alert: 'm-alert',
  pop: 'm-pop',
  none: '',
};

export function Scout({
  pose,
  height,
  motion = [],
  shadow = false,
  alt = '',
}: {
  pose: ScoutPose;
  height: number;
  motion?: ScoutMotion[];
  shadow?: boolean;
  alt?: string;
}) {
  const classes = ['rig', ...motion.map((m) => MOTION_CLASS[m])].filter(Boolean).join(' ');
  return (
    <div className={classes}>
      <img src={SRC[pose]} height={height} alt={alt} />
      {shadow && <div className="shadow" />}
    </div>
  );
}
