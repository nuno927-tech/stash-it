/// The privacy policy, in the app.
///
/// ── Why it is not a link ──────────────────────────────────────────────────
/// A link needs a browser, a network and a URL that still resolves in three
/// years. This app has none of the first two by design and cannot promise the
/// third — and a privacy policy that 404s is worse than none, because the app
/// went out of its way to point at it.
///
/// So the words ship with the build they describe. That also fixes a subtler
/// problem: a hosted policy describes whatever version was current when it was
/// written, while this one cannot be out of step with the app carrying it.
///
/// ── It is NOT the web app's policy ────────────────────────────────────────
/// Two claims in that one are false here, and both in the app's favour, which
/// is the direction that matters:
///
///  - **There is no push server.** The web version had to send a list of
///    moments to a sender so a browser could be woken. Android schedules
///    locally, so nothing leaves at all — see lib/notify/reminders.dart.
///  - **The database is encrypted at rest**, with a key in this handset's
///    Keystore. The web version said plainly that it was not.
///
/// Copying the web policy across would have been the port's most visible
/// untruth, on the one screen written to earn trust. The same trap the tour's
/// notify step fell into — see the README.
library;

import 'package:flutter/material.dart';

import 'feedback.dart';
import 'theme.dart';

/// Slides up over two thirds, and scrolls.
Future<void> showPrivacy(BuildContext context) {
  feedback(Cue.tap);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: StashColors.of(context).slate700,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (context) => const _Sheet(),
  );
}

