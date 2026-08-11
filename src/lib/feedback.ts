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
 */

export type Cue = 'tap' | 'save' | 'delete' | 'error' | 'attach';

interface Voice {
  /** Frequencies in Hz, played in sequence. */
  notes: number[];
  /** Seconds per note. */
  step: number;
  type: OscillatorType;
  gain: number;
}

const VOICES: Record<Cue, Voice> = {
  tap: { notes: [660], step: 0.045, type: 'sine', gain: 0.05 },
  save: { notes: [587.33, 880], step: 0.075, type: 'sine', gain: 0.07 },
  attach: { notes: [523.25, 784], step: 0.06, type: 'triangle', gain: 0.06 },
  delete: { notes: [392, 261.63], step: 0.075, type: 'sine', gain: 0.06 },
  error: { notes: [233.08, 233.08], step: 0.11, type: 'square', gain: 0.04 },
};

/** Vibration patterns, in the alternating on/off milliseconds navigator wants. */
const BUZZ: Record<Cue, number | number[]> = {
  tap: 8,
  save: [12, 40, 18],
  attach: 14,
  delete: [22, 45, 22],
  error: [30, 60, 30],
};

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
