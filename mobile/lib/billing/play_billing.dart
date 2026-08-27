/// The real one: Google Play's billing, through `in_app_purchase`.
///
/// ── One product, non-consumable, bought once ──────────────────────────────
/// A one-time unlock rather than a subscription, because the app has no
/// running cost. There is no server, nothing syncs, and nothing is stored
/// anywhere but the handset — charging monthly for that would be charging for
/// a thing that is not happening.
///
/// It also means the purchase is Google's record, not ours. Somebody who
/// factory-resets or moves phone restores it from the store; there is no
/// account here to look them up in, and there is deliberately never going to
/// be one.
library;

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing.dart';

/*
  ── The product id ──────────────────────────────────────────────────────────

  Must match the in-app product created in the Play Console exactly. It cannot
  be changed after the first sale — the id IS the thing people own — so it is
  written plainly rather than assembled, and RELEASE.md carries the Console
  steps beside it.
*/
const String unlockProductId = 'stash_it_unlock';

class PlayBilling implements Billing {
  PlayBilling({required this.onUnlocked}) {
    _sub = _store.purchaseStream.listen(
      _heard,
      onDone: () => _sub?.cancel(),
      // A dead stream must not take the app with it. The paywall degrades to
      // "the store is not answering", which is true and actionable.
      onError: (_) {},
    );
  }

  /// Called when a purchase is confirmed or restored, with the source Play
  /// reported. The caller writes the entitlement — this file does not touch
  /// the database, so the one place entitlements are written stays one place.
  final Future<void> Function(String source) onUnlocked;

  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  ProductDetails? _product;

  /// Completed by whichever purchase event arrives after a `buy` or a
  /// `restore`. Null when nothing is in flight, so a purchase that turns up on
  /// its own — a card that took three days to clear — is still honoured
  /// without anybody waiting on it.
  Completer<BuyResult>? _waiting;

  @override
  Future<Offer> offer() async {
    try {
      if (!await _store.isAvailable()) {
        return const Offer(price: '', available: false);
      }

      final found = await _store.queryProductDetails({unlockProductId});

      /*
        `notFoundIDs` is the common failure and it is almost never a bug in
        this code: the product has not been created in the Console, or the
        build is not signed with the upload key, or the account testing it is
        not on the licence-testers list. All three look identical from here,
        which is why the paywall says the store is not answering rather than
        guessing at a reason.
      */
      if (found.productDetails.isEmpty) {
        return const Offer(price: '', available: false);
      }

      _product = found.productDetails.first;
      return Offer(price: _product!.price, available: true);
    } catch (_) {
      return const Offer(price: '', available: false);
    }
  }

  @override
  Future<BuyResult> buy() async {
    final product = _product ?? await _fetch();
    if (product == null) return BuyResult.failed;

    _waiting = Completer<BuyResult>();

    try {
      /*
        `buyNonConsumable`, not `buyConsumable`. A consumable can be bought
        twice, and the difference is not a flag on our side — it decides what
        Play does when somebody who already owns it presses buy. Non-consumable
        means Play answers "already owned" and the restore path takes over,
        which is exactly right.
      */
      await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      _waiting = null;
      return BuyResult.failed;
    }

    return _waiting!.future;
  }

  @override
  Future<BuyResult> restore() async {
    _waiting = Completer<BuyResult>();

    try {
      await _store.restorePurchases();
    } catch (_) {
      _waiting = null;
      return BuyResult.failed;
    }

    /*
      A restore with nothing to restore emits no event at all, so waiting on
      the stream alone would hang. Six seconds is long enough for a real
      purchase to come back over a slow connection and short enough that
      somebody does not think the button is broken.
    */
    return _waiting!.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        _waiting = null;
        return BuyResult.nothingToRestore;
      },
    );
  }

  Future<ProductDetails?> _fetch() async {
    await offer();
    return _product;
  }

  Future<void> _heard(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != unlockProductId) continue;

      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await onUnlocked('play');
          _finish(BuyResult.unlocked);

        case PurchaseStatus.canceled:
          _finish(BuyResult.cancelled);

        case PurchaseStatus.error:
          _finish(BuyResult.failed);

        case PurchaseStatus.pending:
          // Slow payment methods exist — a bank transfer can take days. Say
          // nothing and leave the completer open; the event arrives later and
          // unlocks then, whether or not this screen is still on top.
          continue;
      }

      /*
        ── This has to happen, and it has to happen last ───────────────────

        An unacknowledged purchase is REFUNDED AUTOMATICALLY by Google after
        three days. Not failed, not pending — taken back, from somebody who
        paid and is using the app.

        It goes after the entitlement is written rather than before, so a crash
        between the two leaves a purchase that will be re-delivered rather than
        one that has been acknowledged and forgotten.
      */
      if (p.pendingCompletePurchase) {
        await _store.completePurchase(p);
      }
    }
  }

  void _finish(BuyResult result) {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete(result);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
