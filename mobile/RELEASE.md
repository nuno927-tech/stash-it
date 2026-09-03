# Releasing Stash it

Everything needed to get a build onto the Play Store, in the order it has to
happen. The first section is the one with no undo.

---

## 1. The upload key

**This is the only secret in the project that cannot be replaced.** Lose it and
the app on the Play Store can never be updated again — not by you, not by
anybody. Google's account-recovery process for a lost upload key exists but is
slow and not guaranteed, and it does not exist at all for the app signing key if
you opt out of Play App Signing.

Run this yourself. It asks for passwords, so it is not something to paste into a
chat window or a script.

### First, find keytool

It is not on PATH, and it is not supposed to be. `keytool` ships inside a JDK,
and the JDK this project uses is the one bundled with Android Studio rather than
a system-wide Java install — which is why `flutter` works fine and `keytool`
appears not to exist.

```powershell
$java = (flutter doctor -v | Select-String 'Java binary at:').ToString().Split(':',2)[1].Trim()
$keytool = Join-Path (Split-Path $java) 'keytool.exe'
$keytool
```

That prints something like
`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`.

If `flutter doctor` does not report a Java binary, look for it directly:

```powershell
Get-ChildItem 'C:\Program Files\Android','C:\Program Files\Java',"$env:LOCALAPPDATA\Programs" -Recurse -Filter keytool.exe -ErrorAction SilentlyContinue | Select-Object -First 1 FullName
```

### Then create the key

```powershell
mkdir C:\keys
& $keytool -genkey -v -keystore C:\keys\stash-it-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

The `&` is required in PowerShell when the command is held in a variable.

It will ask for:

- **a keystore password** — write it down somewhere that is not this laptop
- **a key password** — the same one is fine, and simpler to keep straight
- your name, organisation, city, country — none of it is shown to users, and
  none of it can be changed later, so "Nuno" and a country code is enough

`-validity 10000` is about 27 years. Google requires a key valid until at least
2033; there is no reason to cut it finer than this.

### Then

```powershell
copy "C:\Stash it\mobile\android\key.properties.example" "C:\Stash it\mobile\android\key.properties"
```

and fill in the two passwords. Both that file and the `.jks` are gitignored.

### Back it up now, not later

Copy `stash-it-upload.jks` and the passwords to **two places that are not this
computer** — a password manager and an external drive, or a password manager and
another machine. Not the project folder, and not anywhere that syncs into it.

The backup story for your own data in this app is a `.stashit` file. The backup
story for the key is you.

---

## 2. Check it is actually signed

> **Build from `C:\Stash it\mobile`, not from `C:\Stash it APK`.**
>
> That second folder is the pre-monorepo copy of this app and it is still a
> complete, buildable, signable Flutter project sitting at version 0.61.1. A
> bundle built there uploads happily and is missing every release since — and
> nothing about the build output says so. It is kept only as an archive.

```powershell
cd "C:\Stash it\mobile"
flutter build appbundle --release
```

The bundle lands at `build\app\outputs\bundle\release\app-release.aab`.

To prove it used your key rather than the debug fallback:

```powershell
& $keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

(`$keytool` from step 1 — a new PowerShell window will need it set again.)

The owner line should be what you typed in step 1. If it says `CN=Android Debug`
then `key.properties` was not found or not filled in, and Play will reject the
upload with a message that does not say so clearly.

---

## 3. What Play needs before it will take an upload

- **A developer account.** One-off $25, and identity verification that can take
  a couple of days. Start this first — it is the only step with a queue.
- **The application ID `app.stashit`** — already set, and permanent from the
  first publish.
- **A privacy policy at a public URL.** Required for every app. This one
  collects nothing and sends nothing anywhere, which makes it short, but the URL
  has to exist and resolve.
- **A data safety declaration.** The honest answers here are unusual and worth
  getting right: no data collected, no data shared, data is encrypted at rest,
  and users can request deletion by deleting the app. All of that is true.
- **Screenshots** — at least two phone screenshots, and a 512×512 icon, and a
  1024×500 feature graphic.
- **An app icon.** Currently Flutter's default. See section 5.

---

## 4. Closed testing: 12 testers, 14 days

A new personal developer account must run a closed test with **at least 12
testers who stay opted in for 14 consecutive days** before production access is
granted.

Read that carefully: it is twelve people who remain opted in for the whole
fortnight, not twelve who install it once. The clock restarts if the count drops
below twelve.

**Start this as early as a build will install and open**, because the fourteen
days run in the background while the rest of the app is finished. Waiting until
the app is polished adds two weeks to the end of the project for nothing.

Testers join by email address through a Google Group or a list in the Play
Console. They need the Google account that their phone uses.

---

## 5. The two URLs that do not resolve yet

Both are written into the app and both currently point at nothing. Neither
breaks a build, which is exactly why they need a checklist line.

### The Play Store link

`storeUrl` in `lib/ui/settings_tab.dart`, used by **Share Stash it**.

    https://play.google.com/store/apps/details?id=app.stashit

The address is predictable from the application id — `app.stashit`, set in
`android/app/build.gradle.kts` and permanent after the first publish — so it
will be correct the moment the listing goes live. Until then every share sends
somebody to a page that does not exist.

**Check it resolves before the closed test goes out.** Testers are the first
people who will press that button, and a dead link is what they will remember.

### The privacy policy page

`privacyUrl` in the same file. The policy people read is inside the app —
Settings → Privacy policy — but Play requires a public URL for the listing, and
the share text does not currently use this one.

The words to put on that page are in `lib/ui/privacy.dart`. **They are not the
same as the web app's policy**: there is no push server here and the database is
encrypted at rest, and the PWA's policy says the opposite of both.

