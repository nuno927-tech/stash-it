/// Sound and haptics.
///
/// Ported from `src/lib/feedback.ts`, including the frequency table, because
/// the cues are the app's voice and two apps that sound different are two apps.
///
/// ── Synthesised, not shipped ──────────────────────────────────────────────
/// The PWA generates its tones with WebAudio rather than bundling audio files:
/// nine short blips would cost more bytes than the entire icon set, and a
/// generated tone can be retuned without a round trip through an audio editor.
///
/// Flutter has no oscillator, so the same reasoning lands one step lower: the
/// PCM is written by hand into a WAV in memory, once per cue, and cached. Same
/// notes, same envelopes, same argument — a few hundred lines of arithmetic
/// instead of a folder of assets that can drift out of sync with the web app's.
///
/// ── The two preferences are independent ───────────────────────────────────
/// Every cue has both a voice and a buzz, gated separately. Turning sound off
/// leaves the ticks; turning haptics off leaves the tones.
///
/// ── And it must never take an action down with it ─────────────────────────
/// Feedback is decoration. Every path here swallows its errors, because a
/// failure to play a 32-millisecond blip must not be the reason a warranty did
/// not save.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum Cue {
  tap,
  nav,
  expand,
  collapse,
  save,
  stashed,
  delete,
  error,
  attach,
  launch,
  unlock
}

class _Voice {
  const _Voice(this.notes, this.step, this.wave, this.gain,
      {this.holdLast = 1});

  /// Frequencies in hertz, played in sequence.
  final List<double> notes;

  /// Seconds per note.
  final double step;

  final _Wave wave;
  final double gain;

  /// How many steps the **last** note is held for.
  ///
  /// ── Why a phrase needs one long note ────────────────────────────────────
  /// Every cue here used to be a string of equal notes, which is why the two-
  /// note ones read as beeps: a run of identical lengths has no shape, so the
  /// ear hears a list rather than a phrase. Landing on a note and letting it
  /// ring is the difference between "beep beep" and an arrival.
  ///
  /// Left at 1 for the eight cues that fire constantly. A cue you hear forty
  /// times a day must not have an ending worth listening to.
  final int holdLast;
}

enum _Wave { sine, triangle, square }

/// The same table as `VOICES` in feedback.ts, note for note.
const Map<Cue, _Voice> _voices = {
  // Ordinary buttons: one short, quiet blip. This fires on nearly every tap,
  // so it has to be the least interesting sound in the set — anything with
  // character becomes irritating by the twentieth press.
  Cue.tap: _Voice([880], 0.032, _Wave.sine, 0.035),

  // Moving between tabs is a bigger gesture, so it gets a lower, rounder note.
  // Pitch carries the distinction better than volume does.
  Cue.nav: _Voice([392], 0.055, _Wave.sine, 0.05),

  // Rising to open, falling to close: the direction is the whole message.
  Cue.expand: _Voice([523.25, 698.46], 0.045, _Wave.sine, 0.04),
  Cue.collapse: _Voice([698.46, 523.25], 0.045, _Wave.sine, 0.04),

  Cue.save: _Voice([587.33, 880], 0.075, _Wave.sine, 0.07),

  /*
    ── Something went into the stash ──────────────────────────────────────────

    `save` covers everything that writes: a switch flipped in Settings, a lock
    turned on, a room renamed. All of those are the app agreeing with you.

    Filing an item, a document or a subscription is different in kind — it is
    the thing the app is FOR, and the only moment somebody has actually got
    something out of using it. Sharing the confirmation tone with a preference
    toggle made the two feel equally consequential, which is to say it made
    neither feel like anything.

    E–B–E: a fifth and then a fourth, the open chiming shape rather than the
    triad. Distinct from `save` by pitch, by having three notes instead of two,
    and by the top E ringing on after the phrase has finished.

    Short, though — a quarter of a second. This is not the unlock fanfare and
    must not be: somebody filing a kitchen drawer's worth of appliances will
    hear it forty times in an evening, and anything with more character than
    this becomes something to turn off.
  */
  Cue.stashed: _Voice(
    [659.25, 987.77, 1318.51],
    0.05,
    _Wave.triangle,
    0.06,
    holdLast: 3,
  ),
  Cue.attach: _Voice([523.25, 784], 0.06, _Wave.triangle, 0.06),
  Cue.delete: _Voice([392, 261.63], 0.075, _Wave.sine, 0.06),
  Cue.error: _Voice([233.08, 233.08], 0.11, _Wave.square, 0.04),

  // The app opening. Three rising notes, under a fifth of a second — long
  // enough to be a phrase rather than a beep, short enough that it is finished
  // before the dashboard has settled. Heard at most once per launch, which is
  // the only reason it is allowed to have a shape at all.
  Cue.launch: _Voice([523.25, 659.25, 880], 0.062, _Wave.sine, 0.05),

  /*
    ── Finding Scout's album ────────────────────────────────────────────────

    The only cue in the set allowed to be a tune, because it is the only one
    most people will hear exactly once. Everything else in this table is
    designed not to wear out; this one has no chance to.

    G–C–E–G–C: a major triad climbing an octave and a half, which is the shape
    every fanfare ever written has, and then the top C held for six steps so
    it rings out under the confetti rather than stopping with it.

    Triangle rather than sine. The extra harmonics are what make it read as
    brass instead of a test tone, and at a third of a second of ring the
    difference is the entire effect.
  */
  Cue.unlock: _Voice(
    [392, 523.25, 659.25, 784, 1046.5],
    0.058,
    _Wave.triangle,
    0.075,
    holdLast: 6,
  ),
};

