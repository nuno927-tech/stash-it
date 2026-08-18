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