---

## 6. The in-app product

The unlock is one non-consumable product, bought once, no subscription. The app
never sets the price — it reads whatever the Console says, localised, and shows
that. Hard-coding "$8" would be wrong in every country but one and wrong
everywhere the day the price changes.

**In the Play Console → Monetise → In-app products → Create product:**

| Field | Value |
| --- | --- |
| Product ID | `stash_it_unlock` |
| Name | Unlock unlimited |
| Description | Save as many things as you like. One payment, no subscription. |
| Price | $8.00 (Play converts and rounds for every other currency) |
| Status | Active |

**The product ID cannot be changed after the first sale.** It is what people
own. It is written plainly in `lib/billing/play_billing.dart` rather than
assembled, so a rename is a one-line diff and a deliberate one.

### Why it will show "the store is not answering" until several things are true

All four of these have to hold before a price appears, and from inside the app
they fail identically:

1. The product exists in the Console **and is Active**.
2. An app bundle with the same `applicationId` has been **uploaded to a track**
   — internal testing is enough. Billing does not work against a local debug
   build alone, even a signed one.
3. The build is signed with the **upload key**, not a debug key.
4. The Google account on the test device is on the **Licence testing** list
   (Console → Setup → Licence testing), or is an internal tester.

Licence testers are also the only way to buy this repeatedly without being
charged — the purchase goes through, the entitlement is written, and it can be
refunded from the Console to test the flow again.

### The one thing that will silently cost money

An unacknowledged purchase is **refunded automatically by Google after three
days** — not failed, not pending, taken back from somebody who paid and is
using the app. `completePurchase` is called in `play_billing.dart` after the
entitlement is written, and moving it, wrapping it in a condition, or
short-circuiting the purchase stream will reintroduce this. It has no visible
symptom for three days.

### Giving it away: promo codes

**This is how beta testers get free access.** Not a code compiled into the app,
and not the developer-tools button.

Play Console → Monetise → Promotions → **Promo codes** → Create promotion:

- Choose **In-app product**, then `stash_it_unlock`.
- One-time use, quantity as needed. **500 per app per quarter**, which is
  roughly forty times more than the twelve testers Play requires.
- Set an expiry. A code with no end date is a code circulating for ever.
- Download the CSV and hand out one code each.

A tester redeems it in the Play Store app — profile → Payments and
subscriptions → Redeem code — or at `play.google.com/redeem`. Google records a
real purchase against their account, `restorePurchases` finds it on a new
phone, and if somebody abuses one it can be refunded from the Console.

Three reasons this beats a code typed into the app:

1. **Nothing to leak.** A redeem code inside the APK is a bypass that anybody
   can find by decompiling, and once it is out it cannot be revoked without
   shipping an update — which the people already using it will not install.
2. **It exercises the real path.** Every tester redeeming is a test of
   purchase delivery, acknowledgement and restore. A custom bypass tests the
   bypass, and the first person to find out buying is broken is a paying
   customer.
3. **It is revocable and it expires.**

The one limitation: a promo code needs the app installed from Play, so it does
not help on a sideloaded debug build. That is what the developer-tools button
is for — Settings, ten taps on the version number, **Grant unlock**. It writes
the same entitlement through the same door and marks the source `dev`, so a row
that says `play` is one somebody actually paid for.

**That button is compiled out of release builds.** It sits behind `kDebugMode`,
which is a compile-time constant, so the subtree folds away and is tree-shaken
— it is not hidden in the shipped APK, it is not in it. For one version it was
not, and ten taps on a version number is not a secret: it is how Android's own
developer options work, so it is a convention people find by accident rather
than a lock they have to pick.

### What a client-side check is actually worth

Worth being clear-eyed about, because it changes what is and is not worth
building.

This app has no server, by design and permanently. That means the entitlement
is a boolean in a database on the handset, and **anybody willing to decompile
and patch the APK can set it.** No amount of obfuscation changes that; it moves
the bar from "twenty minutes" to "an afternoon".

So the check is not a lock, it is a turnstile. It exists so that:

- a casual user cannot stumble past it,
- somebody who wants to pay has an obvious way to,
- and somebody who does not want to pay has to decide to steal it rather than
  simply notice a button.

Everything above is aimed at the first of those. Chasing the third would mean a
server, an account and a login — which would cost more than the unlock earns
and would break the one promise the app is actually built on.

### Testing the restore path

Worth doing properly, because it is the path a paying customer hits on a new
phone and the one place the app can charge somebody twice:

- Buy on device A.
- Install on device B with the same Google account, fill to twenty, press
  **I already paid**.
- The entitlement should be written without a second charge.

---

## 7. Still to do before submitting

- [x] App icon and launch screen — `dart run flutter_launcher_icons` after any
      change to `assets/icon/`. The 512×512 the Play listing wants is already
      at `assets/icon/play-store-512.png`.
- [ ] Privacy policy URL — see section 5
- [ ] `storeUrl` verified to resolve — see section 5
- [ ] `stash_it_unlock` created and Active in the Console — see section 6
- [ ] A purchase made and restored on a second device — see section 6
- [ ] Screenshots from a real device with real data
- [ ] `flutter build appbundle --release` verified to open, restore and back up
      on a phone that has never had a debug build installed

That last one matters more than it sounds. A release build differs from a debug
build in ways that only show up at runtime, and the two most likely to bite here
are the SQLCipher native library and the notification receivers.

---

## A note on `pubspec.lock`

It is currently gitignored, which is right for a package and wrong for an app. A
released build should be reproducible from the repository, and without the lock
file a rebuild months later resolves whatever versions exist then — which is how
a build that worked in August stops working in November for no visible reason.

Worth changing before the first release rather than after.
