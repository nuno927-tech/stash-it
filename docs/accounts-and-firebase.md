# Should Stash it have Google accounts?

An assessment of adding Google sign-in and a Firebase backend, at scale.
Prices checked August 2026, US regions, Blaze plan. They change; the shape of
the answer doesn't.

## The short version

**Firebase will not cost you money at any scale you are likely to reach.** A
hundred thousand users costs roughly **$350 a month** — under half a cent per
user — and most of that is photo storage. Ten thousand users costs about **$5**.

So the decision isn't financial. It's about three other things: the privacy
claim the app currently makes and would have to stop making, the legal position
you'd be taking on, and the fact that a backend is a thing that can be down at
3am. Decide on those, then treat the bill as a rounding error.

---

## What accounts actually buy

Ranked by how much they'd change the product, not by how impressive they sound.

**1. Sync across devices, and survival of a lost phone.**
This is the whole case. Today, everything lives in one browser's IndexedDB. If
that phone goes in a river and no backup was exported, the data is gone —
permanently, with no recourse. Every other benefit is secondary to this one.

*But note:* Drive backup already solves the survival half of it. What accounts
add over Drive is that it happens without anyone remembering to press a button,
and that a second device sees the same data.

**2. iPhone parity.**
iOS has no share targets, so the "share a receipt from Gmail" flow doesn't exist
there. It also evicts IndexedDB from sites unused for seven days, which makes an
uninstalled iOS PWA an actively unsafe place to keep the only copy of anything.
An account with server-side data makes the iPhone experience honest.

**3. A real paid tier.**
`entitlements.proUnlock` is currently a boolean in local storage that anyone can
flip by opening devtools. There is no way to validate a purchase without a
server. If Stash it is ever to charge for anything, this is the prerequisite.

**4. Warranty expiry notifications that arrive when the app is closed.**
The nudges only exist while the app is open. Real push needs a server holding
the expiry dates and a scheduled job. This is arguably the app's most valuable
unbuilt feature — a warranty warning you don't see is worth nothing.

**5. Households.**
Two people, one inventory. Needs identity to be worth anything.

**6. Knowing anything at all about usage.**
Right now you cannot tell whether ten people or ten thousand use this.

---

## What it costs in money

### Assumptions

| | |
| --- | --- |
| Per active user | 40 items, ~20 MB of photos and documents |
| Firestore records | ~80 per user, ~1 KB each |
| Reads | 300/user/month *with* offline persistence enabled |
| Writes | 60/user/month |
| Egress | 10% of stored blobs re-downloaded per month |

Free tiers applied: Auth 50k MAU · Firestore 50k reads + 20k writes/day, 1 GB
· Cloud Storage 5 GB and 100 GB egress.

### The bill

| Users | Auth | Firestore | Photo storage | Egress | **Total/mo** | Per user | Data held |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | $0 | $0 | $0 | $0 | **$0** | — | 0.2 GB |
| 100 | $0 | $0 | $0 | $0 | **$0** | — | 2 GB |
| 1,000 | $0 | $0 | $0 | $0 | **$0** | $0.000 | 20 GB |
| 10,000 | $0 | $1 | $4 | $0 | **$5** | $0.000 | 195 GB |
| 100,000 | $275 | $29 | $39 | $11 | **$354** | $0.004 | 1.9 TB |
| 1,000,000 | $4,415 | $306 | $391 | $222 | **$5,333** | $0.005 | 19 TB |

Two things fall out of this:

- **Up to about 10,000 users you are inside the free tier**, give or take a
  few dollars. The Spark plan's daily Firestore quotas and Cloud Storage's
  always-free 5 GB do most of the work.
- **Past 50,000, Auth becomes your largest line item.** Not storage, not
  reads — the per-MAU charge for the privilege of knowing who someone is. At a
  million users it's 83% of the bill. If you ever get near that, moving auth
  off Firebase is the single highest-value migration available.

### Heavier users

If the average user hoards — 100 MB rather than 20 MB:

| Users | Total/mo |
| ---: | ---: |
| 1,000 | $2 |
| 10,000 | $20 |
| 100,000 | $604 |

Storage is cheap enough that this barely moves. Don't optimise for it.

---

## Where the bill actually breaks

The table above is the well-behaved case. Firebase bill shock is real, and it
comes from four places — none of which are on that table.

**1. Reads, if you skip offline persistence.**
The model assumes 300 reads per user per month. A naive implementation — a
listener re-reading the whole collection on every app open — is closer to
2,400, which is 8× the read cost. At a million users that's the difference
between $306 and $1,439 a month in reads alone. Enable persistence, query by
`updatedAt`, and never attach an unbounded listener.

**2. One bad query, shipped.**
The canonical Firebase horror story is a `onSnapshot` on a collection without a
`limit()`, deployed on a Friday. Set a **budget alert at $50** before you write
a line of Firestore code. It costs nothing and it's the only thing standing
between you and a four-figure surprise.

