# Putting Stash it in the Play Store

Packaged with [PWABuilder](https://www.pwabuilder.com), which wraps the site in
a Trusted Web Activity — a real Android app whose whole content is this PWA,
running in Chrome without any Chrome around it.

---

## Do this first, and it is not a detail

**Ship on the final domain.** A PWA's data belongs to its origin. Launch on
`nuno927-tech.github.io` and later move to `stash-it.app` and every user's
items, documents and subscriptions stay behind on the old origin — with no
server, there is nothing to migrate them from and nobody to ask. You would be
telling people to restore from a backup they probably never made.

Buy the domain, point Pages at it, confirm the app works there, and only then
package anything.

---

## The order, and what blocks what

The only item measured in weeks is the closed test, and it cannot start until
there is a package to upload — so everything above it is on the critical path
and everything below it runs in parallel with the clock.

```
1  domain                     ── blocks everything
2  move the app to it         ── blocks the package (asset links are per origin)
3  screenshots                ── needs the app deployed at its final address
4  decide the v1 price story  ── blocks the listing, not the package
5  Play account, $25          ── can be done any time before 6
6  package with PWABuilder    ── produces the signing key AND assetlinks.json
7  host assetlinks, verify    ── needs 6; without it the address bar stays
8  upload to closed testing   ── STARTS THE 14-DAY CLOCK
9  listing assets + forms     ── do these while the clock runs
10 apply for production       ── 14 days after 8, at the earliest
```

---

## Moving to the domain

Three files, and one of them is not obvious.

**`site/CNAME`** — a new file containing nothing but `stash-it.app`. GitHub
Pages reads it from the published artifact, and the deploy workflow assembles
that from `site/`, so it has to live there rather than in the repository root.
Without it Pages forgets the custom domain on the next deploy.

**`.github/workflows/deploy.yml`** — `BASE_PATH` and `SITE_PATH` currently
derive from the repository name, which is right for a project site and wrong
for a domain:

```yaml
BASE_PATH: /app/
SITE_PATH: /
```

**`functions/.env`** — add the new origin to `ALLOWED_ORIGINS`, comma
separated, and `firebase deploy --only functions`. Miss this and reminders
fail at the CORS check from the new address with no visible error, because a
failed sync is deliberately silent.

Keep the old origin on that list for as long as anyone might still have the
app installed from it.

**What does not change:** the VAPID key, the `PUSH_ENDPOINT`, and both GitHub
repository variables. The sender is addressed by its own URL and does not care
where the app is served from, only who is allowed to call it.

**What quietly does:** the manifest `id`, which is derived from `BASE_PATH`.
Nothing installed from the old address will recognise the new one as the same
app. That is the same origin problem as the data, stated a second way, and the
same answer: move before anyone is using it.

---

## Screenshots

Drop PNGs into `public/screenshots` and they appear in the manifest
automatically, in filename order, at their real dimensions — see
`screenshots()` in `vite.config.ts`. Filenames become labels:
`02-coming-up.png` shows as "Coming up".

They must be the **actual app**. Play rejects listings whose screenshots
aren't, and Chrome shows them to someone deciding whether to install.

**Capturing them**

```bash
npm run build && npm run preview
```

Then, in Chrome:

1. `F12` → the device toolbar (`Ctrl+Shift+M`).
2. Pick a device, or set a custom size. **1080 × 2340** matches a common
   Android phone and is comfortably inside Play's limits.
3. Set the zoom to 100% and the DPR to 1, or the file comes out at three times
   the size you asked for.
4. Three-dot menu in the device toolbar → **Capture screenshot**.

Turn the dev seed on first so the screens have something in them — an empty
dashboard is a truthful screenshot of nothing.

**Four is enough.** The dashboard, the items list, a document with a date
running out, and the subscriptions curve. Each one should show a different
thing the app does; four views of a list is one screenshot repeated.

Play also wants, separately from the manifest, at least two phone screenshots
uploaded to the listing, a **1024 × 500** feature graphic, and a **512 × 512**
icon.

---

## Before packaging

| | Why |
|---|---|
| **`.well-known/assetlinks.json` at the origin root** | Without it the app opens with Chrome's address bar across the top. PWABuilder generates the file; it has to sit at `https://<your-domain>/.well-known/assetlinks.json` — the **origin** root, not the app's subpath. |
| **Privacy policy URL** | `site/privacy.html`. Play requires one in the listing, and reminders make the Data Safety form a real declaration rather than a formality. |
| **Notifications enabled in the package** | PWABuilder has a toggle for it. Off by default, and off means the reminders silently never arrive in the store build — the hardest kind of bug to notice. Android 13+ also asks the user at runtime. |
| **A Play developer account** | $25, once. |

## The price story, which has to be settled before the listing

The site sells a Pro tier: twenty-five records free, unlimited plus
notifications for $10 a year. The app implements neither half — notifications
are free to everyone and there is no way to pay for anything.

That is fine for a website and not fine for a store listing, and there is a
second constraint on top of it: **Play policy requires Google Play Billing for
digital goods sold inside an app it distributes.** In a Trusted Web Activity
that means the Digital Goods API and the Payment Request API, not a Stripe
checkout — so the web version and the Play version would need different
purchase paths and a shared idea of who has Pro.

Two honest ways forward:

**Ship v1 free.** Everything on, cap at twenty-five, no Pro anywhere. Amend
the site's pricing section to match. Adds nothing to the critical path and
gets the closed test started weeks earlier. Pro can arrive in v2 with Play
Billing behind it, which is also when the entitlement question has to be
answered properly rather than guessed at.

**Build billing first.** Correct, and it is the longest thing on this list by
a distance — a purchase flow, an entitlement check, a restore path, and a
second implementation for the web. Nothing else in this document is blocked by
it, so it can only delay the launch.

The first is recommended. A free app that works beats a paid tier nobody can
buy, and the closed-test clock is fourteen days you cannot get back.

## The long pole

Personal developer accounts created after **13 November 2023** must run a
closed test with **at least 12 testers, opted in continuously for 14 days**,
before applying for production access. Consecutively — someone who drops out
and rejoins restarts their own clock. Organisation accounts registered to a
legal business entity are exempt.

Start recruiting before everything else is ready. It is the only item here
measured in weeks.

## After the first install

Three things worth checking on a real phone, because each one is a feature
built deliberately and each one can break in the wrapper alone:

- **No address bar.** If there is one, asset links did not verify — usually
  because they are at the app's subpath instead of the origin root, or behind
  a redirect.
- **Reminders.** Settings → tap the version pill ten times → the bench.
  Button 3 sends a real push. Do it with the app closed.
- **The share target.** Share a receipt to Stash it from your mail app.
