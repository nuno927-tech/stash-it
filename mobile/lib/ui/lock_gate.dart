/// The lock that the switch in Settings has always claimed to turn on.
///
/// ── What was actually wrong ───────────────────────────────────────────────
/// `biometricLock` was written to the database by the Settings switch, and read
/// by nothing. `local_auth` was imported in exactly one file — settings_tab.dart
/// — where it ran a single prompt to confirm the switch, saved `true`, and said
/// "Locked. You will be asked next time the app opens."
///
/// Nobody was ever asked. The one prompt people saw was the confirmation, which
/// looks identical to the thing being set up and so read as proof it worked.
/// That is the worst shape a security bug can take: it is not that the lock
/// failed, it is that it convincingly appeared to succeed.
///
/// ── Why it wraps the splash rather than living inside it ──────────────────
/// `Splash` draws its child UNDERNEATH itself and fades away to reveal it, so
/// the app is built and painted from the first frame. A gate placed inside that
/// would be a picture of a lock laid over a live screen — and the moment the
/// splash faded, or a screenshot was taken by the task switcher, the records
/// would be there. So this sits outside, and the child is not constructed at
/// all until it opens.
library;

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../db/repository.dart';
import '../logic/prefs.dart';
import 'parts.dart';
import 'scout.dart';
import 'theme.dart';

/*
  ── How long you can be away before it asks again ───────────────────────────

  Thirty seconds, and the number is doing real work.

  This app leaves itself constantly and legitimately: the camera for a receipt,
  the file picker for a manual, the share sheet for every single backup. All of
  them background the app. Re-locking on every return would mean a fingerprint
  between choosing a photo and seeing it attached, and a second one after
  sending a backup — which is the point at which people switch the lock off and
  never switch it on again.

  Long enough to cover a round trip to another app and back. Short enough that a
  phone put down on a table is locked before anybody else picks it up.
*/
const Duration lockGrace = Duration(seconds: 30);

/// Whether a resume after [away] should ask again.
///
/// Pulled out as a function with no widget in it so the rule can be tested;
/// the rest of this file needs a platform and a screen.
bool shouldRelock({required bool enabled, required Duration away}) =>
    enabled && away >= lockGrace;

/*
  ── The loop this exists to end ────────────────────────────────────────────

  The gate recorded when the app was left and worked out, on every resume, how
  long it had been away. It never cleared that timestamp — so after a
  successful unlock it was still holding the moment the app was backgrounded
  minutes or hours earlier.

  The biometric sheet is itself an app coming to the front, so dismissing it
  delivers another `resumed`. That one arrived after the unlock had finished,
  found the old timestamp, decided the app had been away for an hour and asked
  again. Scanning a finger produced the prompt again, for ever.

  A departure is CONSUMED by the resume that answers it. Null means there is
  nothing to answer — the sheet's own resume, or a second resume after one has
  already been dealt with — and nothing to answer can never re-lock.
*/
bool relockOnResume({
  required bool enabled,
  required DateTime? leftAt,
  required DateTime now,
}) =>
    leftAt != null &&
    shouldRelock(enabled: enabled, away: now.difference(leftAt));

class LockGate extends StatefulWidget {
  const LockGate({required this.repo, required this.child, super.key});

  final Repository repo;

  /// Built only once the gate is open.
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  /// Null until the setting has been read. Not `false` — the difference is a
  /// frame of the app showing before the lock arrives.
  bool? _enabled;

  bool _open = false;
  bool _asking = false;
  String? _said;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _read();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _read() async {
    final settings = await widget.repo.settings();
    final wanted = prefsFrom(settings).biometricLock;
    if (!mounted) return;

    setState(() {
      _enabled = wanted;
      _open = !wanted;
    });

    if (wanted) _ask();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_enabled != true) return;

    /*
      The prompt itself backgrounds the app.

      Android delivers `inactive`, and on some devices `paused`, while the
      system biometric sheet is up. Without this guard the app would note that
      it had been left, come back, decide it had been away, and ask again —
      forever, with the user unable to do anything but watch.
    */
    if (_asking) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _leftAt = DateTime.now();