/// The policy itself. A list of (heading, body) so the sheet can lay it out
/// rather than the text carrying its own markup.
const List<(String, String)> _policy = [
  (
    'We do not have your data',
    'Not as a promise about how carefully we look after it — as a description '
        'of how the app is built. There is no account, no server holding your '
        'records, and nothing for anyone to look at even if they wanted to.',
  ),
  (
    'The short version',
    '• No account. You never give anyone an email address or a name.\n\n'
        '• Everything stays on this phone, in a database encrypted with a key '
        'held by the phone itself.\n\n'
        '• No analytics, no trackers, no ads. None. Not a launch counter.\n\n'
        '\u2022 The app itself never sends anything anywhere. Nothing you '
        'record leaves this phone unless you share it deliberately.\n\n'
        '\u2022 The one exception is buying the unlock, which Google Play '
        'handles rather than us \u2014 and it is the only reason the app can '
        'reach the network at all.\n\n'
        '\u2022 Home screen widgets are the one exception to \u201Cit stays in the '
            'encrypted database\u201D. A widget is drawn by your launcher, not by '
            'this app, so what it shows is copied into ordinary phone storage \u2014 '
            'and it is on your home screen where anyone can read it. Only add '
            'one if you are happy with that.',
  ),
  (
    'What is stored, and where',
    'Everything you put in is written to a database on this device. It is not '
        'uploaded, synced or mirrored. Uninstall the app and it is gone — which '
        'is why the app keeps asking you to make a backup.\n\n'
        'That includes the things you record and their prices, dates, warranty '
        'terms, rooms and notes; photographs and files you attach; documents '
        'you track; subscriptions and their amounts; your settings, and the '
        'name Scout calls you.',
  ),
  (
    'Documents are dates only',
    'The app deliberately cannot store a scan or a document number — there is '
        'no field for either, on purpose. A backup is a plain file the moment '
        'you share it, and a passport number next to a name is a better '
        'identity-theft package than the scan would be.',
  ),
  (
    'Encryption, and what it does not cover',
    'The database is encrypted with SQLCipher, using a key kept in this '
        'phone\'s hardware-backed Keystore. The key never leaves the handset, '
        'which is also why a lost phone means lost data: nobody can open the '
        'file, including us.\n\n'
        'The backup file you export is NOT encrypted. It has to be readable by '
        'a future version of the app and by you, so treat it like any other '
        'file holding your records.',
  ),
  (
    'Reminders',
    'Reminders are worked out on this phone and handed to Android, which wakes '
        'the app on the day. Nothing is sent anywhere, because there is nowhere '
        'to send it — no account, no sender, no keys.\n\n'
        'The web version of Stash it could not do this. A browser cannot wake '
        'itself, so it needed a server that knew which phone to ping and when. '
        'That whole arrangement is absent here.\n\n'
        'What a notification says is composed on the phone and shown by the '
        'phone. It deliberately names things rather than describing them — '
        '"Passport — Nuno" and not "passport expires 11 February" — because a '
        'lock screen is readable by anyone holding the phone.',
  ),
  (
    'Backups you choose to send',
    '"Back up now" makes one file with everything in it and hands it to the '
        'phone\'s share sheet. Where it goes — a cloud drive, an email to '
        'yourself — is your choice and happens outside Stash it. It is never '
        'received by anyone here.',
  ),
  (
    'Locking a backup with a passphrase',
    'You can set a passphrase, and from then on every backup the app writes '
        'is encrypted with it — AES-256, with the key stretched from your '
        'passphrase so that guessing it is slow.\n\n'
        'Nobody can reset it and nobody has a copy: not us, not Google, and '
        'not anyone who finds the file. That is the point of it, and it is '
        'also the risk — a backup whose passphrase is forgotten is gone, and '
        'so is everything in it. Write it down somewhere that is not this '
        'phone.\n\n'
        'The format is written down in the app\'s own source so that a person '
        'with the passphrase can open a backup with ordinary tools and no '
        'copy of Stash it. Encryption should not be the reason you cannot '
        'reach your own data.',
  ),
  (
    'The folder you choose for automatic backups',
    'You can pick a folder and let the app write a backup into it on the same '
        'interval it would otherwise nag you on. Android asks you which '
        'folder and grants the app permission to that one only — it cannot '
        'see anything else on your device, and you can take the permission '
        'back in Android\'s own settings or by pressing Stop in the app.\n\n'
        'Where that folder lives is entirely your choice. If it is one your '
        'cloud app syncs, your backups go wherever that account is; Stash it '
        'writes a file and knows nothing about what happens to it afterwards. '
        'The app still has no network permission and still sends nothing '
        'anywhere.\n\n'
        'The file is not encrypted, for the reason below. Anyone who can open '
        'that folder can read it, so choose one only you can reach. The app '
        'keeps the five most recent and deletes older ones — only files it '
        'wrote itself, matched by name; nothing else in the folder is ever '
        'touched.',
  ),
  (
    'The biometric lock',
    'It guards the app, not the data. The database key is released to the app '
        'whether or not you have just used the sensor, so the lock stops '
        'somebody picking up your phone; it does not stop somebody with your '
        'phone and a laptop.',
  ),
  (
    'Getting in touch',
    'The contact links open your own mail app with a message already written. '
        'Nothing is sent until you press send, and you can see every word '
        'first — including the one line naming the app version, which is there '
        'to save a round trip and is the only thing added.',
  ),
  (
    'Changes',
    'This policy ships inside the app, so it describes exactly the version you '
        'are holding. If it changes, it changes in an update you installed.',
  ),
];

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    final c = StashColors.of(context);

    return FractionallySizedBox(
      heightFactor: 0.66,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 10),
              child: Text(
                'Privacy',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                  letterSpacing: -0.6,
                  color: c.text,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                children: [
                  for (final (heading, body) in _policy) ...[
                    Text(
                      heading,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: TextStyle(
                        fontFamily: fontBody,
                        fontSize: 13,
                        height: 1.5,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),

            /*
              A gradient over the last few pixels of the list, so a policy that
              continues below the fold looks like it does. A sheet that ends in
              a hard edge reads as finished, and this one rarely is.
            */
            Container(
              height: 1,
              color: c.line,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: FilledButton(
                onPressed: () {
                  feedback(Cue.tap);
                  Navigator.of(context).pop();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: c.gold,
                  foregroundColor: c.onGold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: c.onGold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
