import acorn from '@/assets/mascot/scout-acorn.webp';
import alert from '@/assets/mascot/scout-alert.webp';
import avatar from '@/assets/mascot/scout-avatar.webp';
import stand from '@/assets/mascot/scout-stand.webp';
import wave from '@/assets/mascot/scout-wave.webp';

/**
 * Scout, the mascot. Poses are imported rather than referenced from /public so
 * the single-file build can inline them — see `npm run build:single`.
 *
 * Motion rule from the concept: combine at most two primitives. Float plus
 * breathe reads alive; adding a third reads seasick.
 */

export type ScoutPose = 'acorn' | 'wave' | 'stand' | 'alert' | 'avatar';
export type ScoutMotion = 'float' | 'breathe' | 'alert' | 'pop' | 'none';

const SRC: Record<ScoutPose, string> = { acorn, wave, stand, alert, avatar };

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