      case AppLifecycleState.resumed:
        // Consumed here, before anything is decided, so a second resume for
        // the same departure cannot ask a second time.
        final left = _leftAt;
        _leftAt = null;

        if (relockOnResume(
          enabled: true,
          leftAt: left,
          now: DateTime.now(),
        )) {
          setState(() => _open = false);
          _ask();
        }

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _ask() async {
    if (_asking) return;
    setState(() {
      _asking = true;
      _said = null;
    });

    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock Stash it',
        options: const AuthenticationOptions(
          stickyAuth: true,

          /*
            Device PIN and pattern are accepted as well as a fingerprint, and
            that is deliberate rather than lazy.

            `biometricOnly: true` would mean a person whose sensor breaks, or
            whose enrolled prints are cleared by a system update, can never
            open this app again. There is no account and no server, so there is
            no "log in on the web and turn it off" — their records would be on
            a phone in their hand and permanently unreachable.

            The fallback is not a weakening: getting to the device PIN screen
            already requires the device PIN.
          */
          biometricOnly: false,
        ),
      );

      if (!mounted) return;

      // Nothing left to answer. Belt and braces with the consumption on
      // resume: whichever of the two runs first, the stale departure is gone
      // before the sheet's own resume can be read as one.
      _leftAt = null;

      setState(() {
        _asking = false;
        _open = ok;
        _said = ok ? null : 'Not confirmed.';
      });
    } catch (e) {
      /*
        ── Failing open, and why ─────────────────────────────────────────────

        This is reached when the phone cannot run the check at all: no
        biometrics enrolled any more, hardware unavailable, the plugin
        throwing on a device it does not understand.

        It lets you in, and says so. That is the right way round for THIS app.
        The lock guards the app, not the data — the database key is released
        from the Keystore whether or not anybody touched the sensor, which is
        stated plainly beside the switch and again in the privacy policy. So
        refusing entry here would not protect anything; it would only separate
        somebody from their own records, permanently, with no way back.

        A lock that can brick your data is a lock people are right not to
        trust.
      */
      if (!mounted) return;
      _leftAt = null;

      setState(() {
        _asking = false;
        _open = true;
        _said =
            'This phone could not run the check, so the lock was skipped: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    // Setting not read yet: hold the splash colour rather than flash the app.
    if (_enabled == null) return ColoredBox(color: c.slate800);
    if (_open) return widget.child;

    final height = MediaQuery.of(context).size.height;

    return ColoredBox(
      color: c.slate800,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /*
                On guard, not on alert.

                `alert` is the ears-up pose the dashboard uses for "something
                needs a minute" — a warning. Nothing is wrong here: the app is
                shut, which is what was asked for. Wearing the warning face
                while asking for a fingerprint reads as an accusation, and it
                is the same face somebody sees when they genuinely have
                overdue paperwork, which spends it.

                `acorn` is the launch-screen pose — guarding the thing itself.
                It is also literally the pose on the screen a second earlier,
                so the lock reads as part of opening the app rather than as
                something that went wrong on the way in.
              */
              Scout(
                pose: ScoutPose.acorn,
                height: height * 0.32,
                motion: const [ScoutMotion.breathe],
                shadow: true,
              ),
              const SizedBox(height: 24),
              const Wordmark(fontSize: 34),
              const SizedBox(height: 10),
              Text(
                'Locked',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 15,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 28),

              // Always a way to try again. A lock screen whose only prompt has
              // been dismissed, with no button on it, is an app that cannot be
              // opened without force-quitting.
              FilledButton(
                onPressed: _asking ? null : _ask,
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  disabledBackgroundColor: c.slate600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                child: Text(
                  _asking ? 'Waiting…' : 'Unlock',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: _asking ? c.muted : c.onGold,
                  ),
                ),
              ),

              if (_said != null) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _said!,
                    textAlign: TextAlign.center,
                    style: hintStyle(c),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
