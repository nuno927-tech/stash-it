/**
 * Sound and haptics.
 *
 * Tones are synthesised with WebAudio rather than shipped as audio files:
 * four short blips would cost more bytes than the entire icon set, and
 * generated tones can be tuned without a round trip through an audio editor.
 *
 * Two constraints shape this:
 *  - Browsers refuse to start an AudioContext outside a user gesture, so the
 *    context is created lazily on the first real interaction.
 *  - `navigator.vibrate` is Android-only. iOS Safari has no vibration API at
 *    all, so haptics silently do nothing there. The toggle stays visible
 *    because the same install may sync to a phone that does support it.
 *
 * Sound and haptics are independent: each cue has both a voice and a buzz, and
 * the two preferences gate them separately. Turning sound off leaves the ticks;
 * turning haptics off leaves the tones.
 */

export type Cue =
  | 'tap'
  | 'nav'
  | 'expand'
  | 'collapse'
  | 'save'
  | 'delete'
  | 'error'
  | 'attach'
  | 'launch';

interface Voice {
  /** Frequencies in Hz, played in sequence. */
  notes: number[];
  /** Seconds per note. */
  step: number;
  type: OscillatorType;
  gain: number;
}

const VOICES: Record<Cue, Voice> = {
  // Ordinary buttons: one short, quiet blip. This fires on nearly every tap,
  // so it has to be the least interesting sound in the set — anything with
  // character becomes irritating by the twentieth press.
  tap: { notes: [880], step: 0.032, type: 'sine', gain: 0.035 },
  // Moving between tabs is a bigger gesture, so it gets a lower, rounder note.
  // Pitch carries the distinction better than volume does.
  nav: { notes: [392], step: 0.055, type: 'sine', gain: 0.05 },
  // Rising to open, falling to close: the direction is the whole message.
  expand: { notes: [523.25, 698.46], step: 0.045, type: 'sine', gain: 0.04 },
  collapse: { notes: [698.46, 523.25], step: 0.045, type: 'sine', gain: 0.04 },
  save: { notes: [587.33, 880], step: 0.075, type: 'sine', gain: 0.07 },
  attach: { notes: [523.25, 784], step: 0.06, type: 'triangle', gain: 0.06 },
  delete: { notes: [392, 261.63], step: 0.075, type: 'sine', gain: 0.06 },
  error: { notes: [233.08, 233.08], step: 0.11, type: 'square', gain: 0.04 },
  // The app opening. Three rising notes, under a fifth of a second — long
  // enough to be a phrase rather than a beep, short enough that it's finished
  // before the dashboard has settled. Heard at most once per launch, which is
  // the only reason it's allowed to have a shape at all.
  launch: { notes: [523.25, 659.25, 880], step: 0.062, type: 'sine', gain: 0.05 },
};

/**
 * Vibration patterns, in the alternating on/off milliseconds navigator wants.
 *
 * Every cue buzzes, including ordinary taps — the tick is what makes a button
 * feel like a button. The scale matters more than the presence: a tap is 6ms,
 * barely a tick, while a delete is a double pulse you'd notice with the phone
 * face-down. Anything longer than about 10ms on a per-tap action stops reading
 * as texture and starts reading as a notification.
 */
const BUZZ: Record<Cue, number | number[]> = {
  tap: 6,
  nav: 9,
  expand: 7,
  collapse: 7,
  save: [12, 40, 18],
  attach: 14,
  delete: [22, 45, 22],
  error: [30, 60, 30],
  launch: 10,
};

/** Exposed so the tick scale can be asserted rather than eyeballed. */
export function buzzFor(cue: Cue): number | number[] {
  return BUZZ[cue];
}

let ctx: AudioContext | null = null;
let enabledSounds = false;
let enabledHaptics = true;

/** Called by the app whenever preferences change. */
export function configureFeedback(prefs: { sounds: boolean; haptics: boolean }): void {
  enabledSounds = prefs.sounds;
  enabledHaptics = prefs.haptics;
  if (!prefs.sounds && ctx) {
    void ctx.close();
    ctx = null;
  }
}

function audio(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  const Ctor = window.AudioContext ?? (window as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!Ctor) return null;
  if (!ctx) ctx = new Ctor();
  // Autoplay policy suspends the context until a gesture; this is that gesture.
  if (ctx.state === 'suspended') void ctx.resume();
  return ctx;
}

