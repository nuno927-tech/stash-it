# Publishing Stash it to the Play Store

A step-by-step walkthrough, from "no Google account for this" to "live on the
store".

`RELEASE.md` is the companion to this file. That one covers the signing key and
the build commands in depth; this one covers the account, the Console, the
forms, and the order to do everything in. Where they overlap, this file points
there rather than repeating it.

---

## Read this bit first

Three things have a queue or a clock. Everything else can be done in an
afternoon. Start these now, in this order:

| Thing | How long | Why it blocks you |
| --- | --- | --- |
| Developer account + ID check | 2–5 days | You cannot upload anything until it clears |
| Target Android 16 | one line of code | See the deadline below |
| Closed test: 12 testers, 14 days | 14 days minimum | You cannot go public until it's done |

**Two dates matter right now.**

- **31 August 2026** — from this date, brand new apps must be built against
  Android 16 to be accepted. Stash it is a brand new app. See step 2.2. There is
  an extension form in the Console that buys you until 1 November if you need it.
- **September 2026** — new personal developer accounts must pass an identity
  check before they can publish to *any* track, including test tracks. You can
  set things up and upload while it's pending, you just can't push it live.

The 14-day test runs in the background while you finish everything else. Get a
build that installs and opens into testers' hands as early as you can — waiting
until the app is perfect adds two weeks to the end for no reason.

---

## Step 1 — Set up the developer account

### 1.1 Pick which Google account owns this

Whatever account you sign up with **owns the app permanently**, and it's the
name that appears on your store listing. It's a headache to move later.

Use a Google account you'll still control in five years. Not a work address you
might lose access to.

### 1.2 Register

Go to **play.google.com/console** and sign up.

- Choose **Personal** (an Organisation account needs a registered business and a
  D-U-N-S number, which you don't have and don't need).
- Pay the **$25 one-off fee**. There's no annual renewal. It is **not refunded
  if your identity check fails**, so make sure your details match your ID before
  you pay.
- Accept the Developer Distribution Agreement.

### 1.3 Pass the identity check

You'll be asked for:

- a government photo ID — passport or driving licence
- possibly a selfie / live face check
- your legal name and address, which **must match the ID exactly**

Takes 2–5 working days. Mismatched names are the usual reason it fails.

While you wait, you can do steps 2, 4 and 5 — set up the app, upload builds,
fill in the listing. You just can't publish to a track until it clears.

### 1.4 Set up a payments profile

Needed before you can charge for the unlock. Console → **Setup → Payments
profile**. You'll give bank details and tax information for wherever you live.

Do this early too. It's not instant, and the $8 unlock does nothing without it.

---

## Step 2 — Get the app ready to build

### 2.1 The signing key

**This is the step with no undo.** If you lose this file, the app on the store
can never be updated again — not by you, not by anyone.

Full instructions are in `RELEASE.md`, section 1. The short version:

- You create a keystore file once, with a password.
- It's already set up — `android/key.properties` exists on your machine and both
  it and the `.jks` are kept out of Git on purpose.
- **Back the keystore file and its passwords up to two places that are not this
  computer.** A password manager and an external drive. Not the project folder,
  and not anywhere that syncs into it.

Do the backup today. Everything else in this guide is recoverable.

### 2.2 Target Android 16 — done in 0.61.2

`android/app/build.gradle.kts` used to say `compileSdk = flutter.compileSdkVersion`
and `targetSdk = flutter.targetSdkVersion` — meaning "whatever this laptop's
Flutter install defaults to", which for many current versions is **35, not 36**.
Play rejects a new app that isn't on 36 from 31 August 2026.

Both are now pinned to `36` in the file, where the number can be read and
diffed rather than depending on when the machine last ran `flutter upgrade`.

**Two things still to do yourself:**

1. **Install the SDK.** If Android SDK Platform 36 isn't on the machine the
   build fails immediately. Android Studio → Settings → Languages & Frameworks
   → Android SDK → tick **Android 16.0 ("Baklava" / API 36)** → Apply.

2. **Test on a real phone.** Android 16 makes edge-to-edge drawing mandatory,
   so the app now paints behind the status and navigation bars whether it asked
   to or not. Anything at the very top or bottom of a screen that isn't inside a
   `SafeArea` will sit underneath them. Check the tab bar, the add button, and
   the top of every bottom sheet.

