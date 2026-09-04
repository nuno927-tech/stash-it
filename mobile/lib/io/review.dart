/// Play's rating sheet, behind a seam.
///
/// ── Why the plugin does not appear anywhere else ──────────────────────────
/// `in_app_review` talks to Play Services. It cannot run in a test, it does
/// nothing on a phone with no Play Store, and on a device where the quota is
/// spent it returns having shown nothing at all. Every one of those is a
/// perfectly ordinary outcome that must not stop anything.
///
/// So the decision of WHETHER to ask lives in `logic/review.dart`, where it is
/// pure and tested, and this file is the two lines that ask. The same shape as
/// `io/text_recognition.dart` and for the same reason.
///
/// ── It is a request, not a dialog ─────────────────────────────────────────
/// `requestReview` hands the moment to Play, which decides whether to draw
/// anything. There is no return value worth reading: "did they rate" is not
/// something Google tells an app, deliberately, and an app that inferred it
/// would be inferring wrong.
library;

import 'package:in_app_review/in_app_review.dart';

/// Asks Play to consider showing its sheet.
///
/// True when the request was made — NOT when anybody rated anything, and not
/// even when a sheet appeared. It is only worth knowing so the app can record
/// that the moment was spent.
Future<bool> askForReview() async {
  try {
    final play = InAppReview.instance;
    if (!await play.isAvailable()) return false;

    await play.requestReview();
    return true;
  } catch (_) {
    /*
      Swallowed, like every other decoration in this app.

      No Play Services, an emulator, a sideloaded build, a device that throws
      on a channel it does not implement. A rating prompt that can break a save
      is a rating prompt worth deleting.
    */
    return false;
  }
}
