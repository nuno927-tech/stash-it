/// Buying the unlock, and the seam it sits behind.
///
/// ── Why an interface for one product ──────────────────────────────────────
/// `in_app_purchase` needs a Play connection, a signed build and a Play
/// account that owns the app. None of those exist in `flutter test`, on a
/// desktop run, or on the emulator somebody is using to check a colour — and a
/// paywall that throws on three of the four places the app runs is a paywall
/// nobody can work near.
///
/// So the app talks to `Billing`, and `PlayBilling` is one implementation.
/// `NoBilling` is the other, and it is not a mock: it is the honest answer for
/// a build that genuinely cannot sell anything.
///
/// ── The price is not in this file ─────────────────────────────────────────
/// It is set in the Play Console and read back from the store, localised and
/// with the right currency for wherever somebody is standing. Hard-coding
/// "$8" would be wrong in every country but one and wrong everywhere the day
/// the price changes — and it is the sort of wrong that only shows up in a
/// screenshot from a user.
library;

import 'dart:async';

/// What the app knows about the offer.
class Offer {
  const Offer({required this.price, required this.available});

  /// The store's own formatted price — "$7.99", "£6.99", "8,99 €".
  ///
  /// Never assembled here. See the note above.
  final String price;

  /// False when the store could not be reached, the product is not set up, or
  /// this build cannot sell anything. The UI says so rather than showing a
  /// button that will not work.
  final bool available;
}

/// How a purchase attempt ended.
enum BuyResult {
  /// Bought, or already owned and restored. The entitlement is written.
  unlocked,

  /// Backed out. Not an error and not worth a message — they know.
  cancelled,

  /// Asked to restore and there was nothing to restore.
  nothingToRestore,

  /// The store said no, or was not there.
  failed,
}

abstract class Billing {
  /// What to show on the paywall. Never throws; an unreachable store is an
  /// `Offer` with `available` false.
  Future<Offer> offer();

  /// Opens the store's own purchase flow.
  Future<BuyResult> buy();

  /// For a new phone, a reinstall, or somebody who paid and is not unlocked.
  ///
  /// Always offered, and offered as prominently as the buy button on a screen
  /// somebody reached by being told they are full. The alternative is a person
  /// who has already paid being asked to pay again, which is the worst thing
  /// this screen can do.
  Future<BuyResult> restore();

  void dispose();
}

/// The answer for a build that cannot sell.
///
/// Not a stub that pretends to succeed. A test that unlocks by calling `buy`
/// on a fake would be testing the fake — the entitlement path is exercised by
/// writing the entitlement directly, which is what the repository tests do.
class NoBilling implements Billing {
  const NoBilling();

  @override
  Future<Offer> offer() async => const Offer(price: '', available: false);

  @override
  Future<BuyResult> buy() async => BuyResult.failed;

  @override
  Future<BuyResult> restore() async => BuyResult.nothingToRestore;

  @override
  void dispose() {}
}
