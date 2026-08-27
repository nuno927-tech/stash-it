/// The document and subscription forms.
///
///   flutter test test/forms_test.dart
///
/// Both have exactly one refusal, and the two refusals are different from each
/// other and from the item form's — which is the point worth testing. Each one
/// is the field without which the record would sit in a list making a promise
/// nothing behind it can keep.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stash_it/logic/paper_form.dart';
import 'package:stash_it/logic/papers.dart';
import 'package:stash_it/logic/subscription_form.dart';
import 'package:stash_it/logic/subscriptions.dart';
import 'package:stash_it/models/paper.dart';
import 'package:stash_it/models/subscription.dart';

void main() {
  group('a document', () {
    test('needs a name', () {
      expect(whyNotSaveablePaper(PaperDraft(expiresOn: '2027-01-01')),
          contains('Call it something'));
    });

    /*
      THE REFUSAL. Everything the Documents tab does is arithmetic on the
      printed date — the sort order, the amber circle, the "start now", the
      reminder. Without one the row sits in a list of things being watched,
      not being watched.
    */
    test('and an expiry, because that is the whole list', () {
      final d = PaperDraft(label: 'Passport');
      expect(whyNotSaveablePaper(d), contains('When does it expire'));
    });

    test('and is fine with both', () {
      final d = PaperDraft(label: 'Passport', expiresOn: '2027-02-11');
      expect(whyNotSaveablePaper(d), isNull);
    });

    /*
      Tapping a tile fills the name in, and stops the moment somebody types.
      A household has four passports and they get called "Nuno's passport" —
      correcting the tile must not throw that away.
    */
    test('picking a kind names it', () {
      final d = PaperDraft()..pickKind(PaperKind.licence);
      expect(d.label, kindLabel[PaperKind.licence]);
      expect(d.kind, PaperKind.licence);
    });

    test('and picking another renames it', () {
      final d = PaperDraft()
        ..pickKind(PaperKind.licence)
        ..pickKind(PaperKind.passport);
      expect(d.label, kindLabel[PaperKind.passport]);
    });

    test('but never over something typed', () {
      final d = PaperDraft(label: "Nuno's passport")..pickKind(PaperKind.licence);
      expect(d.label, "Nuno's passport");
    });

    test('the frozen key survives the form', () {
      final d = PaperDraft(expiresOn: '2027-05-01')..pickKind(PaperKind.licence);
      expect(toPaper(d, propertyId: 'p').kind, PaperKind.licence);
    });

    group('the lead time, spelled out', () {
      /*
        "240 days" means nothing and "about eight months" means everything —
        and a passport defaulting to eight months looks like a mistake until
        you know it is six months of required validity plus two of processing.
      */
      test('a passport explains its eight months', () {
        final d = PaperDraft(kind: PaperKind.passport);
        expect(leadExplanation(d), contains('8 months'));
        expect(leadExplanation(d), contains('when to start'));
      });

      test('and zero says it plainly', () {
        final d = PaperDraft(kind: PaperKind.passport, leadDays: 0);
        expect(leadExplanation(d), contains('on the day'));
      });

      test('an override wins over the kind', () {
        final d = PaperDraft(kind: PaperKind.passport, leadDays: 30);
        expect(leadExplanation(d), contains('about a month'));
      });
    });
  });

  group('a subscription', () {
    test('needs a name', () {
      expect(whyNotSaveableSubscription(SubscriptionDraft(anchorDate: '2026-09-01')),
          contains('called'));
    });

    /*
      THE REFUSAL. A subscription is a cadence and one real renewal date, and
      every other date derives from that one — the next renewal, the calendar,
      the chart, the reminder, "due this week". Without it the row appears in a
      list sorted by when things renew while having no answer to that question.
    */
    test('and an anchor date, because everything derives from it', () {
      final d = SubscriptionDraft(name: 'Netflix');
      expect(whyNotSaveableSubscription(d), contains('worked out from that one'));
    });

    test('and is fine with both', () {
      final d = SubscriptionDraft(name: 'Netflix', anchorDate: '2026-09-01');
      expect(whyNotSaveableSubscription(d), isNull);
    });

    /*
      Zero is allowed and means zero. A free tier of something you still want
      to see renewing is a real case, and refusing it would push people into
      typing 0.01 to get past the form.
    */
    test('costing nothing is allowed', () {
      final d = SubscriptionDraft(name: 'Spotify free', anchorDate: '2026-09-01');
      expect(whyNotSaveableSubscription(d), isNull);

      final s = toSubscription(d, propertyId: 'p');
      expect(s.amountCents, 0);
      expect(monthlyCents(s), 0);
    });

    test('the price goes through the same parser the field uses', () {
      final d = SubscriptionDraft(
        name: 'Netflix',
        anchorDate: '2026-09-01',
        amountText: r'$15.49',
      );
      expect(toSubscription(d, propertyId: 'p').amountCents, 1549);
    });

    test('and the saved record actually renews', () {
      final d = SubscriptionDraft(
        name: 'Netflix',
        anchorDate: '2026-09-01',
        cadence: Cadence.monthly,
      );
      final s = toSubscription(d, propertyId: 'p');

      // The point of refusing a missing anchor: with one, this is answerable.
      expect(nextRenewal(s, DateTime(2026, 8, 24)), DateTime(2026, 9, 1));
    });

    test('no reminder is the default', () {
      final d = SubscriptionDraft(name: 'Netflix', anchorDate: '2026-09-01');
      final s = toSubscription(d, propertyId: 'p');
      expect(s.remindDays, isNull);
      expect(reminderDue(s, DateTime(2026, 8, 31)), isFalse);
    });
  });

  group('editing what exists', () {
    test('a document opens with everything in the boxes', () {
      const dl = Paper(
        id: 'dl',
        propertyId: 'default',
        kind: PaperKind.licence,
        label: 'Driving license',
        holder: 'Nuno',
        expiresOn: '2027-05-01',
        leadDays: 60,
        authority: 'DMV',
        storedAt: 'Wallet',
      );

      final d = draftOfPaper(dl);
      expect(d.label, 'Driving license');
      expect(d.holder, 'Nuno');
      expect(d.leadDays, 60);
      expect(d.storedAt, 'Wallet');

      // And saving it untouched gives the same record back.
      final back = toPaper(d, propertyId: 'default');
      expect(back.id, 'dl');
      expect(back.kind, PaperKind.licence);
      expect(back.expiresOn, '2027-05-01');
    });

    test('and a subscription does too', () {
      const nflx = Subscription(
        id: 'nflx',
        propertyId: 'default',
        name: 'Netflix',
        cadence: Cadence.yearly,
        anchorDate: '2026-11-14',
        amountCents: 12000,
        currency: 'USD',
        remindDays: 3,
      );

      final back = toSubscription(draftOfSubscription(nflx), propertyId: 'default');
      expect(back.id, 'nflx');
      expect(back.cadence, Cadence.yearly);
      expect(back.amountCents, 12000);
      expect(back.remindDays, 3);
    });

    test('a free subscription opens with an empty price, not "0.00"', () {
      const free = Subscription(
        id: 'f',
        propertyId: 'default',
        name: 'Spotify free',
        cadence: Cadence.monthly,
        anchorDate: '2026-09-01',
        amountCents: 0,
        currency: 'USD',
      );
      expect(draftOfSubscription(free).amountText, '');
    });
  });
}
