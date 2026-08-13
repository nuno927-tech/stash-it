# Stash it Pro — subscriptions and push reminders

A build guide. Everything here is either a console step you do by hand or a file
that goes in the repo, in the order they need to happen.

**Decisions this document is built on**

| Decision | Choice |
|---|---|
| What's paid | Push reminders, and the 15-item cap stays a Pro feature |
| Price | **$10/year** shown first, **$1/month** as the alternative. No free trial |
| Sign-in | Documented **both ways** — pick one at Phase 4. Email link or Google |
| Free Pro | Grants by email, plus 100% promo codes for beta cohorts — §11 |
| Address | `stash-it.app` — the site at the root, the app at `/app/` — §2 |
| Payments | Stripe direct (not a merchant of record) |
| Backend | Firebase: Auth, Firestore, Cloud Functions, Cloud Messaging |

**One thing to be honest with yourself about up front.** The reminders are
genuinely enforceable, because your server sends them and it can refuse. The
item cap is not, and never will be — it's a boolean in the user's own browser,
and anyone who opens devtools can lift it in four seconds. You've chosen to
keep it paid anyway, which is fine, but price and describe Pro as if reminders
are the product. If someone cracks the cap you lose nothing; if someone cracks
reminders they can't, because there's nothing on the device to crack.

---

## 0. How the whole thing fits together

```
   Phone                    Stripe                Firebase
   ─────                    ──────                ────────
   [Subscribe] ───────────► Checkout
                              │
                              │ webhook
                              ▼
                          stripeWebhook ────► subscribers/{uid}
                                                (status, periodEnd)
                                                   ▲
   [Turn on reminders] ──────────────────────► registerPush
                                                   │ reads, refuses if inactive
                                                   ▼
                                              reminders/{uid}
                                                (token, dates, tz)
                                                   │
                     hourly ──► sendReminders ─────┘
                                     │
                                     ▼
                                    FCM ──► notification on the phone
```

The enforcement point is `registerPush` and `sendReminders`. Both read
`subscribers/{uid}`, which **only the webhook can write** — Firestore rules deny
all client writes to it. The `proUnlock` flag in the app becomes a cache of that
document, used to decide what the UI looks like. Forging it changes what the
screen says and nothing else.

---

## 1. Before you start

### Accounts

- **Stripe account** — <https://dashboard.stripe.com/register>. You'll be asked
  for a business type. In the US, "Individual / sole proprietor" is a normal
  answer for this and doesn't require registering a company. You'll need a bank
  account for payouts and your SSN or EIN for identity verification.
- **Google account** for Firebase — use one you'll still have in five years, not
  a throwaway.

### Tax, briefly, and not as advice

Stripe direct means you are the merchant of record: sales tax and VAT liability
is yours. At the volumes you're likely to see for a while this sits under most
registration thresholds, but the thresholds are per-jurisdiction and change.
Stripe Tax will calculate and collect for 0.5% per transaction if you switch it
on later. Worth half an hour with an accountant before you cross a few hundred
subscribers — not before you have one.

### Two pages you need on the site before Stripe will be happy

Stripe expects a public business site with terms and a privacy policy, and
Google's sign-in consent screen wants a privacy policy URL too. Add to
`site/`:

- `site/terms.html` — what the subscription is, what it costs, that it renews,
  how to cancel, your refund stance.
- `site/privacy.html` — what you collect (email, subscription status, expiry
  dates, a push token), who processes it (Stripe, Google/Firebase), how to
  delete it.

Keep both plain and short. They're the two documents on your site people
actually read when deciding whether to trust you.

### Local tooling

```bash
npm install -g firebase-tools
brew install stripe/stripe-cli/stripe     # or scoop install stripe on Windows
firebase login
stripe login
```

---

## 2. Phase 1 — The domain

**Do this first, before anything else in this document.** Every URL that
follows — Checkout's success and cancel pages, the portal return, the webhook
endpoint, Firebase's authorised domains, `APP_URL` in the functions config —
has to point at the address you're going to keep. Setting them all up against
`nuno927-tech.github.io` and moving afterwards means revisiting every one of
them, in two dashboards, with a live subscriber base watching.

There's also a harder reason, in §2.5.

### 2.1 Buy it

`stash-it.app` runs about $14–20 a year. Check `stashit.app` too — one less
thing to get wrong when someone types it from memory, so take it if it's free.

Buy from **Cloudflare Registrar** (at-cost, no markup, free DNS) or
**Porkbun**. Avoid Squarespace, which absorbed Google Domains and raised
prices.

One property of `.app` worth knowing: the entire TLD is on the HSTS preload
list, so **HTTPS is mandatory** — browsers refuse plain http to it, always.
Fine for us, GitHub Pages issues a certificate automatically. It does mean you
cannot test that hostname over http, even locally.

### 2.2 DNS

Four A records and four AAAA records on the apex, plus a CNAME for `www`:

```
A     @     185.199.108.153
A     @     185.199.109.153
A     @     185.199.110.153
A     @     185.199.111.153
AAAA  @     2606:50c0:8000::153
AAAA  @     2606:50c0:8001::153
AAAA  @     2606:50c0:8002::153
AAAA  @     2606:50c0:8003::153
CNAME www   nuno927-tech.github.io.
```

On Cloudflare set every one of these to **DNS only** — the grey cloud, not the
orange one. Proxying in front of GitHub Pages produces certificate errors and
redirect loops that take an evening to diagnose and buy you nothing here.

### 2.3 Repo changes

- **`site/CNAME`**, one line: `stash-it.app`. The deploy workflow already
  copies `site/*` into `out/`, so it lands at the root by itself.
- **`.github/workflows/deploy.yml`**: `BASE_PATH: /app/` and `SITE_PATH: /`.
  The manifest's `id`, `start_url` and `scope` are derived from those, so they
  follow along without further edits.
- **`src/lib/contact.ts`**: `DEVELOPER_EMAIL` becomes `hello@stash-it.app`
  (see §2.6).

The result is the site at `stash-it.app` and the app at `stash-it.app/app/`.

**Keep the app as a path, not `app.stash-it.app`.** A subdomain is a different
origin: it would need its own certificate, its own storage, and it would break
the service worker scope arrangement that currently lets one worker serve the
share target and the cache. There's nothing to gain.

