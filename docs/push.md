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

```bash
# .env.local — gitignored
VAPID_PUBLIC_KEY=BJx...
```

`vite.config.ts` reads it into `__VAPID_PUBLIC_KEY__`. With no key the switch
in Settings stays off and says *"Reminders are not configured in this build"*,
which is the correct behaviour for a fork and for CI.

**Never add `VAPID_PRIVATE_KEY` here.** Nothing in the app has any use for it,
and anything in `.env.local` that the app imports ends up in a public bundle.

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