**3. Abuse.**
An open storage bucket with no per-user quota is free hosting for whatever
anyone wants to upload. Storage rules must pin writes to the authenticated
user's own path, cap file size, and restrict content types.

**4. Cloud Functions, once you add them.**
Push notifications mean a scheduled function scanning for expiries. That's
where the cost curve actually starts bending, and where the operational
complexity lives. Budget for it separately from the numbers above.

---

## What it costs in everything else

This is the real bill, and none of it is on a pricing page.

**The privacy claim goes away.** The app currently says "everything you add
stays on this device" and means it. That's in the install prompt, the Settings
copy, and the lock screen. It's also a genuine differentiator — every
competitor is a cloud service. The moment there's a Firestore, that sentence
becomes false and every place it appears has to be rewritten. You cannot
half-keep it.

**You become the custodian of an unusually sensitive dataset.** Not email
addresses — a structured, searchable list of the valuable objects inside
people's homes, with photos, purchase prices and the addresses on their
receipts. That is close to a burglary shopping list, and holding it makes you a
target in a way that a warranty-tracking app has no business being. Today a
breach of Stash it is impossible because there is nothing to breach.

**You take on data-protection duties.** GDPR data controller: deletion
requests, export requests, a privacy policy that's accurate, a processor
agreement with Google, breach notification obligations. Achievable — it's a
weekend of reading, not a legal department — but it's permanent and it's
unpaid.

**You inherit an on-call rotation of one.** Local-first has no outages. The
moment sync exists, "the app is broken" becomes possible while you're asleep.

**Account recovery becomes a support queue.** "I signed up with the wrong
Google account and my stuff is gone" is now your problem, forever.

**Sync is genuinely hard.** Two devices editing offline is the hardest problem
in this entire codebase, and the existing backup merge — last-write-wins on
`updatedAt` — is a much blunter instrument than it looks when it's running
continuously instead of once a month. Budget weeks, not a weekend.

---

## Three ways to go

### A. Stay local-first. Drive for backup. (What you have)

**Cost: $0 forever**, because the data sits in each user's own Drive quota
rather than yours. No liability, no DSARs, no outages. The privacy line stays
true.

Doesn't fix: iPhone, multi-device, push, paid tiers, or the user who never
presses the backup button.

### B. Accounts for identity, Drive for data

Google sign-in, and a tiny Firestore holding only preferences, entitlements and
a pointer to the user's own Drive folder. Photos and documents never touch your
infrastructure.

**Cost: effectively $0 up to ~50,000 users**, then $0.0055/MAU for auth alone —
about $275/month at 100k, and no storage or egress at all.

Buys you: paid tiers that can't be flipped in devtools, usage numbers, and a
recovery story. Keeps: "your documents never leave your devices", which is
still very nearly the original claim.

Doesn't buy: push notifications, or sync that works without a Google account.

### C. Full Firebase backend

Everything above, plus real sync, push, and households.

**Cost: $0 to 10k users, ~$350/mo at 100k**, and every non-financial cost in
the previous section, in full.

---

## What I'd do

**B, and not yet.**

The financial argument for a backend is a non-argument — it's free at the scale
this app is at, and cheap at any scale it plausibly reaches. But that cuts both
ways: since money isn't the constraint, there's no cost pressure forcing the
decision, and the non-financial costs are all permanent and one-directional.
You can add accounts later. You cannot un-hold someone's data.

The specific triggers I'd wait for:

1. **You want to charge for it.** Then B is mandatory — the local `proUnlock`
   boolean is not a business model.
2. **Real iPhone users.** iOS makes local-first genuinely unsafe, and that's an
   honesty problem more than a feature gap.
3. **Someone loses their data.** One report of that from a real user outweighs
   every argument above.

Until one of those lands, the highest-value thing that doesn't require any of
this is **push notifications for expiring warranties** — and it's worth noting
those need a server, which makes it the first thing that will actually force
this decision.

If you do go: enable offline persistence on day one, set a $50 budget alert
before writing any Firestore code, and keep blobs in Cloud Storage rather than
Firestore — a 400 KB receipt as a Firestore document is 400 KB at $0.26/GB
instead of $0.02/GB, and it will hit the 1 MB document limit eventually.

---

## Sources

- [Firebase pricing](https://firebase.google.com/pricing)
- [Identity Platform pricing](https://cloud.google.com/identity-platform/pricing)
- [Cloud Storage pricing](https://cloud.google.com/storage/pricing)
- [Google Cloud network pricing](https://cloud.google.com/vpc/network-pricing)
- [Where the Blaze bill breaks](https://www.sashido.io/en/blog/firebase-guide-and-pricing-traps-2026)
- [Firebase Authentication pricing explained](https://blog.logto.io/firebase-authentication-pricing)
