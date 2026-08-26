package app.stashit

import io.flutter.embedding.android.FlutterFragmentActivity

/*
   FlutterFragmentActivity, not FlutterActivity.

   The biometric prompt is a Fragment — androidx.biometric puts it in the host
   activity's fragment manager — and a plain FlutterActivity has no fragment
   manager to put it in. `local_auth` answers that by reporting no biometrics
   available at all rather than by failing when asked, so the switch in
   Settings simply never appeared and there was nothing to debug.

   It is a drop-in swap: FlutterFragmentActivity is a FragmentActivity that
   hosts the same Flutter engine, and nothing else in the app can tell.
*/
class MainActivity : FlutterFragmentActivity()