### 2.4 GitHub settings

Settings → Pages → set the custom domain → wait for the certificate to be
issued (usually minutes, occasionally an hour) → tick **Enforce HTTPS**.

Once the custom domain is live, GitHub redirects the old
`nuno927-tech.github.io/stash-it/` URLs to it automatically, so existing links
and bookmarks keep working.

### 2.5 The reason this can't wait

**Changing the origin orphans everyone's data.** IndexedDB at
`nuno927-tech.github.io` and IndexedDB at `stash-it.app` are separate stores.
An installed app will follow the redirect to the new address and find itself
empty — nothing has been deleted, it's simply at a location the new origin
cannot read.

Today that's you and perhaps a tester. Export a backup, move, restore. With a
few hundred users it's a migration project with a support queue attached.

Once you're on a domain you own, this problem never returns: moving from GitHub
Pages to Firebase Hosting or anywhere else later becomes a DNS change with no
data migration at all.

### 2.6 Email at the domain, while you're here

**Cloudflare Email Routing is free.** Point `hello@stash-it.app` at your Gmail
and it forwards, with no mailbox to run and nothing to maintain.

Do it now, because three things want that address and none of them should have
a personal Gmail in it: the "Ask a question" rows in Settings, the Stripe
receipts and terms page, and whatever you put on the marketing site. It's the
same instinct as wanting your name out of the URL.

---

## 3. Phase 2 — Stripe (all dashboard, no code)

Do all of this in **test mode** first. The toggle is top-right of the dashboard.
Everything below has a separate test and live version, including the keys and
the webhook.

### 3.1 Product and prices

Products → **Add product**.

- Name: `Stash it Pro`
- Description: `Warranty reminders, and no item limit.`

Add two prices to that one product — not two products:

| | Price | Billing period | Lookup key |
|---|---|---|---|
| Annual | $10.00 USD | Yearly | `pro_annual` |
| Monthly | $1.00 USD | Monthly | `pro_monthly` |

Set the lookup keys. They let you swap prices later without redeploying
functions. Copy both **price IDs** (`price_...`) — you'll need them in Phase 5.

### 3.2 Statement descriptor

Settings → Business → **Public details**.

Set the statement descriptor to `STASHIT.APP`. This is the single highest-value
setting on this page: most chargebacks are people not recognising a line on
their statement. Set the shortened descriptor too if offered.

### 3.3 Customer portal

Settings → Billing → **Customer portal**.

- Allow customers to **cancel subscriptions** — immediately or at period end,
  your call. At period end is friendlier and loses you nothing.
- Allow **update payment method**.
- Allow **switch plans** between your two prices.
- Set the return URL to `https://stash-it.app/app/`.
- Add links to your terms and privacy pages.

Save. This is the whole of your cancellation UI — one tap away, no email to you.

### 3.4 Emails

Settings → Billing → **Subscriptions and emails**:

- **Send emails about expiring cards** — on.
- **Send emails when card payments fail** — on.
- **Send a reminder before a subscription renews** — on, 7 days. Non-optional
  in my view: a $10 charge arriving twelve months after someone forgot they
  subscribed is the classic dispute.

Settings → Emails: turn on **successful payment receipts**.

### 3.5 Smart retries

Settings → Billing → **Manage failed payments**. Leave Smart Retries on, and
set the end behaviour to **cancel the subscription** after the retry schedule
finishes. That way a dead card ends cleanly instead of leaving a zombie record.

### 3.6 Keys

Developers → API keys. Copy the **secret key** (`sk_test_...`). Never put this
in the app bundle — it goes in Firebase secrets only.

---

## 4. Phase 3 — Firebase project

### 4.1 Create it

<https://console.firebase.google.com> → Add project → `stash-it`. Disable Google
Analytics for the project — you don't want it and it complicates the consent
story.

### 4.2 Upgrade to Blaze, then immediately cap it

Cloud Functions cannot be deployed on the free Spark plan. You must upgrade to
Blaze, which needs a card.

**Do this in the same sitting:**

1. Firebase console → ⚙ → Usage and billing → Details and settings → **Modify
   plan** → Blaze.
2. Google Cloud console → Billing → **Budgets and alerts** → Create budget.
   Set $5/month, with alerts at 50%, 90% and 100%.
3. Note the numbers you're actually expecting: at 1,000 subscribers the daily
   job reads ~30,000 Firestore documents a month against a free tier of 50,000
   *a day*. FCM is free and unlimited. Your realistic bill is $0. The budget
   alert exists to catch a bug in a loop, not normal usage.

### 4.3 Firestore

Build → Firestore Database → Create database → **Production mode** → pick a
region close to your users (`us-central1` if you're unsure; note it, functions
should match).

Two collections, both created automatically on first write:

```
subscribers/{uid}
  status          'active' | 'past_due' | 'canceled' | 'incomplete'
  plan            'annual' | 'monthly'
  currentPeriodEnd  timestamp
  customerId      'cus_...'
  updatedAt       timestamp

reminders/{uid}
  token           FCM registration token
  tz              'America/New_York'
  sendHourUtc     14            // the UTC hour that is 9am for them
  dates           [{ at: '2026-11-21', label: 'Fabric' }, ...]
  lastSentKey     '2026-11-21|Fabric'
  updatedAt       timestamp
```

Note what is deliberately **not** there: no item names, no photos, no prices,
no room names. Dates and policy labels only. See §10 for the one decision you
may want to revisit there.

### 4.4 Security rules

Firestore → Rules. Replace with:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Written only by the Stripe webhook, through the Admin SDK, which
    // bypasses these rules. The client may read its own row and nothing else.
    match /subscribers/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if false;
    }

    // Written only by the callable functions, which check entitlement first.
    match /reminders/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

Publish. **This file is the enforcement.** Every other check is convenience.

### 4.5 Authorised domains

Build → Authentication → Settings → **Authorised domains**. Add:

```
stash-it.app
```

If you haven't done §2 yet, stop and do it — an authorised domain you're about
to abandon is one of the several places a late move bites you.

`localhost` is there by default for development.

---