**One related thing left open:** `minSdk` still reads `flutter.minSdkVersion`,
under a comment claiming it's set explicitly. It isn't, and the comment is
wrong. It's very likely fine — SQLCipher needs API 23 and every current Flutter
default is above it — but that's a different claim from the one the comment
makes. Build once, read the number out of the merged manifest, and pin it.
It decides which phones can install the app at all, so it's worth knowing
rather than inheriting.

### 2.3 Give it a version number Play will accept — done in 0.61.2

`pubspec.yaml` had no build number, so Play would have seen **version code 1**.
It now reads:

```yaml
version: 0.61.2+1
```

The part after the `+` is the number Play cares about. **Bump it every single
time you upload anything**, even a test build you throw away five minutes
later — a version code can never be reused and can never go down, so the first
throwaway upload burns `+1` permanently.

The version *name* (`0.61.2`) is just the text people see, and is kept in step
with `appVersion` in `lib/ui/settings_tab.dart`.

A simple habit: `+1`, `+2`, `+3`… and never reuse one.

### 2.4 Put the privacy policy on the web

The app has a policy screen built in (Settings → Privacy policy), but **Play
also needs one at a public web address** it can open.

The app currently points at:

```
https://nuno927.github.io/stash-it/privacy.html
```

**Open that in a browser and check it actually loads.** When I checked, it came
back empty, which usually means the page isn't published yet. If it's not there:

1. Create a public GitHub repository called `stash-it` (or reuse it if it
   exists).
2. Add a file `privacy.html` with the policy text — the words are already
   written in `lib/ui/privacy.dart`.
3. In the repo: **Settings → Pages → Source: main branch**. Wait a minute, then
   reload the URL.

**Don't reuse the web app's policy.** This version has no push server and the
database is encrypted on the phone; the old policy says the opposite of both.

### 2.5 Make the store graphics

You have the icon. You don't have a feature graphic yet.

| Asset | Size | Format | Where you are |
| --- | --- | --- | --- |
| App icon | 512 × 512 | PNG, transparency allowed | ✅ `assets/icon/play-store-512.png` |
| Feature graphic | 1024 × 500 | JPEG or PNG, **no transparency**, under 1 MB | ❌ needs making |
| Phone screenshots | at least 2, ideally 4–6 | JPEG or PNG, portrait, 9:16 | ❌ needs taking |

Screenshots: take them on a real phone with **real-looking data in it**. Empty
screens are the single most common reason a listing looks abandoned. Fill it
with a handful of believable items first — a boiler, a laptop, a passport, a
couple of subscriptions.

The feature graphic is the wide banner at the top of your listing. Keep the
wordmark near the middle; the edges get cropped on some screens.

---

## Step 3 — Build the file you upload

```powershell
cd "C:\Stash it APK"
flutter build appbundle --release
```

The file lands at:

```
build\app\outputs\bundle\release\app-release.aab
```

**It's an `.aab`, not an `.apk`.** Play only accepts `.aab` for new apps.

Before you upload, prove it used your real key and not the debug fallback —
`RELEASE.md` section 2 has the command. If it says `CN=Android Debug`, Play will
reject it with a message that doesn't explain why.

---

## Step 4 — Create the app in the Console

Console → **All apps → Create app**.

| Field | Answer |
| --- | --- |
| App name | Stash it |
| Default language | English |
| App or game | App |
| Free or paid | **Free** |
| Declarations | Tick both (ads policy, export laws) |

**"Free" is correct even though there's an $8 unlock.** Free means free to
download. Charging inside the app is an in-app purchase, which is a separate
thing. You cannot change free to paid later, so getting this wrong is a real
problem — a paid app cannot be made free, and a free app cannot be made paid.

---

## Step 5 — Fill in the forms

These are under **App content** and **Store listing** in the left sidebar. Play
won't let you publish until every one has a green tick.

### 5.1 Store listing

- **App name** — Stash it (30 characters max)
- **Short description** — 80 characters, shown in search results. This is the
  one that does the work. Something like:
  *Warranties, receipts and renewals. All on your phone, nothing in the cloud.*
- **Full description** — 4,000 characters. Lead with the problem, not the
  feature list. Mention that nothing is uploaded, because that's the unusual
  part.
- Upload the icon, feature graphic and screenshots from step 2.5.
- **Category** — Productivity. **Tags** — pick 3–5.
- **Contact email** — this is shown publicly on your listing.
- **Privacy policy URL** — the one from step 2.4.

