/// The three preferences that change how the app behaves, held where the whole
/// app can see them.
///
/// ── Why these three and not the rest ──────────────────────────────────────
/// Theme, sound and haptics are the preferences that affect a widget somewhere
/// other than the screen you changed them on. Everything else in `Settings` is
/// read at the point of use — the ending-soon window by the ring, the backup
/// interval by the nudge — and does not need carrying about.
///
/// A notifier rather than reading the database in `build`: switching the theme
/// has to repaint the whole tree, and a `FutureBuilder` per screen would mean
/// five screens each discovering the change at a different moment.
library;

import 'package:flutter/material.dart';

import '../db/repository.dart';
import '../logic/prefs.dart';
import '../models/settings.dart';
import 'feedback.dart';

class PrefsController extends ChangeNotifier {
  PrefsController(this._repo);

  final Repository _repo;

  ThemeChoice _theme = ThemeChoice.system;
  bool _sounds = false;
  bool _haptics = true;

  ThemeChoice get theme => _theme;
  bool get sounds => _sounds;
  bool get haptics => _haptics;

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
    notifyListeners();
  }

  Future<void> set({ThemeChoice? theme, bool? sounds, bool? haptics}) async {
    _theme = theme ?? _theme;
    _sounds = sounds ?? _sounds;
    _haptics = haptics ?? _haptics;

    configureFeedback(sounds: _sounds, haptics: _haptics);
    notifyListeners();

    // Written after the repaint rather than before it. A preference that waits
    // on a disk write to take effect feels broken even when it is not.
    final settings = await _repo.settings();
    await _repo.saveSettings(
      settings.copyWith(theme: _theme, sounds: _sounds, haptics: _haptics),
    );
  }
}

/// Reached with `PrefsScope.of(context)`.
class PrefsScope extends InheritedNotifier<PrefsController> {
  const PrefsScope({required PrefsController super.notifier, required super.child, super.key});

  static PrefsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PrefsScope>()!.notifier!;
}