## 5. Phase 4 — Sign-in (pick one)

Free users never see any of this. The only moment a Stash it user is asked to
identify themselves is the moment they choose to pay — which they're doing with
a card anyway.

### Option A — Email link (passwordless)

**Why:** nothing to remember, nothing to reset, portable to a new phone, and
you need their email for receipts regardless. **Cost:** they have to leave the
app, open mail, and come back.

**Console:** Authentication → Sign-in method → **Email/Password** → enable, and
tick **Email link (passwordless sign-in)**. Leave password sign-in itself off.

**Client:**

```ts
// src/lib/auth.ts
import { getAuth, sendSignInLinkToEmail, isSignInWithEmailLink, signInWithEmailLink }
  from 'firebase/auth';

const ACTION = {
  url: 'https://stash-it.app/app/?signin=1',
  handleCodeInApp: true,
};

export async function startEmailSignIn(email: string) {
  await sendSignInLinkToEmail(getAuth(), email, ACTION);
  // Kept so the second half of the flow doesn't have to ask again.
  localStorage.setItem('stashit.signin.email', email);
}

/** Call on every launch. Completes the flow if we arrived from the link. */
export async function completeEmailSignIn(): Promise<boolean> {
  const auth = getAuth();
  if (!isSignInWithEmailLink(auth, location.href)) return false;

  const email =
    localStorage.getItem('stashit.signin.email') ??
    window.prompt('Confirm the email you used') ??
    '';
  if (!email) return false;

  await signInWithEmailLink(auth, email, location.href);
  localStorage.removeItem('stashit.signin.email');
  history.replaceState({}, '', location.pathname); // drop the token from the URL
  return true;
}
```

**The catch to test:** on Android, an installed PWA shares storage with Chrome,
so the link opening in a browser tab still signs the installed app in. On iOS a
standalone PWA has its own storage jar, and it may not. Test on both before
launch; if iOS misbehaves, that's an argument for Option B.

### Option B — Google sign-in

**Why:** one tap, nothing typed, no round trip through email. **Cost:** an app
that advertises needing no account now asks for a Google account, and anyone
without one is shut out.

**Console:** Authentication → Sign-in method → **Google** → enable. Set the
support email. Then Google Cloud console → APIs and services → OAuth consent
screen: fill in app name, support email, your privacy policy and terms URLs,
and add your domain.

**Client:**

```ts
// src/lib/auth.ts
import { getAuth, GoogleAuthProvider, signInWithPopup, signInWithRedirect,
         getRedirectResult } from 'firebase/auth';
import { isStandalone } from '@/lib/install';

export async function signInWithGoogle() {
  const auth = getAuth();
  const provider = new GoogleAuthProvider();
  // Popups are blocked or invisible in a standalone PWA on several platforms;
  // redirect is the reliable path there.
  if (isStandalone()) return signInWithRedirect(auth, provider);
  return signInWithPopup(auth, provider);
}

/** Call on every launch, to pick up the redirect half of the flow. */
export async function completeGoogleSignIn() {
  await getRedirectResult(getAuth());
}
```

### Either way

Add a **delete account** path (§11). And in Settings, the signed-in state should
show the email and a "sign out" — someone who pays deserves to see who they
are to you.

---

## 6. Phase 5 — Cloud Functions

### 6.1 Scaffold

```bash
cd "C:\Stash it"
firebase init functions      # TypeScript, ESLint yes, install deps yes
cd functions
npm install stripe firebase-admin firebase-functions
```

Keep the functions directory inside the repo. It deploys separately from the
app but belongs with it.

### 6.2 Secrets

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY      # paste sk_test_...
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET  # from §6.5
```

These are stored in Google Secret Manager and injected at runtime. They never
enter your repo or your bundle.

### 6.3 Shared setup

```ts
// functions/src/config.ts
import { defineSecret } from 'firebase-functions/params';

export const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
export const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');

export const APP_URL = 'https://stash-it.app/app/';
export const REGION = 'us-central1';

// From Stripe → Products. Swap for live IDs when you go live.
export const PRICES = {
  annual: 'price_REPLACE_ME_ANNUAL',
  monthly: 'price_REPLACE_ME_MONTHLY',
} as const;

/**
 * Your own uid, so you can exercise Pro without paying, and the authorisation
 * for the admin callables in §11.2. Replaces the old client-side dev toggle —
 * the bypass lives on the server now.
 *
 * Only ever your own. Everyone else gets a grant (§11.1): a name in here costs
 * a redeploy to add and another to remove, and it lives in git forever.
 */
export const DEV_UIDS = new Set<string>(['PASTE_YOUR_FIREBASE_UID']);
```

```ts
// functions/src/entitlement.ts
import { getFirestore } from 'firebase-admin/firestore';
import { DEV_UIDS } from './config';

/**
 * The only question that matters. Called before storing a push token and again
 * before every send, because a subscription can lapse between the two.
 */
export async function isActive(uid: string): Promise<boolean> {
  if (DEV_UIDS.has(uid)) return true;

  const snap = await getFirestore().doc(`subscribers/${uid}`).get();
  if (!snap.exists) return false;

  const d = snap.data()!;
  if (d.status !== 'active' && d.status !== 'trialing') return false;

  // Past the paid-for period with no renewal recorded: treat as lapsed rather
  // than trusting a status field that a failed webhook may have left stale.
  const end = d.currentPeriodEnd?.toMillis?.() ?? 0;
  return end > Date.now() - 3 * 24 * 60 * 60 * 1000; // 3-day grace
}
```

### 6.4 Checkout and portal

```ts
// functions/src/billing.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import Stripe from 'stripe';
import { APP_URL, PRICES, REGION, STRIPE_SECRET_KEY } from './config';

export const createCheckout = onCall(
  { region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');

    const uid = req.auth.uid;
    const plan = req.data?.plan === 'monthly' ? 'monthly' : 'annual';
    const stripe = new Stripe(STRIPE_SECRET_KEY.value());

    const existing = await getFirestore().doc(`subscribers/${uid}`).get();

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [{ price: PRICES[plan], quantity: 1 }],
      client_reference_id: uid,
      customer: existing.data()?.customerId,
      customer_email: existing.exists ? undefined : req.auth.token.email,
      // Belt and braces: the webhook reads uid from here, which survives even
      // if the checkout session object is long gone by the time it fires.
      subscription_data: { metadata: { uid } },
      success_url: `${APP_URL}?checkout=done`,
      cancel_url: `${APP_URL}?checkout=cancelled`,
      allow_promotion_codes: true,
    });

    return { url: session.url };
  },
);

