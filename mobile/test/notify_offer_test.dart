/// Asking, once, whether reminders should arrive as notifications.
///
///   dart test test/notify_offer_test.dart
///
/// Translated from the notify-offer half of `test/notify.test.ts`.
///
/// ── Three web verdicts have no test here because they no longer exist ─────
/// `unsupported` (a browser without a push API), `no-key` (a build shipped
/// without a VAPID key) and `needs-install` (on iOS, web push only worked for
/// a PWA on the Home Screen). All three were platform problems. What is left
/// is the only question that was ever about the person: have they said no.
library;

import 'package:stash_it/logic/notify_offer.dart';
import 'package:flutter_test/flutter_test.dart';

OfferInput offer({
  bool asked = false,
  bool enabled = false,
  NotifyVerdict verdict = NotifyVerdict.ready,
  bool dated = true,
}) =>
    OfferInput(asked: asked, enabled: enabled, verdict: verdict, dated: dated);

void main() {
  group('when to ask', () {
    test('a first dated save, on a phone that can, is the moment', () {
      expect(shouldOffer(offer()), isTrue);
    });

    /*
      A prompt that returns is a prompt that gets dismissed reflexively, and
      after the second time the dismissal is muscle memory rather than an
      answer. The date is written whether they said yes or no.
    */
    test('having been asked once is enough, forever', () {
      expect(shouldOffer(offer(asked: true)), isFalse);
    });

    test('already on means nothing to offer', () {
      expect(shouldOffer(offer(enabled: true)), isFalse);
    });

    /*
      Offering on the strength of something with no date would be offering an
      empty schedule — a yes, then silence, which reads as broken.
    */
    test('something with no date is not a reason to ask', () {
      expect(shouldOffer(offer(dated: false)), isFalse);
    });

    test('and a refused permission is not worth asking twice', () {
      expect(shouldOffer(offer(verdict: NotifyVerdict.denied)), isFalse);
    });
  });

  group('what counts as dated', () {
    test('a document with an expiry does', () {
      expect(datedSave(expiresOn: '2027-02-11'), isTrue);
    });

    test('an item with a purchase date and cover does', () {
      expect(datedSave(purchaseDate: '2026-08-01', hasCover: true), isTrue);
    });

    /*
      Cover is the second half and not optional. A purchase date on its own
      produces no reminder, so a save with one is not a reason to ask.
    */
    test('but a purchase date with no cover does not', () {
      expect(datedSave(purchaseDate: '2026-08-01'), isFalse);
    });

    test('nor cover with no date to run it from', () {
      expect(datedSave(hasCover: true), isFalse);
    });

    test('and blank is blank', () {
      expect(datedSave(expiresOn: '   '), isFalse);
      expect(datedSave(purchaseDate: '  ', hasCover: true), isFalse);
      expect(datedSave(), isFalse);
    });

    /*
      Deliberately the crude check: does it have a date at all. Testing whether
      the date falls inside the reminder horizon would mean an item bought last
      week and covered for three years does not count — which is exactly
      backwards. That is the one most worth a reminder, because it is the one
      nobody will still be thinking about.
    */
    test('a date years out still counts', () {
      expect(datedSave(expiresOn: '2039-01-01'), isTrue);
    });
  });

  group('the flag', () {
    // Armed by the form that just saved, read by the app shell. An intent that
    // survived a restart would surface days later, attached to nothing the
    // person remembers doing.
    setUp(clearNotifyOffer);
    tearDown(clearNotifyOffer);

    test('nothing is armed to begin with', () {
      expect(notifyOfferArmed(), isFalse);
    });

    test('arming shows, and clearing clears', () {
      armNotifyOffer();
      expect(notifyOfferArmed(), isTrue);
      clearNotifyOffer();
      expect(notifyOfferArmed(), isFalse);
    });

    test('clearing twice is harmless', () {
      clearNotifyOffer();
      clearNotifyOffer();
      expect(notifyOfferArmed(), isFalse);
    });
  });
}
