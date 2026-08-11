import acorn from '@/assets/mascot/nutsy-acorn.webp';
import alert from '@/assets/mascot/nutsy-alert.webp';
import avatar from '@/assets/mascot/nutsy-avatar.webp';
import stand from '@/assets/mascot/nutsy-stand.webp';
import wave from '@/assets/mascot/nutsy-wave.webp';

/**
 * The mascot. Poses are imported rather than referenced from /public so the
 * single-file build can inline them — see `npm run build:single`.
 *
 * Motion rule from the concept: combine at most two primitives. Float plus
 * breathe reads alive; adding a third reads seasick.
 */

export type NutsyPose = 'acorn' | 'wave' | 'stand' | 'alert' | 'avatar';
export type NutsyMotion = 'float' | 'breathe' | 'alert' | 'pop' | 'none';

const SRC: Record<NutsyPose, string> = { acorn, wave, stand, alert, avatar };

const MOTION_CLASS: Record<NutsyMotion, string> = {
  float: 'm-float',
  breathe: 'm-breathe',
  alert: 'm-alert',
  pop: 'm-pop',
  none: '',
};

export function Nutsy({
  pose,
  height,
  motion = [],
  shadow = false,
  alt = '',
}: {
  pose: NutsyPose;
  height: number;
  motion?: NutsyMotion[];
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