export const createPortal = onCall(
  { region: REGION, secrets: [STRIPE_SECRET_KEY] },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');

    const snap = await getFirestore().doc(`subscribers/${req.auth.uid}`).get();
    const customerId = snap.data()?.customerId;
    if (!customerId) throw new HttpsError('failed-precondition', 'No subscription.');

    const stripe = new Stripe(STRIPE_SECRET_KEY.value());
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: APP_URL,
    });
    return { url: session.url };
  },
);
```

### 6.5 The webhook

```ts
// functions/src/webhook.ts
import { onRequest } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import Stripe from 'stripe';
import { REGION, STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from './config';

export const stripeWebhook = onRequest(
  { region: REGION, secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (req, res) => {
    const stripe = new Stripe(STRIPE_SECRET_KEY.value());

    let event: Stripe.Event;
    try {
      // rawBody, not body: the signature covers the exact bytes Stripe sent.
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        req.headers['stripe-signature'] as string,
        STRIPE_WEBHOOK_SECRET.value(),
      );
    } catch (err) {
      // Anything unsigned is either a misconfiguration or someone trying it on.
      res.status(400).send(`Signature check failed: ${(err as Error).message}`);
      return;
    }

    const db = getFirestore();

    const writeFromSubscription = async (sub: Stripe.Subscription) => {
      const uid = sub.metadata?.uid;
      if (!uid) {
        console.error('subscription with no uid', sub.id);
        return;
      }
      const price = sub.items.data[0]?.price;
      await db.doc(`subscribers/${uid}`).set(
        {
          status: sub.status,
          plan: price?.recurring?.interval === 'month' ? 'monthly' : 'annual',
          currentPeriodEnd: Timestamp.fromMillis(sub.current_period_end * 1000),
          customerId: typeof sub.customer === 'string' ? sub.customer : sub.customer.id,
          subscriptionId: sub.id,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    };

    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        if (session.subscription) {
          const sub = await stripe.subscriptions.retrieve(session.subscription as string);
          // The uid rides on client_reference_id here; copy it onto the
          // subscription so later events can find it without the session.
          const uid = session.client_reference_id;
          if (uid && !sub.metadata?.uid) {
            await stripe.subscriptions.update(sub.id, { metadata: { uid } });
            sub.metadata = { ...sub.metadata, uid };
          }
          await writeFromSubscription(sub);
        }
        break;
      }

      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        await writeFromSubscription(event.data.object as Stripe.Subscription);
        break;

      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice;
        if (invoice.subscription) {
          const sub = await stripe.subscriptions.retrieve(invoice.subscription as string);
          await writeFromSubscription(sub);
        }
        break;
      }

      default:
        break; // Everything else is noise for our purposes.
    }

    res.json({ received: true });
  },
);
```

**Register it.** Deploy first (§6.8), then Stripe → Developers → Webhooks → Add
endpoint:

- URL: `https://us-central1-<project-id>.cloudfunctions.net/stripeWebhook`
- Events: `checkout.session.completed`, `customer.subscription.created`,
  `customer.subscription.updated`, `customer.subscription.deleted`,
  `invoice.payment_failed`

Copy the **signing secret** (`whsec_...`) into the `STRIPE_WEBHOOK_SECRET`
secret from §6.2, then redeploy.

### 6.6 Push registration and sync

```ts
// functions/src/push.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { REGION } from './config';
import { isActive } from './entitlement';

/** The UTC hour that is 9am in the given zone, today. */
function sendHourUtc(tz: string): number {
  const now = new Date();
  const local = new Date(now.toLocaleString('en-US', { timeZone: tz }));
  const offsetHours = Math.round((local.getTime() - now.getTime()) / 3_600_000);
  return (24 + 9 - offsetHours) % 24;
}

export const registerPush = onCall({ region: REGION }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (!(await isActive(req.auth.uid))) {
    // This is the gate. Nothing on the phone can talk its way past it.
    throw new HttpsError('permission-denied', 'Reminders need a subscription.');
  }

  const { token, tz } = req.data ?? {};
  if (typeof token !== 'string' || token.length < 20) {
    throw new HttpsError('invalid-argument', 'No push token.');
  }
  const zone = typeof tz === 'string' ? tz : 'UTC';

  await getFirestore().doc(`reminders/${req.auth.uid}`).set(
    { token, tz: zone, sendHourUtc: sendHourUtc(zone), updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  return { ok: true };
});

/** The dates to watch. Called on launch when they've changed. */
export const syncReminders = onCall({ region: REGION }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  if (!(await isActive(req.auth.uid))) {
    throw new HttpsError('permission-denied', 'Reminders need a subscription.');
  }

  const raw = Array.isArray(req.data?.dates) ? req.data.dates : [];
  const dates = raw
    .filter((d: unknown): d is { at: string; label: string } =>
      !!d && typeof (d as any).at === 'string' && /^\d{4}-\d{2}-\d{2}$/.test((d as any).at))
    .slice(0, 200)                                    // a sane ceiling
    .map((d) => ({ at: d.at, label: String(d.label ?? 'Warranty').slice(0, 40) }));

  await getFirestore().doc(`reminders/${req.auth.uid}`).set(
    { dates, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  return { ok: true, count: dates.length };
});

export const unregisterPush = onCall({ region: REGION }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  await getFirestore().doc(`reminders/${req.auth.uid}`).delete();
  return { ok: true };
});
```

### 6.7 The sender

