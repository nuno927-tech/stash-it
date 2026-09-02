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

  /*
    ── A list becoming a set of choices ──────────────────────────────────────

    Long-pressing a row turns the whole screen into something else: rows stop
    opening and start ticking, and a bar appears where the search box was. That
    is a mode change, and it was answered with `tap` — the same reply an
    ordinary press gets, for the one gesture whose entire point is that
    something different happened.

    Fired when selection STARTS, not on every tick. The ticks are ordinary taps
    and should sound like it; arriving somewhere new is the thing worth saying.
  */
  pick,
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
///
/// ── A switch, not a map ────────────────────────────────────────────────────
/// It was a `const Map<Cue, _Voice>` read with `_voices[cue]!`, which meant a
/// cue added to the enum and forgotten here was a null-check crash at the exact
/// moment somebody pressed the thing — the worst place to find out and the last
/// place anybody would look. A test walked `Cue.values` to catch it, which is a
/// weaker guarantee than the compiler for the same money.
///
/// The buzz table next door has always been a switch and has always been
/// exhaustive. This is the same table it was, with colons for arrows.
_Voice _voiceFor(Cue cue) => switch (cue) {
  // Ordinary buttons: one short, quiet blip. This fires on nearly every tap,
  // so it has to be the least interesting sound in the set — anything with
  // character becomes irritating by the twentieth press.
  Cue.tap => const _Voice([880], 0.032, _Wave.sine, 0.035),

  // Moving between tabs is a bigger gesture, so it gets a lower, rounder note.
  // Pitch carries the distinction better than volume does.
  Cue.nav => const _Voice([392], 0.055, _Wave.sine, 0.05),

  // Rising to open, falling to close: the direction is the whole message.
  Cue.expand => const _Voice([523.25, 698.46], 0.045, _Wave.sine, 0.04),
  Cue.collapse => const _Voice([698.46, 523.25], 0.045, _Wave.sine, 0.04),

  /*
    Two quick ticks, up. Short enough to be a click rather than a phrase — this
    marks a mode change, and a mode change that announces itself with a tune is
    a mode change people stop entering.
  */
  Cue.pick => const _Voice([784, 1046.5], 0.03, _Wave.sine, 0.045),

  Cue.save => const _Voice([587.33, 880], 0.075, _Wave.sine, 0.07),

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
  Cue.stashed => const _Voice(
      [659.25, 987.77, 1318.51],
      0.05,
      _Wave.triangle,
      0.06,
      holdLast: 3,
    ),
  Cue.attach => const _Voice([523.25, 784], 0.06, _Wave.triangle, 0.06),
  Cue.delete => const _Voice([392, 261.63], 0.075, _Wave.sine, 0.06),
  Cue.error => const _Voice([233.08, 233.08], 0.11, _Wave.square, 0.04),

  // The app opening. Three rising notes, under a fifth of a second — long
  // enough to be a phrase rather than a beep, short enough that it is finished
  // before the dashboard has settled. Heard at most once per launch, which is
  // the only reason it is allowed to have a shape at all.
  Cue.launch => const _Voice([523.25, 659.25, 880], 0.062, _Wave.sine, 0.05),

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
  Cue.unlock => const _Voice(
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

  ── It has to agree with the tones ──────────────────────────────────────────

  It did not. `nav` has a lower, rounder note than `tap` on the argument that
  moving between tabs is a bigger gesture — and then asked for
  `selectionClick`, which on Android is CLOCK_TICK and is FAINTER than the
  `lightImpact` an ordinary tap gets. The sound said "bigger" and the phone
  said "smaller", on the same press. `attach` had it the same way round.

  So the two scales are written against each other now, lightest first:

      tap, pick, expand, collapse   light
      nav, attach, save             medium
      delete, error                 heavy

  with `stashed` and `unlock` spending more than one pulse because they are the
  two moments worth more than one.
*/
Future<void> _buzz(Cue cue) async {
  switch (cue) {
    /*
      The floor.

      `lightImpact` rather than `selectionClick`, even though the latter is
      lighter: CLOCK_TICK is the effect OEMs most often leave unimplemented,
      and the app's commonest haptic is the worst one to have silently missing
      on somebody's phone.
    */
    case Cue.tap:
    case Cue.pick:
    case Cue.expand:
    case Cue.collapse:
      await HapticFeedback.lightImpact();

    /*
      ── The launch cue does not buzz ─────────────────────────────────────

      A tone on opening is a greeting; a vibration on opening is the phone
      reporting for duty. It also cannot be turned off on its own — haptics
      are one switch — so somebody who wants the app to stop buzzing at them
      when they unlock their phone has to give up every other tick as well.

      The three rising notes stay. Those are off by default.
    */
    case Cue.launch:
      break;

    // Above an ordinary tap, because the tones are: a tab change and an
    // attachment are both arrivals somewhere rather than presses.
    case Cue.nav:
    case Cue.attach:
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

/// How many notes a cue's tone has, for the test that walks `Cue.values`.
///
/// The crash this used to guard against cannot happen any more — `_voiceFor`
/// is an exhaustive switch, so a cue with no tone does not compile. The test
/// stays because it also asserts the cues are not accidental copies of each
/// other, which no compiler will notice.
int noteCount(Cue cue) => _voiceFor(cue).notes.length;

/// The notes of a cue, in hertz. Read by the test, and by nothing else.
List<double> notesOf(Cue cue) => _voiceFor(cue).notes;

bool _sounds = false;
bool _haptics = true;

/// Called whenever preferences change.
void configureFeedback({required bool sounds, required bool haptics}) {
  _sounds = sounds;
  _haptics = haptics;
}

final AudioPlayer _player = AudioPlayer(playerId: 'stash-it-cues');
final Map<Cue, Uint8List> _rendered = {};

/*
  ── These are interface sounds, and Android has a word for that ──────────────

  Nothing configured the player, so every blip went out with audioplayers' own
  defaults: usage `media`, content type `music`, and an audio focus request of
  `gain` — which is the description of a music app announcing that it is now
  the only thing the user is listening to.

  Two consequences, both of them things somebody would notice and neither of
  them anything to do with this app's design:

    A 32-millisecond tick asked for audio focus, so tapping around could duck
    or stop whatever was playing in the background. Podcast, radio, anything.

    Media-stream audio ignores the ringer, so the cues would play at full
    volume on a phone set to silent. A UI tick that survives silent mode is the
    kind of thing that gets an app deleted in a meeting.

  `assistanceSonification` is the platform's own name for exactly this — see
  AudioAttributes.USAGE_ASSISTANCE_SONIFICATION — and it routes to the system
  stream, which the ringer governs. `AndroidAudioFocus.none` says out loud what
  a blip should never have had to say: this does not interrupt anybody.

  Set once, lazily, on the first cue that actually plays. Doing it at startup
  would run a platform call on every launch for a preference that is off by
  default.
*/
bool _configured = false;

Future<void> _configure() async {
  if (_configured) return;
  _configured = true;

  await _player.setAudioContext(
    const AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
    ),
  );
}

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
  await _configure();

  // Rendered once per cue and kept. The arithmetic is cheap but it is not free,
  // and `tap` is asked for sixty times an evening.
  final bytes = _rendered[cue] ??= _wav(_voiceFor(cue));

  // Stopped first, so a fast run of taps is a run of ticks rather than a pile.
  await _player.stop();
  await _player.play(BytesSource(bytes), volume: 1);
}

/// Wraps a callback so that pressing the thing ticks.
///
/// ── Why this exists ────────────────────────────────────────────────────────
/// `feedback(Cue.tap)` was written out by hand at sixty-one call sites. The
/// controls the app builds itself — the pills, the chips, the segmented rows,
/// the service tiles — all remembered, because each was written once and by
/// somebody thinking about it. Everything assembled from a plain `FilledButton`
/// or `IconButton` did not: the Edit button on every record page, both buttons
/// on the selection bar, the Undo in the snackbar, every date box.
///
/// The pattern that produced that is "silence is the default and noise is the
/// thing you remember to add". This inverts it at the only place a control can
/// be described in one word: its callback.
///
///     onPressed: cued(onEdit),
///     onTap: cued(onTap, cue: Cue.expand),
///
/// A callback rather than a widget, deliberately. A `Tappable` wrapper would
/// mean restructuring every call site's tree, and a wrapper that is easy to
/// forget is the problem again with more indentation.
///
/// Null in, null out — so a disabled button stays disabled rather than becoming
/// an enabled button that does nothing, which is the bug this shape makes
/// impossible.
VoidCallback? cued(VoidCallback? onTap, {Cue cue = Cue.tap}) {
  if (onTap == null) return null;

  return () {
    feedback(cue);
    onTap();
  };
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