/*
  ── The buzz scale, and why it is not one vibration ──────────────────────────

  Every cue buzzes, including ordinary taps — the tick is what makes a button
  feel like a button. The scale matters more than the presence: a tap is barely
  perceptible, while a delete is something you would notice with the phone
  face-down.

  The web version gives these in milliseconds because `navigator.vibrate` takes
  a duration. Flutter's `HapticFeedback` does not: Android exposes a small set
  of named effects instead, and asking for six milliseconds is not something the
  platform offers. So the millisecond table becomes a mapping onto the nearest
  named effect, which loses the exact durations and keeps the thing that
  mattered — that these are ordered, and that a tap is the smallest.
*/
Future<void> _buzz(Cue cue) async {
  switch (cue) {
    // 6–9ms in the web table. The lightest thing Android will do.
    case Cue.tap:
    case Cue.expand:
    case Cue.collapse:
    case Cue.launch:
      await HapticFeedback.lightImpact();
    case Cue.nav:
    case Cue.attach:
      await HapticFeedback.selectionClick();
    case Cue.save:
      await HapticFeedback.mediumImpact();

    // Light then medium, rising with the notes. A single pulse would be the
    // same reply an ordinary save gives, which is the thing this cue exists
    // not to be.
    case Cue.stashed:
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await HapticFeedback.mediumImpact();
    // Double pulses on the web. Heavy is the closest single effect, and the
    // two that get it are the two that undo something.
    case Cue.delete:
    case Cue.error:
      await HapticFeedback.heavyImpact();

    /*
      The only buzz in the set with a rhythm.

      A single pulse under a five-note fanfare feels like the phone missed the
      moment. Three, climbing and spaced to sit under the rise, land as one
      gesture rather than three taps — and this is the one cue where spending
      a quarter of a second on a vibration is affordable, because nobody is
      waiting to do something else.
    */
    case Cue.unlock:
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 95));
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 75));
      await HapticFeedback.heavyImpact();
  }
}

/// Whether this cue has a tone at all.
///
/// Public only so a test can walk `Cue.values` — `_play` reaches into the map
/// with a `!`, so a member added to the enum and not to the table is a crash
/// at the moment somebody presses the thing, which is the worst possible time
/// to find out and the least likely place to look.
bool hasVoice(Cue cue) => _voices.containsKey(cue);