```ts
// functions/src/send.ts
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { APP_URL, REGION } from './config';
import { isActive } from './entitlement';

const WARN_DAYS = 30;

export const sendReminders = onSchedule(
  { schedule: 'every 1 hours', region: REGION, timeZone: 'UTC' },
  async () => {
    const db = getFirestore();
    const hour = new Date().getUTCHours();

    // Only the people for whom it is currently 9am.
    const due = await db.collection('reminders').where('sendHourUtc', '==', hour).get();

    for (const doc of due.docs) {
      const uid = doc.id;
      const d = doc.data();

      // Re-checked here, not just at registration: subscriptions lapse.
      if (!(await isActive(uid))) continue;

      const today = new Date();
      const limit = new Date(today.getTime() + WARN_DAYS * 86_400_000);

      const soon = (d.dates ?? []).filter((x: { at: string }) => {
        const at = new Date(`${x.at}T00:00:00Z`);
        return at >= today && at <= limit;
      });
      if (soon.length === 0) continue;

      soon.sort((a: any, b: any) => a.at.localeCompare(b.at));
      const first = soon[0];
      const key = `${first.at}|${first.label}`;
      if (d.lastSentKey === key) continue;          // already told them

      const days = Math.round(
        (new Date(`${first.at}T00:00:00Z`).getTime() - today.getTime()) / 86_400_000,
      );

      const title =
        soon.length === 1
          ? `${first.label} cover ends in ${days} days`
          : `${soon.length} warranties end within ${WARN_DAYS} days`;

      try {
        await getMessaging().send({
          token: d.token,
          // Data-only. Our own service worker draws the notification, so no
          // Firebase messaging SDK has to run inside the worker.
          data: { title, body: 'Open Stash it to see what needs doing.', url: APP_URL },
          webpush: { headers: { TTL: '86400', Urgency: 'normal' } },
        });
        await doc.ref.update({ lastSentKey: key, lastSentAt: FieldValue.serverTimestamp() });
      } catch (err: any) {
        // A token dies when the app is uninstalled or permission is revoked.
        if (
          err?.code === 'messaging/registration-token-not-registered' ||
          err?.code === 'messaging/invalid-registration-token'
        ) {
          await doc.ref.delete();
        } else {
          console.error('send failed', uid, err);
        }
      }
    }
  },
);
```

### 6.8 Export and deploy

```ts
// functions/src/index.ts
import { initializeApp } from 'firebase-admin/app';
initializeApp();

export { createCheckout, createPortal } from './billing';
export { stripeWebhook } from './webhook';
export { registerPush, syncReminders, unregisterPush } from './push';
export { grantPro, revokePro } from './admin';        // §11.2
export { sendReminders } from './send';
```

```bash
firebase deploy --only functions
```

First deploy will ask to enable several APIs — say yes. It also creates the
Cloud Scheduler job for `sendReminders`.

---

## 7. Phase 6 — The app

### 7.1 Config

Firebase console → ⚙ → Project settings → Your apps → **Add app** → Web. Copy
the config. None of it is secret — it identifies the project, it doesn't
authorise anything. Your rules do the authorising.

```ts
// src/lib/firebase.ts
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getFunctions } from 'firebase/functions';

/**
 * Loaded lazily, and only by people who are subscribing or subscribed. A free
 * user never downloads any of this — see billing.ts, which dynamic-imports it.
 */
const app = initializeApp({
  apiKey: 'AIza...',
  authDomain: 'stash-it.firebaseapp.com',
  projectId: 'stash-it',
  messagingSenderId: '...',
  appId: '...',
});

export const auth = getAuth(app);
export const db = getFirestore(app);
export const fns = getFunctions(app, 'us-central1');
export { app };
```

```bash
npm install firebase
```

### 7.2 The entitlement, and its cache

```ts
// src/lib/billing.ts

/**
 * What the app believes about the subscription, and how long it's allowed to
 * go on believing it.
 *
 * This is a cache of the server's answer, not the answer. It decides what the
 * UI looks like — whether the Pro rows are live, whether the item cap applies.
 * It cannot make a notification arrive: `registerPush` and `sendReminders`
 * both re-read Firestore, which the client cannot write.
 *
 * Cached with an expiry so a subscriber on a plane still sees Pro, and so a
 * lapsed one doesn't see it forever.
 */
export const ENTITLEMENT_TTL_DAYS = 7;

export interface Entitlement {
  active: boolean;
  plan?: 'annual' | 'monthly';
  periodEnd?: string;
  checkedAt: string;
}

export function entitlementFresh(e: Entitlement | undefined, now = new Date()): boolean {
  if (!e) return false;
  const age = now.getTime() - new Date(e.checkedAt).getTime();
  return age < ENTITLEMENT_TTL_DAYS * 86_400_000;
}

/** True when Pro features should be shown. Stale means "assume not". */
export function proActive(e: Entitlement | undefined, now = new Date()): boolean {
  return !!e?.active && entitlementFresh(e, now);
}
```

Store it in the existing settings record — extend `Entitlements` in
`src/db/types.ts` rather than adding a parallel store:

```ts
export interface Entitlements {
  reportUnlock: boolean;
  proUnlock: boolean;
  source?: 'appstore' | 'playstore' | 'web' | 'stripe';
  verifiedAt?: string;
  /** From Stripe, via the server. Read-only as far as the app is concerned. */
  plan?: 'annual' | 'monthly';
  periodEnd?: string;
}
```

On launch, if signed in: read `subscribers/{uid}` and write the result into
settings. That's the only thing that ever sets `proUnlock` from now on.

### 7.3 Remove the dev toggle

Delete the Pro unlock switch from the Developer card in
`src/screens/Settings.tsx`. Its replacement is `DEV_UIDS` in
`functions/src/config.ts`. A dev bypass in the client is a dev bypass for
everyone, which is exactly the problem you set out to fix.

### 7.4 The Pro card

New card in Settings, above the tip jar:

- **Not signed in:** what Pro is, the two prices with annual first, a sign-in
  button.
- **Signed in, not subscribed:** the two prices as buttons, each calling
  `createCheckout` and following the returned URL.
- **Subscribed:** plan, renewal date, "Manage subscription" (calls
  `createPortal`), and the reminders toggle.

```ts
// calling a function
import { httpsCallable } from 'firebase/functions';
const { fns } = await import('@/lib/firebase');
const checkout = httpsCallable<{ plan: string }, { url: string }>(fns, 'createCheckout');
const { data } = await checkout({ plan: 'annual' });
location.href = data.url;
```

