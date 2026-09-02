/// The few preferences that change how the app behaves, held where the whole
/// app can see them.
///
/// ── Why these and not the rest ────────────────────────────────────────────
/// Theme, sound and haptics are the preferences whose effect is felt somewhere
/// other than the screen you changed them on. Everything else in `Settings` is
/// read at the point of use — the ending-soon window by the ring, the backup
/// interval by the nudge — and does not need carrying about.
///
/// The orientation is set here too, and is no longer a preference: see
/// `_applyOrientation`.
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
import 'layout.dart';

class PrefsController extends ChangeNotifier {
  PrefsController(this._repo);

  final Repository _repo;

  ThemeChoice _theme = ThemeChoice.system;
  bool _sounds = false;
  bool _haptics = true;

  ThemeChoice get theme => _theme;
  bool get sounds => _sounds;
  bool get haptics => _haptics;

  /*
    ── Portrait, unless it is a tablet ─────────────────────────────────────

    Every screen in this app is a column — a list of records, a form, a
    settings page. Turned sideways on a phone they get shorter and no wider in
    any way that helps, and the add sheets, which open to just under the tab
    heading, become a keyboard with two fields above it. So a phone is locked.

    A tablet is not, and that is the whole reason this stopped being a
    preference. A tablet lives in a stand, sideways, and it has the width to
    show a list and the record beside it — see `splitView`. A landscape layout
    nobody can reach is not a feature, and a switch buried in Settings is not
    reaching it.

    The switch is gone rather than ignored on tablets. A control that does
    nothing on the device you are holding is worse than no control.

    ── Not a rebuild ───────────────────────────────────────────────────────

    Orientation is not something a widget can express by drawing differently;
    it is a message to the platform, and it stays set until something changes
    it. So this is called from `load` rather than read during a build — a
    `build` with a side effect on the window would run on every repaint.

    Empty means "no preference", which leaves the tablet's own rotation lock
    with the final say. Naming all four would override the user's system
    setting, which is not this app's business.
  */
  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(
      deviceIsTablet
          ? const []
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
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
  }) async {
    _theme = theme ?? _theme;
    _sounds = sounds ?? _sounds;
    _haptics = haptics ?? _haptics;

    configureFeedback(sounds: _sounds, haptics: _haptics);
    notifyListeners();

    // Written after the repaint rather than before it. A preference that waits
    // on a disk write to take effect feels broken even when it is not.
    final settings = await _repo.settings();
    await _repo.saveSettings(
      /*
        `lockPortrait` is not written any more and is not cleared either.

        The column stays because a form model that does not hold a field
        deletes it on save, and this one is carried in every backup ever taken.
        Nothing reads it — `_applyOrientation` asks the device instead — but a
        backup restored onto a future version should still come back whole.
      */
      settings.copyWith(
        theme: _theme,
        sounds: _sounds,
        haptics: _haptics,
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
