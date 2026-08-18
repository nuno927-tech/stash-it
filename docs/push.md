# Reminders — phase 1, the device half

Everything needed for a notification to appear on a phone, except the thing
that sends it. You can finish and test all of this today: no hosting, no
accounts, no money, and nothing here locks in a backend choice later.

This supersedes the push architecture in `subscriptions-and-push.md`, which
planned Firebase Auth plus a Firestore document per user. The Stripe and
pricing sections of that document still stand.

---

## The idea it is all built around

> A sender has to know **when** to wake the phone and **where** to send the
> ping. It does not have to know **what the reminder says**.

- `src/lib/push.ts` works out the dates *and the words*, on the device, from
  the same code the dashboard uses.
- The words are parked in Cache Storage. Only the **dates** would ever be
  uploaded.
- The push that arrives on the day carries **no payload at all**.
  `public/push-handler.js` opens the cache and reads what the page wrote.

Breach the sender and you have a set of push endpoints and a set of dates. Not
one item name, price, passport or photograph. `test/push.test.ts` asserts that
property directly — if a name or an amount ever appears in the uploaded shape,
the suite fails.

---

## 1. Generate a VAPID keypair

One keypair, once, for the whole app. The **public** half goes in the build and
is handed to Google and Apple; the **private** half signs sends and must never
enter this repository.

```bash
npx web-push generate-vapid-keys
```

```
Public Key:   BJx...roughly 87 characters, base64url
Private Key:  8Kf...roughly 43 characters
```

Put the private key in a password manager now. Losing it means every existing
subscription becomes unreachable and everyone has to turn reminders on again.

## 2. Put the public key in the build

**`.env.local` is already in the repository root**, gitignored, with the line
waiting. Paste the public key after the `=`:

```bash
VAPID_PUBLIC_KEY=BJx...
```

No quotes, no spaces around the `=`. `.env.example` is the committed copy of
the same file, for anyone cloning this.

`vite.config.ts` reads it through `loadEnv` — **not** `process.env`, which
does not contain .env files inside a Vite config and would silently build an
empty key while the file looked perfectly filled in. A real shell variable
still wins, so CI can pass one without a file.

**`.env.local` only configures your laptop.** The deployed app is built by
GitHub Actions from a fresh checkout, and `.env.local` is gitignored, so the
published build has no key unless CI is given one. Repo → Settings → Secrets
and variables → Actions → **Variables** → New repository variable:

| Name | Value |
|---|---|
| `VAPID_PUBLIC_KEY` | the same public key as `.env.local` |
| `PUSH_ENDPOINT` | the sender's base URL, once phase 2 is deployed |

**Variables, not secrets.** Both are public — the key is handed to Google and
Apple by the browser, the endpoint is a URL the app fetches — and both land in
the bundle regardless. A secret would only make them unreadable to you. Set as
secrets by mistake, `vars.VAPID_PUBLIC_KEY` resolves to empty and the build
ships unconfigured; the *Check the reminders build* step in `deploy.yml` exists
because that failure is otherwise invisible — green deploy, working app, switch
that just refuses.

With no key the switch in Settings stays off and says *"Reminders are not
configured in this build"*, which is correct for a fork and for CI.

**Never add `VAPID_PRIVATE_KEY` here.** Nothing in the app has any use for it,
and anything in `.env.local` that the app reads ends up in a public bundle.

## 3. Run it

```bash
npm run dev
```

Service workers need a secure context. `localhost` counts, so dev works — but
`npm run dev` does not build the worker. To exercise the real thing:

```bash
npm run build && npm run preview
```

Open Settings → **Reminders**, tap **See exactly what would be sent** and read
the dates. Then flip the switch and accept the browser prompt.

## 4. Fire a push without a server

Chrome DevTools → **Application** → **Service workers** → the **Push** box →
**Push**. Leave the payload empty — an empty payload is what the real thing
sends, so testing with one is testing the actual path.

You should get a notification naming whatever is due today. If nothing is due,
you get *"Nothing needs you"*, which is the correct all-clear and not a bug.

To see a real reminder, set a document's expiry so its renew-by lands today,
reopen the app so the note is rewritten, then push again.

**Tapping it** should focus the open app rather than opening a second copy.

## 5. On an iPhone

Web push on iOS only exists for a PWA **added to the Home Screen** — Safari
will not offer it from a browser tab. The app detects this and the switch says
so rather than failing.

1. Deploy somewhere with HTTPS, or use a tunnel to your dev server.
2. Safari → Share → **Add to Home Screen**.
3. Open it **from the Home Screen icon**, not from Safari.
4. Settings → Reminders → the switch.

The permission prompt has to come straight out of a tap. `enablePush()` calls
`Notification.requestPermission()` with nothing awaited in front of it for
exactly that reason — the same class of bug as the share sheet refusing after a
long export. Don't add an `await` above it.

