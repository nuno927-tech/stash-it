/// Preferences, and the lists of choices behind them.
///
///   dart test test/prefs_test.dart
///
/// Translated from the pure half of `test/prefs.test.ts`. The half that wrote
/// to Dexie and read it back comes with the storage layer in phase 2.
///
/// The point of the file: a record written before a preference existed still
/// answers every question about it. Null is not "off", it is "no opinion".
library;

import 'package:stash_it/logic/prefs.dart';
import 'package:stash_it/models/settings.dart';
import 'package:test/test.dart';

void main() {
  group('defaults', () {
    // The whole reason prefsFrom exists: an old record has none of these
    // fields, and must not read as everything switched off.
    const fresh = Settings();

    test('a record written before prefs existed still reads', () {
      expect(prefsFrom(fresh).theme, ThemeChoice.system);
    });

    test('sounds default to on', () => expect(prefsFrom(fresh).sounds, isTrue));
    test('haptics default to on', () => expect(prefsFrom(fresh).haptics, isTrue));

    test('rooms start collapsed', () {
      // With a dozen rooms the expanded list is a long scroll, and the question
      // people arrive with is usually "what's in the garage".
      expect(prefsFrom(fresh).roomsView, RoomsView.collapsed);
    });

    test('the lock is off until asked for', () {
      // Switching it on costs an enrolment prompt, and a lock nobody chose is
      // a lock they will be surprised by at the worst moment.
      expect(prefsFrom(fresh).biometricLock, isFalse);
    });

    test('no settings at all still yields defaults', () {
      expect(prefsFrom(null).theme, defaultPrefs.theme);
      expect(prefsFrom(null).sounds, defaultPrefs.sounds);
    });
  });

  group('a set value wins', () {
    test('a chosen theme', () {
      expect(prefsFrom(const Settings(theme: ThemeChoice.light)).theme, ThemeChoice.light);
    });

    test('and turning something off is not "no opinion"', () {
      expect(prefsFrom(const Settings(sounds: false)).sounds, isFalse);
    });

    test('an empty display name is a real answer', () {
      // Asked, and declined. Different from never having been asked.
      expect(prefsFrom(const Settings(displayName: '')).displayName, '');
    });
  });

  group('resolving the theme', () {
    test('system follows a dark device', () {
      expect(resolveTheme(ThemeChoice.system, true), ThemeChoice.dark);
    });

    test('and a light one', () {
      expect(resolveTheme(ThemeChoice.system, false), ThemeChoice.light);
    });

    test('an explicit choice ignores the device', () {
      expect(resolveTheme(ThemeChoice.light, true), ThemeChoice.light);
      expect(resolveTheme(ThemeChoice.dark, false), ThemeChoice.dark);
    });
  });

  group('the choices', () {
    /*
      Null is the first option on the item form and it is the default: follow
      the setting. It has to be a real, selectable choice rather than an
      absence, or there is no way back once someone has picked a number.
    */
    test('the item list opens with Default, meaning no override', () {
      expect(itemLeadChoices.first.days, isNull);
      expect(itemLeadChoices.first.label, 'Default');
    });

    /*
      Longer than the global list on purpose. A renewal is a payment you might
      want to cancel this week; a warranty on something installed is a job — a
      quote, a tradesman, a date in a diary — and thirty days does not cover
      any of it. A roof wants a year.
    */
    test('and runs longer than the global one', () {
      final itemMax = itemLeadChoices
          .map((c) => c.days ?? 0)
          .reduce((a, b) => a > b ? a : b);
      final globalMax =
          reminderChoices.map((c) => c.days!).reduce((a, b) => a > b ? a : b);
      expect(itemMax, greaterThan(globalMax));
      expect(itemMax, 365);
    });

    test('zero is offered for backups, and means never', () {
      expect(backupReminderChoices.last.days, 0);
      expect(backupReminderChoices.last.label, 'Never');
    });

    test('every choice has a label, and no duplicates', () {
      for (final list in [reminderChoices, itemLeadChoices, backupReminderChoices]) {
        for (final c in list) {
          expect(c.label, isNotEmpty);
        }
        expect(list.map((c) => c.days).toSet().length, list.length);
      }
    });

    test('the picker offers a currency the formatter knows', () {
      expect(currencies, contains('USD'));
      expect(currencies.toSet().length, currencies.length);
    });
  });
}
