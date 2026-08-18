# Store screenshots

Drop PNGs in here and they appear in the manifest automatically, in filename
order, at their real dimensions. See `screenshots()` in `vite.config.ts`.

    01-what-you-own.png   →   label "What you own"
    02-coming-up.png      →   label "Coming up"

Portrait files are tagged `narrow` (phone), landscape `wide` (tablet).

**They have to be the actual app.** Play rejects listings whose screenshots
aren't, and Chrome's install sheet shows them to someone deciding whether to
trust the thing. Capture them from a built copy — `docs/store.md` has the
steps and the sizes Play wants.

This folder is committed with only this file in it, so the path exists and the
manifest key stays absent until there is something real to put in it.