bool _sounds = false;
bool _haptics = true;

/// Called whenever preferences change.
void configureFeedback({required bool sounds, required bool haptics}) {
  _sounds = sounds;
  _haptics = haptics;
}

final AudioPlayer _player = AudioPlayer(playerId: 'stash-it-cues');
final Map<Cue, Uint8List> _rendered = {};

/// Fire a cue. Safe to call from anywhere; does nothing when the relevant
/// preference is off, and never throws.
void feedback(Cue cue) {
  if (_haptics) {
    _buzz(cue).catchError((_) {});
  }
  if (_sounds) {
    _play(cue).catchError((_) {});
  }
}

Future<void> _play(Cue cue) async {
  final bytes = _rendered[cue] ??= _wav(_voices[cue]!);
  await _player.stop();
  await _player.play(BytesSource(bytes), volume: 1);
}

/// Play a cue regardless of the current preference, so Settings can demonstrate
/// one as the switch is turned on. A toggle you cannot hear is a toggle you
/// have to take on trust.
Future<void> previewCue(Cue cue,
    {required bool sounds, required bool haptics}) async {
  final was = (_sounds, _haptics);
  configureFeedback(sounds: sounds, haptics: haptics);
  feedback(cue);
  configureFeedback(sounds: was.$1, haptics: was.$2);
}

/* ------------------------------------------------------------ synthesis */

const int _rate = 44100;

/// A voice as a mono 16-bit WAV.
Uint8List _wav(_Voice voice) {
  final perNote = (voice.step * _rate).round();
  final last = voice.notes.length - 1;

  // Every note is one step except the last, which may be held. Written as a
  // list rather than assumed, because the decay below divides by whatever
  // length the note it is in actually has — a held note has to fade over its
  // own duration or it stops dead at the point the short ones would have.
  final lengths = [
    for (var n = 0; n < voice.notes.length; n++)
      n == last ? perNote * voice.holdLast : perNote,
  ];

  final samples = Int16List(lengths.fold(0, (sum, n) => sum + n));
  var at = 0;

  for (var n = 0; n < voice.notes.length; n++) {
    final freq = voice.notes[n];
    final length = lengths[n];

    for (var i = 0; i < length; i++) {
      final t = i / _rate;
      final phase = 2 * math.pi * freq * t;

      final shape = switch (voice.wave) {
        _Wave.sine => math.sin(phase),
        // A triangle from the sine's phase rather than a lookup: cheap, and
        // close enough at these durations that the difference is inaudible.
        _Wave.triangle => 2 / math.pi * math.asin(math.sin(phase)),
        _Wave.square => math.sin(phase) >= 0 ? 1.0 : -1.0,
      };

      /*
        A hard start or stop clicks — most audibly on the square wave, which is
        why the error cue is the one that exposed this in the web version. Both
        ends are ramped: 8ms up, then an exponential decay to silence just
        before the note ends.
      */
      final attack = math.min(1.0, t / 0.008);
      final tail = (length - i) / length;
      final decay = math.pow(tail, 2.2).toDouble();

      samples[at + i] = (shape * voice.gain * attack * decay * 32767)
          .round()
          .clamp(-32768, 32767);
    }

    at += length;
  }

  return _riff(samples);
}

/// The 44-byte canonical WAV header, then the samples.
Uint8List _riff(Int16List samples) {
  final data = samples.buffer.asUint8List();
  final out = BytesBuilder();

  void ascii(String s) => out.add(s.codeUnits);
  void u32(int v) =>
      out.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      out.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  u32(36 + data.length);
  ascii('WAVE');
  ascii('fmt ');
  u32(16); // PCM header length
  u16(1); //  PCM, uncompressed
  u16(1); //  mono
  u32(_rate);
  u32(_rate * 2); // byte rate: one channel, two bytes a sample
  u16(2); //  block align
  u16(16); // bits per sample
  ascii('data');
  u32(data.length);
  out.add(data);

  return out.toBytes();
}