---

## What phase 2 adds, and what it must not

A sender. Roughly 150 lines: `register`, `forget`, and an hourly cron.

Three rules that keep the claim above true:

1. **It stores dates, and a delivery address. Nothing else.** No names, no
   labels, no counts of what kind.
2. **It sends an empty push.** The moment a payload carries text, the sender
   knows what your reminders say and so does anyone who breaches it.
3. **It is small enough to read, and public.** A privacy claim nobody can check
   is marketing. Under a couple of hundred lines, open source, linked from the
   Reminders card.

And the honest exceptions, which belong in that card whatever else changes:
the delivery address lives on Google's or Apple's servers, so they can see that
a phone was pinged and when; and a sender sees an IP each time the schedule
refreshes. Sync weekly in a batch rather than on every edit, or the sender can
watch you typing.

---

## Files

| File | What it is |
|---|---|
| `src/lib/push.ts` | Pure. Wake dates, the wording, the permission verdict. Tested in Node. |
| `src/lib/pushClient.ts` | The browser bits: permission, subscribe, writing the cache. |
| `public/push-handler.js` | The worker. Reads the cache, shows the notification. Does no thinking. |
| `test/push.test.ts` | Including the assertion that nothing but dates leaves. |

`push-handler.js` is imported into the generated Workbox worker alongside
`share-handler.js`, rather than switching the project to a custom bundled
worker. That keeps the precaching and the `autoUpdate` handover exactly as they
are — this app has already lost days to a service worker that would not hand
over, and a push feature is not worth risking that again.

The price of that choice is that the worker is plain JavaScript and cannot run
`buildTimeline`, which is why the words are precomputed. The note is rewritten
on every launch, so it is only ever as old as your last visit to the app.

---

# Phase 2 — the sender

Firebase, on purpose, and with one thing done differently from the plan in
`subscriptions-and-push.md`: **raw Web Push with our own VAPID pair, not the
Firebase Cloud Messaging SDK.** Phase 1 subscribed through
`pushManager.subscribe`, so the endpoints are ordinary Web Push URLs — Google's
for Chrome, Apple's for Safari, Mozilla's for Firefox. FCM's SDK would mean a
Google-specific token, a different path to an iPhone, and no way to move host
later without every subscriber re-enrolling.

## The honest cost of choosing Firebase

Worth knowing before you commit, because it is the one thing Cloudflare would
have done better.

On Android, the delivery endpoint is already Google's (`fcm.googleapis.com`).
Put the sender on Google too and **one company holds both halves** — the
schedule and the delivery — joined by the endpoint URL, which appears on both
sides. Split across two vendors, each sees half and neither can join them
without the other's cooperation.

For iPhone and Firefox users it makes no difference: those endpoints are
Apple's and Mozilla's and Google never sees them.

Whether that matters is a judgement about how much a list of dates is worth.
It is a real weakening and a small one, and consolidating on one vendor you
already use has its own honest value. Just don't claim the two-vendor property
in any copy while running on Firebase.

## The steps

**1. Create the project.** <https://console.firebase.google.com> → Add project.
Turn Google Analytics **off** — it is a tracker on a privacy feature.

**2. Blaze plan, then cap it.** Cloud Functions cannot deploy on Spark, so a
card is required. Set a budget alert at $1 immediately: your realistic bill for
this is zero, and the alert is there to tell you if something is being abused.

**3. Firestore.** Project shortcuts → **Firestore** → **Create database**. It is
a three-step wizard, and the middle step contains the only irreversible
decision in this whole document.

1. **Edition** — **Standard**. Enterprise buys a query engine and MongoDB
   compatibility; this database has one collection and one range query.
2. **Database ID & location** — leave the ID as `(default)`. The free tier and
   `firebase deploy` both assume it. For **Location** the console offers
   `nam5 (United States)`, a multi-region; pick **`us-central1 (Iowa)`**
   instead. It is the region Cloud Functions default to, so the sweep's reads
   are local, and a single region is cheaper per operation. Multi-region buys
   survival of losing one US region, which here would delay a notification
   rather than lose anything — every subscription can be re-registered from the
   phone that made it. **This cannot be changed afterwards.** Moving means a
   new database and every subscriber re-enrolling.
3. **Configure** — **Start in production mode**. The preview pane should read
   `allow read, write: if false;`, which is character-for-character what
   `firestore.rules` deploys in step 7. Test mode opens the database to the
   world for 30 days and there is no reason to spend a single one of them: the
   functions run with admin credentials and never consult these rules.

Nothing reaches this database from a browser — only through the functions.
Confirm on the **Rules** tab that it says `if false` before moving on.

**4. Install and log in.**

```bash
npm install -g firebase-tools
firebase login
firebase use --add          # pick the project, alias it "default"
cd functions && npm install && cd ..
```

**5. The secrets.** The private key finally gets a home — this one, and nowhere
else.

