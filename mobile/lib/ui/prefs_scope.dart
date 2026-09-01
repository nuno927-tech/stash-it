/// The few preferences that change how the app behaves, held where the whole
/// app can see them.
///
/// ── Why these and not the rest ────────────────────────────────────────────
/// Theme, sound, haptics and the portrait lock are the preferences whose
/// effect is felt somewhere other than the screen you changed them on — the
/// last one not even on a widget, but on the window itself. Everything else in
/// `Settings` is read at the point of use — the ending-soon window by the
/// ring, the backup interval by the nudge — and does not need carrying about.
///
/// A notifier rather than reading the database in `build`: switching the theme
/// has to repaint the whole tree, and a `FutureBuilder` per screen would mean
/// five screens each discovering the change at a different moment.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/repository.dart';
import '../logic/nudges.dart' show endingSoonDays;
import '../logic/prefs.dart';
import '../logic/warranty.dart' show setEndingSoonDays;
import '../models/settings.dart';
import 'feedback.dart';

class PrefsController extends ChangeNotifier {
  PrefsController(this._repo);

  final Repository _repo;

  ThemeChoice _theme = ThemeChoice.system;
  bool _sounds = false;
  bool _haptics = true;
  bool _lockPortrait = true;

  ThemeChoice get theme => _theme;
  bool get sounds => _sounds;
  bool get haptics => _haptics;
  bool get lockPortrait => _lockPortrait;

  /*
    ── Not a rebuild ───────────────────────────────────────────────────────

    Orientation is not something a widget can express by drawing differently;
    it is a message to the platform, and it stays set until something changes
    it. So this is called on load and on every change, rather than being read
    during a build — a `build` that had a side effect on the window would run
    on every repaint and fight anything else that ever touches the setting.

    Off is an empty list rather than all four orientations named. Empty means
    "no preference", which lets the phone's own rotation lock have the final
    say — naming all four would override the user's system setting, which is
    the opposite of what switching this off is asking for.
  */
  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(
      _lockPortrait
          ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : const [],
    );
  }

  /// Read once at launch, through `prefsFrom` so the defaults live in one
  /// place — a null field is a record written before the preference existed
  /// and has no opinion, which is not the same as "off".
  Future<void> load() async {
    final settings = await _repo.settings();
    final p = prefsFrom(settings);

    _theme = p.theme;
    _sounds = p.sounds;
    _haptics = p.haptics;
    _lockPortrait = p.lockPortrait;

    configureFeedback(sounds: _sounds, haptics: _haptics);
    _applyOrientation();

    /*
      ── The fallback notice, pushed where the rest of the app reads it ───────

      `warrantyState` asks `itemLeadDays`, which falls back to a library-level
      value in warranty.dart when an item has not chosen its own. `setEndingSoonDays`
      is what sets that value — and until now nothing in the app ever called it.
      Only the tests did, which is why it looked wired.

      The consequence was quiet rather than dramatic, because the hard-coded
      default happens to equal the stored one. But a backup carrying a different
      `reminderOffsetsDays` would have been read, decoded, saved and ignored.

      Set here because this is where settings are already turned into global
      state — the same three lines that configure sound and lock the
      orientation.
    */
    setEndingSoonDays(endingSoonDays(settings));

    notifyListeners();
  }

  Future<void> set({
    ThemeChoice? theme,
    bool? sounds,
    bool? haptics,
    bool? lockPortrait,
  }) async {
    _theme = theme ?? _theme;
    _sounds = sounds ?? _sounds;
    _haptics = haptics ?? _haptics;
    _lockPortrait = lockPortrait ?? _lockPortrait;

    configureFeedback(sounds: _sounds, haptics: _haptics);
    _applyOrientation();
    notifyListeners();

    // Written after the repaint rather than before it. A preference that waits
    // on a disk write to take effect feels broken even when it is not.
    final settings = await _repo.settings();
    await _repo.saveSettings(
      settings.copyWith(
        theme: _theme,
        sounds: _sounds,
        haptics: _haptics,
        lockPortrait: _lockPortrait,
      ),
    );
  }
}

/// Reached with `PrefsScope.of(context)`.
class PrefsScope extends InheritedNotifier<PrefsController> {
  const PrefsScope(
      {required PrefsController super.notifier,
      required super.child,
      super.key});

  static PrefsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrefsScope>()!.notifier!;
}
