# Play Store listing copy

Paste the sections below into the Console. Play's full description field takes
plain text — the capitalised headings are deliberate, since bold and bullets do
not survive reliably.

---

## Short description (80 characters max)

Warranties, receipts and renewals. All on your phone, nothing in the cloud.

*(74 characters)*

---

## Full description (4,000 characters max)

Everything you own has a date attached to it. The washing machine's warranty. The passport that needs renewing before the summer. The subscription that quietly went up in price last month. Stash it keeps track of all of it, and tells you before it matters.

EVERYTHING STAYS ON YOUR PHONE

There is no account to create, no cloud to sign into, and no company database holding your records. Your things, your photos and your receipts are written to an encrypted database on your own device, and they stay there.

No analytics. No trackers. No advertising. Not even a launch counter.

WHAT YOU CAN KEEP IN IT

Items and warranties — record what you own with the price, the retailer, the model and the serial number. Expiry is worked out for you using proper calendar arithmetic, so 24 months from 31 January ends on 31 January, not three days earlier. Attach the receipt, the warranty and the manual, so they are all in one place on the day you actually need to make a claim. Organise by room. Search by name, brand, or half-remembered serial number.

Documents — passports, driving licences, insurance, certifications, memberships, pet vaccinations. Dates and general details only. The app deliberately has no field for a scan or a document number, because a file holding a passport number next to a name is a worse thing to lose than the passport was.

Subscriptions — what you pay, when it renews, and what it quietly adds up to per month and per year. A calendar shows the month at a glance. Split a shared subscription and record who actually pays for it.

REMINDERS THAT WORK WITHOUT A SIGNAL

Warnings arrive before cover ends or a renewal lands, at an hour you choose. They are worked out on your phone and handed to Android, so they keep working on a plane, in a tunnel, and on the day some server somewhere goes down. Tap one and it opens the exact record it was about.

Notifications name things rather than describe them — "Passport — Nuno" rather than "passport expires 11 February" — because a lock screen is readable by anyone holding the phone.

YOUR DATA IS YOURS, AND YOU CAN TAKE IT

Back everything up to a single file and put it wherever you like: a cloud drive, an email to yourself, a memory card in a drawer. Restore it onto a new phone in one step. Export to CSV instead if you would rather have spreadsheets. Nothing here is proprietary, and nothing is held hostage.

The database is encrypted using a key kept in your phone's own hardware-backed keystore, and the app itself can be locked behind your fingerprint.

ONE PAYMENT, IF YOU WANT IT

Stash it holds 20 things for free — items, documents and subscriptions combined — and every feature works at that tier. The reminders work. The backups work. The photographs work. Nothing is watermarked and nothing nags.

One payment lifts the limit for good. It is not a subscription, there is nothing to renew, and it is the only thing this app will ever ask you to pay for.

ABOUT THE PERMISSIONS

Camera, for photographing something you own or a receipt. Notifications, for the reminders. Fingerprint, for the optional lock. Run at startup, so scheduled reminders survive a restart.

Network access appears in the list because Google Play's own billing library requires it. Stash it uses it for nothing else — there is no account, no sync and no server of ours for it to reach.

Stash it is open source, so you do not have to take our word for any of this.

---

## Notes

- **"20 things"** is `freeItemLimit` in `lib/logic/limits.dart`. If that number
  changes, this copy is wrong and so is the unlock sheet.
- **The permissions paragraph is load-bearing.** Users can see the permission
  list on the listing page, and a description that failed to mention network
  access while claiming "nothing leaves your phone" would read as a lie the
  moment somebody expanded it. Saying it first, with the reason, costs three
  lines and buys the rest of the page its credibility.
- **No price is stated.** Play shows the real localised price, and a number
  written here would be wrong in every country but one, and wrong everywhere
  the day it changes.
