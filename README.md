# Stash it

Warranties, receipts and manuals for everything you own. Local-first PWA.

## Run it

```bash
npm install
npm run dev          # http://localhost:5173
npm run build        # dist/        installable PWA + service worker
npm run build:single # dist-single/ one self-contained index.html
npm run typecheck
npm run test:backup  # export/restore round trip
```

## Deploy

Push to `main`. The workflow typechecks, runs the backup test, builds with
`BASE_PATH=/<repo>/` and publishes `dist/` to GitHub Pages. Enable it once at
Settings → Pages → Source → GitHub Actions.

Installing to a home screen needs HTTPS, which Pages gives you. It will not
install from `file://` or plain `http://` — and IndexedDB is blocked on
`file://` entirely, so the single-file build still has to be served.

## Where the data lives

IndexedDB, on the device, and nowhere else. No mobile browser can write to a
user-visible file as it goes — `showSaveFilePicker` doesn't exist on Android or
iOS — so durability rests on two things: `navigator.storage.persist()`, which
the app requests at boot, and the backup file the user exports themselves.

## What's here

| Path | What it is |
|---|---|
| `src/db/types.ts` | Entity types. Schema v2 — v1 dropped `Item.category`. |
| `src/db/db.ts` | Dexie schema, migrations, first-run seeding. |
| `src/db/repo.ts` | All data access. Validation, soft delete, thumbnails, room rules. |
| `src/lib/warranty.ts` | Calendar-month maths. Expiry is computed, never stored. |
| `src/lib/backup.ts` | Export and restore the `.stashit` bundle. Merge and replace. |
| `src/lib/docs.ts` | Document attachment, blob lifecycle, open and download. |
| `src/lib/itemIcon.ts` | Picks a fallback icon from the item's own words. |
| `test/` | `npm test` — 274 assertions against fake-indexeddb. |
| `src/styles/tokens.css` | Graphite & brass palette. Every colour comes from here. |
| `src/App.tsx` | Screen state and the app shell. No router yet. |
| `src/screens/` | Home dashboard, Items, Item detail, Item form, Rooms, Settings. |
| `src/lib/search.ts` | Field-weighted matching. Partial serials, folded accents. |
| `src/lib/dashboard.ts` | The figures Home reports. Pure over items and docs. |
| `stash-it.html` | Signed-off UI concept — palette, motion lab, three screen mockups. |

## Decisions baked in

- **UUIDv7 IDs.** Time-sortable, safe if sync is ever added. Never auto-increment.
- **Warranty expiry is computed** from the term the user entered. Days are exact;
  months and years use calendar arithmetic, so 24 months from 31 Jan ends 31 Jan.
  A term entered in days counts down in days for its whole life.
- **Soft delete**, purged after 30 days. Deleting frees a free-tier slot immediately.
- **Thumbnails generated on add** — 200px WebP, so the list renders instantly.
- **Currency per item**, seeded from the device default at save time.
- **Rooms are entities**, seeded per property, fully editable. Deleting a room never
  cascades: items are reassigned or unassigned first.
- **Room is the only way items are organised.** Category was removed in v2: the
  icon comes from the item's own words, so category was a question with no
  consequence.
- **Entitlement flags, not SKU checks** (`proUnlock`, `reportUnlock`).
- **The item cap blocks new additions only.** Existing items stay editable and
  exportable at every tier.

## Try the free-tier gate

Settings → Developer → Pro unlock. Toggles the entitlement so you can hit the
15-item cap without wiring up purchases.

## Not built yet

Link health checks. Passphrase encryption for backups. The maintenance
log. Inventory report. Multiple properties. IAP, Capacitor wrapping, the
thin auth/analytics backend.
