/// The passphrase, asked for before the first document scan and not after.
///
/// ── Why a scan is the thing that changes the bet ───────────────────────────
/// A backup is a plain zip unless somebody locks it. That was a reasonable
/// default while the worst it could hold was a list of appliances and what
/// they cost — a real loss, and a survivable one.
///
/// A photograph of a passport is not that. It is the page somebody
/// impersonates you with, and it would be sitting in a cloud folder in a file
/// anybody who can open the folder can read. Offering the same shrug for both
/// would be the app pretending they are the same risk.
///
/// So the lock goes on before the first scan is taken rather than being
/// suggested afterwards. `whyKeepTheLock` is the other half: once one exists,
/// it cannot be turned off again while it does.
///
/// ── Asked, not imposed ─────────────────────────────────────────────────────
/// Somebody can still say no — and then there is no scan, which is the honest
/// outcome. What must not happen is a scan taken and a backup left open,
/// because that is the one combination nobody chose and nobody is told about.
library;

import 'package:flutter/material.dart';

import '../io/vault.dart';
import 'feedback.dart';
import 'passphrase_sheet.dart';
import 'theme.dart';

/// True when a scan may be taken — either backups are already locked, or one
/// has just been locked in answer to this.
Future<bool> allowScan(BuildContext context) async {
  if (await backupsAreLocked()) return true;
  if (!context.mounted) return false;

  final c = StashColors.of(context);
  feedback(Cue.tap);

  final wants = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: c.slate800,
      title: Text(
        'Lock your backups first',
        style: TextStyle(
          fontFamily: fontDisplay,
          fontWeight: FontWeight.w800,
          fontSize: 19,
          color: c.text,
        ),
      ),
      content: Text(
        'A scan of a document goes into your backups, and an unlocked backup '
        'is a plain file anyone who opens that folder can read.\n\n'
        'Set a passphrase and the app will keep them sealed. It takes a '
        'minute and you only do it once.',
        style: TextStyle(
          fontFamily: fontBody,
          fontSize: 13.5,
          height: 1.5,
          color: c.muted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: cued(() => Navigator.of(context).pop(false)),
          child: Text(
            'Not now',
            style: TextStyle(fontFamily: fontBody, color: c.muted),
          ),
        ),
        TextButton(
          onPressed: cued(() => Navigator.of(context).pop(true)),
          child: Text(
            'Set a passphrase',
            style: TextStyle(fontFamily: fontBody, color: c.gold),
          ),
        ),
      ],
    ),
  );

  if (wants != true || !context.mounted) return false;

  /*
    The app's own passphrase sheet, not a second one written for here.

    It carries the warning that nobody can reset it and the twelve-character
    rule, and both have to be the same wherever a passphrase is set — a second
    sheet is a second place for that warning to drift.
  */
  final phrase = await askForNewPassphrase(context);
  if (phrase == null || phrase.trim().isEmpty) return false;

  await setBackupPassphrase(phrase);
  return true;
}
