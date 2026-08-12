# Backing up to Google Drive

Stash it can upload its backup bundle to a **Stash it** folder in your Google
Drive, and restore from it. This takes one setup job of about five minutes,
once, because there is no server behind the app.

## Why you have to do this bit

Stash it is static files on GitHub Pages. There's nowhere to keep a client
secret, so it uses Google's browser token flow: a **public** client ID that is
locked to an origin. Google won't issue tokens to any other site using it, so
publishing it costs nothing — but it has to be created under a Google Cloud
project, and only the person deploying the app can do that.

The scope requested is `drive.file`. That grants access **only to files this
app created**, which is why it needs no verification and no security
assessment: Stash it cannot see anything else in your Drive, and that's
enforced by Google rather than promised by the code.

## Setup

1. Go to [console.cloud.google.com](https://console.cloud.google.com) and
   create a project. The name is only ever seen by you.

2. **APIs and services → Library → Google Drive API → Enable.**
   Skipping this is the most common mistake; the app will tell you if you have,
   because Google's error for it is specific.

3. **APIs and services → OAuth consent screen.** Pick **External**, fill in an
   app name and your own email. You do not need to submit anything for
   verification — `drive.file` is a non-sensitive scope. Add your own Google
   account under **Test users** if the project stays in Testing mode.

4. **Credentials → Create credentials → OAuth client ID → Web application.**
   Under **Authorised JavaScript origins**, add the origin the app is served
   from, exactly, with no trailing slash:

   ```
   https://nuno927-tech.github.io
   ```

   Add `http://localhost:5173` too if you want it working in `npm run dev`.

   Leave **Authorised redirect URIs** empty. The token flow doesn't use one.

5. Copy the client ID — it ends in `.apps.googleusercontent.com` — and paste it
   into **Settings → Google Drive** in the app.

Then press **Back up to Drive**. The first press opens Google's consent screen;
after that, renewals are silent until you revoke access.

## What gets uploaded

The same `.stashit` bundle the Export button produces: every item, document,
photo and setting, as one zip, with a checksum. The Drive copy is not
encrypted beyond Google's own at-rest encryption — anyone with your Google
account can open it, which is the trade you're making by putting it there.

Two things never travel in a bundle, whichever direction it moves:

- **Entitlements.** A restored file can't grant a paid unlock.
- **The biometric lock and its credential.** They're specific to one device's
  keychain, and restoring them onto a new phone would raise a lock nothing on
  that phone could satisfy.

The client ID *does* travel, deliberately — it isn't a secret, and carrying it
means a restore onto a new phone already knows where its backups live.

## Housekeeping

Drive keeps every upload as a separate file even when the name repeats, so the
app shows you the ten most recent and tells you how many older ones are still
there. It never deletes anything on its own: pruning is listed, not performed,
because a backup you didn't ask to lose is exactly the thing this feature
exists to prevent.

## If something goes wrong

| What you see | What it usually means |
| --- | --- |
| "The Drive API is not enabled…" | Step 2 was skipped. |
| "Google rejected the sign-in" | The token expired and the silent renewal failed. Press the button again. |
| "The sign-in window was blocked" | Pop-ups are blocked for the site. |
| `redirect_uri_mismatch` or `origin mismatch` | The origin in step 4 doesn't match exactly — check `https` and the missing trailing slash. |
| Nothing happens, no error | Check the browser console; an extension blocking `accounts.google.com` will do this silently. |

## Revoking

**Disconnect** in Settings forgets the client ID on this device and drops the
token. It does not delete anything already in Drive. To withdraw the grant
itself, use
[myaccount.google.com/permissions](https://myaccount.google.com/permissions).