### 5.2 Data safety

This is the one most people get wrong. Your answers are unusually simple because
they're all "no", and **they're all true** — this app has no server.

| Question | Answer |
| --- | --- |
| Does your app collect or share any user data? | **No** |
| Is data encrypted in transit? | N/A — nothing is transmitted |
| Can users request data deletion? | Yes — deleting the app deletes everything |

Photos and documents the user adds stay on the device and are never sent
anywhere, so they are not "collected" in Play's sense. Collected means *sent off
the phone*.

Be honest here. Google spot-checks this against what the app actually does, and
a wrong answer gets the app pulled.

### 5.3 Content rating

Fill in the questionnaire honestly. For an app like this — no violence, no
adult content, no gambling, no user-to-user communication — you'll come out at
**Everyone / PEGI 3**.

The rating is issued instantly once you submit the answers.

### 5.4 Target audience

Choose **18 and over**.

This is about who the app is *for*, not who could technically use it. Anything
that includes under-13s pulls you into Google's Families policy, which brings a
pile of extra requirements you don't want and don't need.

### 5.5 App access

If any part of the app needs a login to see, you have to give Google test
credentials. Stash it doesn't — choose **All functionality is available without
special access**.

### 5.6 Permissions you'll be asked about

You declare four. None are in Google's "sensitive" list that needs a written
justification, but be ready to explain them:

| Permission | Why |
| --- | --- |
| Notifications | Reminders before a warranty or renewal runs out |
| Camera | Photographing an item or a receipt |
| Biometrics | Optional fingerprint lock on the app |
| Run at startup | So scheduled reminders survive a phone restart |

---

## Step 6 — Set up the $8 unlock

Console → **Monetise → In-app products → Create product**.

| Field | Value |
| --- | --- |
| Product ID | `stash_it_unlock` |
| Name | Unlock unlimited |
| Description | Save as many things as you like. One payment, no subscription. |
| Price | $8.00 |
| Status | **Active** |

**The product ID can never be changed after the first sale.** It's what people
own. It must match the app exactly — it's written in
`lib/billing/play_billing.dart`.

The app never hard-codes the price. It asks Play what the price is and shows
whatever comes back, already converted into local currency. Change the price in
the Console and the app follows.

### It will say "the store is not answering" until all of these are true

From inside the app these four failures look identical, so check all of them:

1. The product exists in the Console **and is Active**.
2. A build has been **uploaded to a track** — internal testing counts. Billing
   does not work against a build installed straight from your laptop.
3. The build is signed with your real key, not a debug key.
4. The Google account on the test phone is on the **licence testing** list
   (Console → Setup → Licence testing).

Licence testers can buy it over and over without being charged, which is how you
test the flow.

### Free access for beta testers

Use **promo codes**, not a code built into the app.

Console → **Monetise → Promotions → Promo codes**. You get 500 per quarter,
which is forty times more than you need. Set an expiry date. Send one per
tester, and they redeem it in the Play Store app.

Full reasoning is in `RELEASE.md` section 6.

---

## Step 7 — Internal testing (a day)

Console → **Testing → Internal testing → Create new release**.

- Upload the `.aab`.
- Add your own email and a couple of friends (up to 100 people).
- Roll it out.

Install it from the link Play gives you — **not** from your laptop — and check:

- [ ] It opens on a phone that has never had a debug build on it
- [ ] The Go Pro price shows a real price, not "the store is not answering"
- [ ] Buying works, and the limit lifts
- [ ] "I already paid" restores it on a second phone with the same account
- [ ] A reminder notification arrives, and tapping it opens the right record
- [ ] Backup writes a file and restoring it brings everything back

That last pair matters more than it sounds. Release builds differ from debug
builds in ways that only show up when they're running — the encrypted database
and the notification scheduler are the two most likely to bite.

---

## Step 8 — Closed testing (14 days, in the background)

This is the long pole. **Start it the moment step 7 passes.**

Console → **Testing → Closed testing → Create a new release**.

### The rule

You need **12 people opted in, continuously, for 14 days in a row.**

Read that carefully:

- Twelve people who *stay* opted in — not twelve who install it once.
- If someone opts out and you drop to eleven, **the clock restarts.**
- They need to accept the invitation with the same Google account their phone
  uses. This trips up nearly everyone at least once.