function tone(voice: Voice): void {
  const ac = audio();
  if (!ac) return;

  voice.notes.forEach((freq, i) => {
    const osc = ac.createOscillator();
    const amp = ac.createGain();
    const at = ac.currentTime + i * voice.step;

    osc.type = voice.type;
    osc.frequency.setValueAtTime(freq, at);

    // A hard start or stop on a square wave clicks; ramp both ends.
    amp.gain.setValueAtTime(0, at);
    amp.gain.linearRampToValueAtTime(voice.gain, at + 0.008);
    amp.gain.exponentialRampToValueAtTime(0.0001, at + voice.step * 0.95);

    osc.connect(amp).connect(ac.destination);
    osc.start(at);
    osc.stop(at + voice.step);
  });
}

/**
 * Fire a cue. Safe to call from anywhere — it does nothing when the relevant
 * preference is off, and never throws.
 *
 * A note on the launch cue specifically: browsers refuse to start an
 * AudioContext, and ignore navigator.vibrate, without a user gesture. Opening
 * an app from the home screen is not a gesture the page can see, so on a cold
 * start this may make no sound at all — and that is the correct outcome. The
 * alternative is queueing it until the first tap, which would play "the app
 * has opened" some minutes after it opened.
 */
export function feedback(cue: Cue): void {
  try {
    if (enabledSounds) tone(VOICES[cue]);
    if (enabledHaptics && typeof navigator !== 'undefined' && navigator.vibrate) {
      navigator.vibrate(BUZZ[cue]);
    }
  } catch {
    // Feedback is decoration. It must never take an action down with it.
  }
}

/** Lets Settings demo a cue when the toggle is switched on. */
export function previewCue(cue: Cue, prefs: { sounds: boolean; haptics: boolean }): void {
  const [s, h] = [enabledSounds, enabledHaptics];
  configureFeedback(prefs);
  feedback(cue);
  enabledSounds = s;
  enabledHaptics = h;
}

export function hapticsSupported(): boolean {
  return typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function';
}

/* ------------------------------------------------------------ click sounds */

export interface ClickContext {
  /** An explicit `data-cue` on the element or an ancestor. */
  override?: string | null;
  /** Bottom-nav tabs and the add button. */
  isNav?: boolean;
  /** A disclosure control, with its state *before* the click. */
  isDisclosure?: boolean;
  expanded?: boolean;
}

/**
 * Which cue a click should make. Pure, so the rules can be tested without a
 * DOM — the browser adapter below is deliberately thin.
 */
export function pickCue(ctx: ClickContext): Cue | null {
  if (ctx.override) {
    if (ctx.override === 'none') return null;
    return (ctx.override as Cue) in VOICES ? (ctx.override as Cue) : 'tap';
  }
  if (ctx.isNav) return 'nav';
  // A disclosure reports the state it was in, so clicking an open one closes it.
  if (ctx.isDisclosure) return ctx.expanded ? 'collapse' : 'expand';
  return 'tap';
}

const NAV_SELECTOR = '.navitem, .fab';
const DISCLOSURE_SELECTOR = '.expander, [aria-expanded]';

/**
 * One listener for the whole app rather than a call in every handler.
 *
 * Wiring each button individually would mean every new button silently opting
 * out until someone remembered. Delegation makes sound the default and
 * `data-cue="none"` the exception.
 */
export function installClickSounds(root: Document | HTMLElement = document): () => void {
  const onClick = (event: Event) => {
    const target = event.target as HTMLElement | null;
    const el = target?.closest?.('button, a[href], [role="switch"], [role="button"]');
    if (!el || (el as HTMLButtonElement).disabled) return;

    const cue = pickCue({
      override: el.closest('[data-cue]')?.getAttribute('data-cue'),
      isNav: !!el.closest(NAV_SELECTOR),
      isDisclosure: el.matches(DISCLOSURE_SELECTOR),
      expanded: el.getAttribute('aria-expanded') === 'true',
    });

    if (cue) feedback(cue);
  };

  root.addEventListener('click', onClick, true);
  return () => root.removeEventListener('click', onClick, true);
}
