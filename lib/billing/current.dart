/// The app's one billing connection.
///
/// ── A library variable, not a provider ────────────────────────────────────
/// There is exactly one store connection per process and it is needed from
/// three places that have nothing to do with each other: the item form, the
/// document form and Settings. Threading a `Billing` through five widget
/// constructors to reach three leaves would be plumbing for its own sake.
///
/// The same shape `devmode.dart` and `feedback.dart` already use, for the same
/// reason: a process-wide fact that the UI reads and does not own.
///
/// It starts as `NoBilling` so that a `flutter test`, a desktop run or any
/// build that never calls `startBilling` gets the honest answer — a store that
/// cannot sell anything — rather than a null to check for.
library;

import 'billing.dart';

Billing appBilling = const NoBilling();

/// Called once from `main`, on the platforms that can sell.
void startBilling(Billing billing) {
  appBilling.dispose();
  appBilling = billing;
}