So get **15 or 16** people, not exactly 12. Assume some will drop out or use the
wrong account.

### Setting it up

1. Make a Google Group, or paste a list of email addresses into the Console.
2. Send everyone the opt-in link Play generates.
3. Tell them plainly: *accept the link, install it, and please don't uninstall
   for two weeks.*
4. Watch the tester count in the Console. If it dips below 12, chase it
   immediately — every day it's low is a day added to the end.

You can keep uploading new builds to this track the whole time. Fixing bugs
doesn't reset the clock; losing testers does.

---

## Step 9 — Apply for production

After 14 clean days, a button appears on the Console dashboard: **Apply for
production access**.

You'll write a short form about how testing went and what you changed. Be
specific — "found and fixed a crash when restoring a backup" reads better than
"went well".

Google reviews this. Allow **up to a week**, sometimes more.

---

## Step 10 — Publish

Console → **Production → Create new release**.

- Upload the `.aab` (with a **higher version code** than the test build — see
  step 2.3).
- Write the release notes. Keep them plain: what's new, in one or two lines.
- **Roll out at 20% first**, not 100%. If something's badly wrong you'll see it
  in the crash reports before it reaches everyone. Move to 100% after a couple
  of quiet days.

First review of a brand new app usually takes a few days.

### Once it's live

Check that this opens properly, because the app's Share button uses it:

```
https://play.google.com/store/apps/details?id=app.stashit
```

It's `storeUrl` in `lib/ui/settings_tab.dart`. Until the listing goes live, every
share sends someone to a page that doesn't exist.

---

## Publishing an update, later

Much shorter once the first one's done:

1. Bump the version in `pubspec.yaml` — **both parts**: `0.62.0+2`
2. `flutter build appbundle --release`
3. Console → Production → Create new release → upload → release notes
4. Roll out at 20%, then 100%

No forms, no review queue in most cases. Updates are usually live within hours.

---

## The full checklist

**Account**

- [ ] Developer account registered, $25 paid
- [ ] Identity check passed
- [ ] Payments profile set up

**Code**

- [ ] Keystore backed up in two places away from this computer
- [x] `targetSdk = 36` and `compileSdk = 36` pinned in build.gradle.kts
- [ ] SDK Platform 36 installed, and a build tested on a real phone for
      edge-to-edge problems
- [ ] `minSdk` pinned to a real number instead of Flutter's default
- [x] `version:` has a `+build` number — remember to raise it every upload
- [x] Privacy policy written for this app and live at
      `nuno927-tech.github.io/stash-it/privacy-android.html`
- [ ] `flutter analyze` and `flutter test` clean

**Assets**

- [ ] 512 × 512 icon
- [ ] 1024 × 500 feature graphic
- [ ] At least 2 phone screenshots, with real-looking data in them

**Console**

- [ ] App created, set to **Free**
- [ ] Store listing filled in
- [ ] Data safety: no data collected
- [ ] Content rating questionnaire submitted
- [ ] Target audience: 18+
- [ ] `stash_it_unlock` created and **Active**

**Testing**

- [ ] Internal test installed from Play and working
- [ ] A real purchase made, and restored on a second phone
- [ ] 12+ testers opted in
- [ ] 14 continuous days served

**Launch**

- [ ] Production access granted
- [ ] Released at 20%
- [ ] Store URL confirmed working

---

## Things that will waste a day if you don't know them

- **Version code can only go up.** Upload a build with code 5 and you can never
  use 1–5 again, on any track.
- **Free vs paid is permanent.** Set it to Free.
- **The 14-day clock restarts if testers drop below 12.** Over-recruit.
- **Testers must accept with the account their phone signs into.** The most
  common single point of failure in the whole process.
- **Billing needs a Play-installed build.** It will never work from a build you
  copied onto the phone yourself, no matter how correctly it's signed.
- **An unacknowledged purchase gets auto-refunded after three days.** The app
  handles this correctly today; don't move that code without reading the note in
  `RELEASE.md` section 6. It has no visible symptom for three days.

---

## Sources

Current as of 26 August 2026 — Play's rules change often, so check the Console's
own dashboard if something here doesn't match what you see.

- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Target API level requirements for Google Play apps](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Add preview assets to showcase your app](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
- [Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)
- [Content rating requirements](https://support.google.com/googleplay/android-developer/answer/9859655?hl=en)
