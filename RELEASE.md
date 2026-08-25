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
copy "C:\Stash it APK\android\key.properties.example" "C:\Stash it APK\android\key.properties"
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

```powershell
cd "C:\Stash it APK"
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

## 5. Still to do before submitting

- [x] App icon and launch screen — `dart run flutter_launcher_icons` after any
      change to `assets/icon/`. The 512×512 the Play listing wants is already
      at `assets/icon/play-store-512.png`.
- [ ] Privacy policy URL
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