```bash
firebase functions:secrets:set VAPID_PUBLIC_KEY
firebase functions:secrets:set VAPID_PRIVATE_KEY
```

**6. Tell it which websites may call it.** Nothing to do — the file already
exists at **`functions/.env`**:

```
ALLOWED_ORIGINS=https://nuno927-tech.github.io
```

Firebase reads it automatically on deploy. Add `https://stash-it.app` to the
same line, comma separated and with no trailing slash, the day that domain
exists. Anything not on the list is refused.

*An earlier version of this step said to put it in `firebase.json`. That was
wrong and there was nothing to find: `firebase.json` says what to deploy, not
what the deployed code is configured with.*

`functions/.env` is committed on purpose and is the only `.env` file in the
repository that is — a list of allowed websites is public, and keeping it
tracked is what makes a deploy from a fresh clone behave like a deploy from
this laptop. Because that is an exception to the rule stopping a private key
being committed, `test/push.test.ts` fails if any name other than
`ALLOWED_ORIGINS` appears in it. **The private key never goes in a file** — it
goes in Firebase's secret store, in step 5.

**7. Deploy.**

```bash
firebase deploy --only functions,firestore:rules
```

It prints the function URLs. Take the base — everything before `/register` —
and put it in `.env.local`. For this project that is:

```
PUSH_ENDPOINT=https://us-central1-stashit-47534.cloudfunctions.net
```

Then set the same value as the `PUSH_ENDPOINT` **repository variable** on
GitHub, or the deployed app still has no sender. `.env.local` configures one
laptop; see the note in step 2.

Only `register` and `forget` print a URL. `sweep` has none by design — it is
triggered by the clock, not by anything on the internet, and there is no
address at which a stranger could ask it to run. Confirm all three appear in
the Functions dashboard, `sweep` with a clock icon rather than an HTTP badge.

**8. Turn the logging down.** Cloud Logging keeps request metadata including IP
addresses by default, which quietly undoes part of what this design is for.
Google Cloud console → Logging → Log Router → the `_Default` sink → add an
exclusion for these functions' request logs. The sweep logs three counts and
nothing else; that is all you need.

**9. Rebuild and try it.** `npm run build && npm run preview`, turn the switch
on, and check Firestore: one document, containing an endpoint, two keys, and a
list of integers. If it contains anything else, something has gone wrong in
`clean()` and the promise on the settings card is no longer true.

## Testing it — the bench in Settings → Developer

Tap the version pill ten times. The card stays open until you press **Hide**,
which matters here more than anywhere else: testing a notification means
leaving Settings to see whether it arrived.

A reminder crosses four things that break independently, so there is a button
for each, in the order the chain runs.

| | What it proves | Needs |
|---|---|---|
| The readout | Where the chain stands right now | — |
| **1. Show one now** | Permission, the icon, and what tapping it does | A built copy, not `npm run dev` |
| **2. Fake a reminder for today** | The wording, on a day that has one | — |
| **3. Send a real push** | Sender → Google or Apple → this phone | A deployed `ping`, and the app closed |

Read the grid before pressing anything. It shows what the **browser** thinks
and what the **database** thinks as separate rows, because the failure worth
catching is when they disagree: *Switch on, Subscription none* is a device the
sender will ping every week and that cannot show a thing. It goes red rather
than grey, because grey would look like a switch nobody turned on.

Three requires the extra endpoint, which deploys with everything else:

```bash
firebase deploy --only functions
```

`ping` sends **to a device already in the database and nowhere else** — a 404
otherwise. That is not much of a lock, and it does not need to be: holding
someone's subscription means they turned the switch on, and the sweep can
already ping them hourly. It adds no reach that registering did not. The
ten-second cooldown is about a retry loop in a test build hammering a real push
service, which is how a sender gets itself rate-limited for everyone.

**It is still an empty push.** There is no test mode where the payload carries
words — a switch like that is how the words start travelling. The same rule
covers the whole bench: nothing there can make the app do something it cannot
do in production, or the bench passes while the feature is broken.

Press 3 with the app **closed**. Some platforms show a foreground notification
by a different route, so a foreground test can pass on a device where the real
thing never appears.

## What the sweep does, and the bug it nearly had

Hourly, `where('nextWake', '<=', now)`.

The first version asked `array-contains-any` for every hour boundary in the
window, which only matches a wake that lands exactly on one. A wake is 9am
wherever the user is — and India is +5:30, Nepal +5:45, South Australia +9:30.
Measured: 9am on 4 September 2026 is epoch `1788492600` in Kolkata and
`1788491700` in Kathmandu. Neither divides by 3600. Around a billion and a half
people would have registered successfully, appeared correctly in Firestore, and
never been sent anything at all.

`nextWake` is the soonest of the list, kept beside it and indexed, so the sweep
is one range query with nothing rounded and no window to miss.