Handle `?checkout=done` on launch: the webhook may not have landed yet, so poll
`subscribers/{uid}` for a few seconds before deciding it failed.

### 7.5 Enforce the cap honestly

`canAddItem` already reads `settings.entitlements`. Nothing changes except
where `proUnlock` comes from. Keep the copy factual — "Free tier holds 15
items" — and don't imply a security property the cap doesn't have.

---

## 8. Phase 7 — Push

### 8.1 Web push certificate

Firebase console → Project settings → **Cloud Messaging** → Web configuration →
**Generate key pair**. Copy the VAPID public key.

### 8.2 Service worker

You have one worker and one scope, and it's already carrying the share handler.
Add a second script the same way rather than registering anything new.

```js
// public/push-handler.js
//
// Draws notifications from data-only FCM messages. Deliberately not the
// Firebase messaging SDK: this is twenty lines, it has no CDN dependency, and
// nothing else needs to run inside the worker.

self.addEventListener('push', (event) => {
  let payload = {};
  try {
    payload = event.data?.json()?.data ?? {};
  } catch {
    // A malformed push is still a push; show something rather than nothing,
    // because the browser will show its own placeholder if we don't.
  }

  event.waitUntil(
    self.registration.showNotification(payload.title || 'Stash it', {
      body: payload.body || 'Something needs a minute.',
      icon: '/app/icon-192.png',
      badge: '/app/icon-192.png',
      tag: 'stashit-reminder',
      data: { url: payload.url || '/app/' },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = event.notification.data?.url || '/app/';

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      // Focus the app if it's already open rather than stacking another copy.
      for (const client of list) {
        if (client.url.includes('/app/') && 'focus' in client) return client.focus();
      }
      return self.clients.openWindow(url);
    }),
  );
});
```

```ts
// vite.config.ts
workbox: {
  importScripts: ['share-handler.js', 'push-handler.js'],
  // ...
}
```

### 8.3 Turning it on

```ts
// src/lib/push.ts
import { httpsCallable } from 'firebase/functions';

const VAPID_KEY = 'BPaste_your_public_key_here';

export async function enablePush(): Promise<'on' | 'denied' | 'unsupported'> {
  if (!('Notification' in window) || !('serviceWorker' in navigator)) return 'unsupported';

  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return 'denied';

  const { getMessaging, getToken } = await import('firebase/messaging');
  const { app, fns } = await import('@/lib/firebase');

  // Our own worker, not a second one.
  const registration = await navigator.serviceWorker.ready;
  const token = await getToken(getMessaging(app), {
    vapidKey: VAPID_KEY,
    serviceWorkerRegistration: registration,
  });

  await httpsCallable(fns, 'registerPush')({
    token,
    tz: Intl.DateTimeFormat().resolvedOptions().timeZone,
  });

  return 'on';
}
```

**Ask at the right moment.** Request notification permission when they tap the
toggle, never on launch. A permission prompt nobody asked for is denied, and a
denial is close to permanent.

### 8.4 Syncing the dates

On launch, when signed in and subscribed, build the list from the data you
already have and send it if it differs from last time:

```ts
import { coverageSchedule } from '@/lib/warranty';

const dates = items
  .flatMap((item) =>
    coverageSchedule(item)
      .filter((d) => d.end && d.daysLeft !== null && d.daysLeft >= 0)
      .map((d) => ({ at: toISODate(d.end!), label: coverageLabel(d.coverage) })),
  )
  .sort((a, b) => a.at.localeCompare(b.at))
  .slice(0, 200);
```

Hash it, compare to the last hash in localStorage, and only call
`syncReminders` when it changed. Most launches will send nothing.

**The limitation to state plainly in the UI:** reminders are based on what the
app last sent. Someone who never opens Stash it again gets reminders from their
last visit's data. Say so under the toggle — "Reminders use what Stash it knew
when you last opened it" — rather than letting someone discover it.

### 8.5 iOS

Web push on iOS works only for a PWA installed to the home screen, 16.4 or
later. In Safari there's nothing to offer. Detect it and say so rather than
showing a toggle that can't work.

---

## 9. Testing

### Locally

```bash
# terminal 1
cd functions && npm run build && firebase emulators:start --only functions,firestore

# terminal 2 — forwards real Stripe test events to your local webhook
stripe listen --forward-to http://localhost:5001/<project-id>/us-central1/stripeWebhook
# copy the whsec_... it prints into your local .secret.local

# terminal 3
npm run dev
```

### Cards worth trying

| Card | What it does |
|---|---|
| `4242 4242 4242 4242` | Succeeds |
| `4000 0000 0000 0341` | Attaches, then fails on charge — exercises `payment_failed` |
| `4000 0000 0000 9995` | Declined, insufficient funds |
| `4000 0025 0000 3155` | Requires 3D Secure authentication |

Any future expiry, any CVC, any postcode.

### The list to actually walk

- [ ] Sign in, subscribe annual, `subscribers/{uid}` appears with `active`
- [ ] Pro UI turns on; item cap lifts
- [ ] Turn on reminders → permission prompt → `reminders/{uid}` gets a token
- [ ] **Sign in as a second user who hasn't paid, call `registerPush` from the
      console, confirm `permission-denied`** — this is the test that matters
- [ ] Set `proUnlock: true` by hand in devtools → cap lifts (expected), but
      `registerPush` still refuses (the point)
- [ ] Cancel in the portal → status flips → next hourly run sends nothing
- [ ] `stripe trigger invoice.payment_failed` → status updates
- [ ] Force a send by setting `sendHourUtc` to the current UTC hour and a date
      inside the window; check the notification arrives, and tapping it opens
      the app rather than a second copy
- [ ] Uninstall the PWA, run the sender, confirm the dead token is deleted
- [ ] Both a phone and a desktop browser; both sign-in halves if using email link
- [ ] The comp paths in §11.5

---

## 10. The privacy consequences, and the copy that has to change

Once a subscriber turns reminders on, this leaves their device: **their email,
a push token, their timezone, and a list of dates with policy labels.** No item
names, no photos, no prices, no rooms. Free users send nothing, ever.

That is still a change to what the site currently promises. These need editing
before launch:

| Where | Current | Problem |
|---|---|---|
| `site/index.html` meta description | "No account, no cloud, no tracking." | Subscribers have an account |
| `site/index.html` tick list | "No tracking" | Fine as-is — you still don't track |
| `site/index.html` feature | "No analytics, no tracking" | Fine — keep it true by not adding analytics |
| `site/index.html` FAQ | "no account system and no analytics, so no data about you or your possessions reaches anyone. The only network requests it makes are ones you start" | Needs the reminder exception |
| `src/screens/Settings.tsx` | "Everything below changes how Stash it behaves. Nothing here leaves the device." | Needs "unless you turn on reminders" |

Suggested FAQ replacement:

> Stash it is free and works with no account at all — nothing about you or your
> possessions is sent anywhere. If you subscribe to reminders, three things
> leave your phone: your email address, a notification token, and the dates
> your warranties end. Not what the items are, not what you paid, not the
> photos. You can cancel and delete all of it in one tap.

**The one decision left open.** The notification currently reads "Fabric cover
ends in 30 days" because labels are all the server holds. Including item names
would let it say "Sectional couch — fabric cover ends in 30 days", which is a
better notification and a worse privacy story. I'd ship without names and see
whether anyone asks.

---

## 11. Free Pro — yourself, beta testers, and anyone you owe a favour

Three mechanisms, because they solve genuinely different problems. Use the
right one and you'll never be tempted to reach for the client-side toggle
again.

| | Who it's for | Touches Stripe | Expires | Effort per person |
|---|---|---|---|---|
| `DEV_UIDS` | You, and only you | No | No | A redeploy |
| **Grants** | Beta testers, friends, apologies | No | Yes | One Firestore doc |
| **100% promo code** | Beta cohorts you want on the real path | Yes | Yes | One code, many people |

### 11.1 Grants — the one you'll use most

A `grants` collection, keyed by **email address** rather than uid. That matters:
you know someone's email before they've ever opened the app, and you'd have to
ask them to read a uid off a screen otherwise.

```
grants/{email}                       // lowercased, e.g. "sam@example.com"
  reason        'Beta tester'
  expiresAt     timestamp | null     // null = forever, for your own account
  grantedAt     timestamp
  grantedBy     'hello@stash-it.app'
  note          'Found the drag-reorder bug'
```

**Rules** — add to the block from §4.4:

```js
    // A grant is looked up by the email on the sign-in token, so someone can
    // see their own and nobody else's. Only you write these, by hand.
    match /grants/{email} {
      allow read: if request.auth != null
                  && request.auth.token.email_verified == true
                  && request.auth.token.email.lower() == email;
      allow write: if false;
    }
```

**Entitlement** — `isActive` gains a middle step. Replace §6.3's version with:

```ts
// functions/src/entitlement.ts
import { getFirestore } from 'firebase-admin/firestore';
import { DEV_UIDS } from './config';

export type Reason = 'dev' | 'grant' | 'stripe' | null;

/**
 * Whether this account gets Pro, and why.
 *
 * The reason is returned as well as the answer because the app says it out
 * loud: someone on a free grant should see "Pro, on the house" rather than a
 * renewal date that doesn't exist. A comp presented as a purchase is a support
 * email waiting to happen.
 */
export async function entitlementFor(
  uid: string,
  email?: string,
): Promise<{ active: boolean; reason: Reason; until?: Date }> {
  if (DEV_UIDS.has(uid)) return { active: true, reason: 'dev' };

  const db = getFirestore();

  // Grants come before Stripe: a tester who later subscribes properly should
  // still be covered on the day their grant lapses.
  if (email) {
    const grant = await db.doc(`grants/${email.toLowerCase()}`).get();
    if (grant.exists) {
      const until = grant.data()?.expiresAt?.toDate?.() as Date | undefined;
      if (!until || until.getTime() > Date.now()) {
        return { active: true, reason: 'grant', until };
      }
    }
  }

  const snap = await db.doc(`subscribers/${uid}`).get();
  if (!snap.exists) return { active: false, reason: null };

  const d = snap.data()!;
  if (d.status !== 'active' && d.status !== 'trialing') return { active: false, reason: null };

  const end = d.currentPeriodEnd?.toMillis?.() ?? 0;
  if (end <= Date.now() - 3 * 24 * 60 * 60 * 1000) return { active: false, reason: null };

  return { active: true, reason: 'stripe', until: new Date(end) };
}

/** The yes/no, for the two places that only need that. */
export async function isActive(uid: string, email?: string): Promise<boolean> {
  return (await entitlementFor(uid, email)).active;
}
```

Every caller passes the email off the auth token:

```ts
// in registerPush and syncReminders
if (!(await isActive(req.auth.uid, req.auth.token.email))) {
  throw new HttpsError('permission-denied', 'Reminders need a subscription.');
}
```

The scheduled sender doesn't have an auth token, so store the email on the
reminders document when registering, and pass that:

```ts
// registerPush, alongside token and tz
email: req.auth.token.email ?? null,

// sendReminders
if (!(await isActive(uid, d.email))) continue;
```

**Issuing one** — Firestore console → `grants` → Add document. Document ID is
the lowercased email. Add `reason` (string), `expiresAt` (timestamp, or leave
it out for permanent), `grantedAt`, `note`. Thirty seconds.

**Revoking one** — delete the document. Takes effect on their next launch for
the UI, and on the next hourly run for sends. No redeploy, no app update.

**Give beta grants an expiry.** Six months is generous. Without one you'll be
paying to send notifications to people who stopped testing in 2027 and you'll
never notice, because nothing will ever tell you.

### 11.2 A callable, if you'd rather not open the console

Optional, but pleasant — it lets you comp someone from your phone while
you're replying to their bug report.

```ts
// functions/src/admin.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { DEV_UIDS, REGION } from './config';

export const grantPro = onCall({ region: REGION }, async (req) => {
  // The only authorisation that exists here. DEV_UIDS is in the deployed
  // config, so this cannot be reached by editing anything on a phone.
  if (!req.auth || !DEV_UIDS.has(req.auth.uid)) {
    throw new HttpsError('permission-denied', 'Not you.');
  }

  const email = String(req.data?.email ?? '').trim().toLowerCase();
  if (!email.includes('@')) throw new HttpsError('invalid-argument', 'Need an email.');

  const months = Number(req.data?.months ?? 6);
  const forever = months <= 0;

  await getFirestore().doc(`grants/${email}`).set({
    reason: String(req.data?.reason ?? 'Beta tester').slice(0, 80),
    note: String(req.data?.note ?? '').slice(0, 200),
    expiresAt: forever
      ? null
      : Timestamp.fromMillis(Date.now() + months * 30 * 86_400_000),
    grantedAt: FieldValue.serverTimestamp(),
    grantedBy: req.auth.token.email ?? req.auth.uid,
  });

  return { ok: true, email, months: forever ? 'forever' : months };
});

export const revokePro = onCall({ region: REGION }, async (req) => {
  if (!req.auth || !DEV_UIDS.has(req.auth.uid)) {
    throw new HttpsError('permission-denied', 'Not you.');
  }
  const email = String(req.data?.email ?? '').trim().toLowerCase();
  await getFirestore().doc(`grants/${email}`).delete();
  return { ok: true };
});
```

Expose it as two fields and a button in the Developer card — which is now
allowed to exist again, because pressing it does nothing unless the *server*
recognises you.

### 11.3 100% promo codes — for a beta cohort

When you want testers to walk the real purchase path, bugs and all, a Stripe
coupon is better than a grant: it exercises Checkout, the webhook and the
portal exactly as a paying customer would.

Stripe → Products → **Coupons** → New:

- Percentage discount, **100%**
- Duration: **Repeating**, 12 months (or Forever, if you mean it)
- Optionally limit to your two prices

Then **Promotion codes** → Create, on that coupon:

- Code: `BETA2026` — readable, since you'll be typing it into messages
- Max redemptions: however many testers you have, plus a couple
- Expires: a date you'll actually reach

Your checkout already passes `allow_promotion_codes: true`, so the field
appears in Checkout with no code change. One addition worth making:

```ts
// billing.ts, in the session create call
payment_method_collection: 'if_required',
```

Without it, Stripe asks for a card even when the total is $0, which is a
strange thing to ask of someone doing you a favour. With it, a fully discounted
subscription completes with no card at all — and when the coupon runs out
twelve months later, Stripe will ask for one before charging.

**The trade to know about:** at the end of the coupon, that subscription
becomes a real $10 charge unless they cancel. Say so when you hand out the
code. A grant, by contrast, simply stops.

### 11.4 What the app should say

Never show a comped account a renewal date or a price. The Pro card reads from
the `reason`:

| Reason | Card says |
|---|---|
| `stripe` | "Pro — annual, renews 12 March 2027" + Manage subscription |
| `grant` | "Pro, on the house — thanks for testing" + expiry if there is one |
| `dev` | "Pro — developer build" |

Expose the reason by having the app read its own `subscribers/{uid}` and
`grants/{email}` documents — both are readable by their owner under the rules
above — or return it from a tiny `whoAmI` callable if you'd rather have one
round trip than two reads.

### 11.5 Testing the comp paths

- [ ] Add a grant for a second Google account, sign in as it, confirm Pro turns
      on with the "on the house" copy and no renewal date
- [ ] `registerPush` succeeds for that account with no Stripe record at all
- [ ] Set `expiresAt` to yesterday → next launch loses Pro, next hourly run
      sends nothing
- [ ] Delete the grant → same
- [ ] Redeem `BETA2026` in Checkout → `subscribers/{uid}` shows `active` with
      no card collected
- [ ] Call `grantPro` as a non-dev account → `permission-denied`

---

## 12. Going live

1. Stripe: flip out of test mode, recreate the two prices, copy the **live**
   price IDs into `config.ts`.
2. Complete Stripe account activation — bank details, identity verification.
3. Create the **live** webhook endpoint, copy its signing secret, update the
   secret, redeploy.
4. Set the live secret key.
5. Re-check statement descriptor, portal config and renewal emails in live mode
   — they're configured separately from test.
6. Publish `terms.html` and `privacy.html`, link them from the app and the
   footer, both on `stash-it.app`.
7. Confirm the domain: HTTPS enforced, `www` resolves, the old github.io URL
   redirects, and the installed app's start URL is the new origin.
8. Buy your own subscription with a real card. Then cancel it and check the
   whole path works.
9. Confirm the budget alert is live.

## 13. Running it

**A dispute arrives.** Respond within the window with the receipt and the
access logs, but expect to lose most of them. Cheaper to refund on request
before it becomes a dispute — a refund costs you the fees, a dispute costs
about $15.

**Someone asks for their data deleted.** Delete `subscribers/{uid}` and
`reminders/{uid}`, delete the Firebase Auth user, and cancel the Stripe
subscription. Worth writing as a small callable so it's one action rather than
four console visits you'll get wrong at 11pm.

**Watch monthly:** Stripe dispute rate (keep it under 0.75%), failed payment
count, Firebase spend against the $5 alert, and the Cloud Functions error log.

**When you change the price:** never edit an existing price object — create a
new one and update the lookup key. Existing subscribers keep the price they
signed up at, which is the correct and kind behaviour.

---

## Appendix — build order

Each of these is independently shippable. Don't start the next until the
previous one works end to end.

1. **The domain** — buy it, DNS, CNAME, base paths, email forwarding — §2
   *(an hour, plus DNS propagation)*. Everything downstream hard-codes URLs,
   and moving later orphans every user's data.
2. Stripe products, portal, emails, descriptor — §3 *(an hour, no code)*
3. Firebase project, Blaze, budget, Firestore, rules — §4 *(half an hour)*
4. Sign-in, one option — §5 *(an evening)*
5. Checkout, portal, webhook, `subscribers` — §6.1–6.5 *(a day)*
6. Grants, so you can comp yourself and testers — §11.1 *(twenty minutes,
   and worth doing before the Pro card so you have something to test it with)*
7. App: entitlement cache, Pro card, cap gating, dev toggle removed — §7
8. **Ship it here.** Subscriptions work and the cap is paid. Sell it before you
   build the expensive half.
9. Push: certificate, worker, registration, sync — §8
10. The sender — §6.7
11. Copy changes and the privacy page — §10
