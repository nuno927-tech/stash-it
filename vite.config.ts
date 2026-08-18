import { createRequire } from 'node:module';
import { fileURLToPath, URL } from 'node:url';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';
import { viteSingleFile } from 'vite-plugin-singlefile';

/**
 * Two build targets:
 *
 *   vite build                 → dist/        normal PWA, service worker, hashed assets
 *   vite build --mode single   → dist-single/ one self-contained index.html
 *
 * The single file is for handing the app to someone or dropping it on a static
 * host. It still needs serving over http:// — browsers deny IndexedDB to
 * file:// origins, so double-clicking it will not work. No service worker
 * either: a worker has to be a separate script at a real URL.
 */
const { version } = createRequire(import.meta.url)('./package.json') as { version: string };

/**
 * Where the app is served from. GitHub Pages puts a project site under
 * /<repo>/, and the app sits one level below that again at /<repo>/app/ —
 * the repo root belongs to the marketing site.
 *
 * That split is not cosmetic. While both lived under /<repo>/ the app's
 * service worker scope and its navigation scope covered the website too, so
 * an installed phone answered the website's address with the app.
 *
 * The deploy workflow sets BASE_PATH; local builds stay at '/'.
 */
const base = process.env.BASE_PATH ?? '/';

/**
 * The manifest's scope is deliberately the level above the app.
 *
 * It has to include the marketing page or Chromium won't fire
 * beforeinstallprompt there and the site's install button can't work. It
 * costs nothing to widen: the service worker's scope comes from where sw.js
 * sits, not from the manifest, so the worker still only controls the app.
 */
const scope = process.env.SITE_PATH ?? base;

export default defineConfig(({ mode }) => {
  const single = mode === 'single';

  /*
    `.env.local` is not in `process.env`, and assuming it was is a silent bug.

    Vite reads .env files for the *client* and exposes only `VITE_`-prefixed
    values on `import.meta.env`. Nothing populates `process.env` inside this
    config, so `process.env.VAPID_PUBLIC_KEY` reads undefined however carefully
    the file was filled in — and the build succeeds, ships an empty key, and
    the reminders switch says "not configured" as if that were the truth.

    `loadEnv` with an empty prefix reads every variable in the .env files,
    which is what the config needs and what the client must never get. A real
    shell variable still wins, so CI can pass one in without a file.
  */
  const env = { ...loadEnv(mode, process.cwd(), ''), ...process.env };

  return {
    // A single file can be opened from any path, so its asset URLs must be
    // relative — it has no idea where it will be served from.
    base: single ? './' : base,

    define: {
      __APP_VERSION__: JSON.stringify(version),
      // Where the marketing site lives. Sharing "the app" should hand someone
      // a page that explains what it is and offers to install it, not a bare
      // application they have to work out.
      __SITE_PATH__: JSON.stringify(single ? './' : scope),

      /*
        The VAPID public key, for push subscriptions.

        Public by definition: the browser is handed it and forwards it to
        Google or Apple, so it is not a secret and belongs in the build. The
        PRIVATE half signs the sends and must never appear in this repo — it
        lives in the sender's environment, which does not exist yet.

        Empty by default, and the reminders toggle says "not configured in this
        build" rather than failing at the browser. See docs/push.md.
      */
      __VAPID_PUBLIC_KEY__: JSON.stringify(env.VAPID_PUBLIC_KEY ?? ''),
    },

    plugins: [
      react(),
      ...(single
        ? [viteSingleFile()]
        : [
            VitePWA({
              /*
                'prompt' was the wrong choice, and it was why fixes appeared
                not to work. Under 'prompt' a new worker installs and then
                waits for every client to close before it takes over — and an
                installed PWA on a phone is never really closed. Nothing in the
                app registered the worker or offered the refresh either, so the
                only thing that ever triggered the handover was the OS killing
                the app for memory. People ran a build or two behind for days
                and reported bugs that had already been fixed.

                'autoUpdate' takes over on the next launch: skipWaiting and
                clientsClaim, plus the reload in main.tsx for the case where a
                new build lands while the app is open.
              */
              registerType: 'autoUpdate',
              includeAssets: ['apple-touch-icon.png'],
              workbox: {
                // The point of the change above: don't wait for the last tab.
                skipWaiting: true,
                clientsClaim: true,
                // Precaches from previous builds are dead weight the moment
                // this one claims the page.
                cleanupOutdatedCaches: true,
                /*
                  Pulled in at the top of the generated worker, so their
                  listeners are registered before Workbox's routing. That's
                  what lets the share handler answer the share POST — first
                  respondWith wins.

                  The push handler is here for a different reason: it is plain
                  JavaScript because the generated worker is, which is exactly
                  why it does no thinking. The page works out what a reminder
                  should say and leaves it in Cache Storage; the worker reads
                  it. Two files rather than one bundled worker keeps the
                  precaching and the autoUpdate behaviour above untouched —
                  this app has already lost days to a service worker that
                  would not hand over.
                */
                importScripts: ['share-handler.js', 'push-handler.js'],
                globPatterns: ['**/*.{js,css,html,woff2,svg,webp}'],
                // Install icons are fetched by the OS at install time and never
                // again — precaching half a megabyte of them buys nothing.
                globIgnores: ['**/icon-*.png', '**/apple-touch-icon.png'],
                // Any unknown path inside the app resolves to the shell. Needed
                // once routing exists, harmless now.
                navigateFallback: `${base}index.html`,
                // …but never the share endpoint: falling that back to the
                // shell would hand the POST to Workbox and lose the payload.
                //
                // The marketing site needs no exclusion any more. It lives
                // above the app, outside this worker's scope, which is the
                // whole reason the app moved down a level.
                navigateFallbackDenylist: [/\/share$/],
              },
              manifest: {
                id: base,
                name: 'Stash it',
                short_name: 'Stash it',
                description: 'Warranties, receipts and manuals for everything you own.',
                start_url: base,
                scope,
                display: 'standalone',
                orientation: 'portrait',
                // Matches the HTML splash exactly. The OS draws this one and
                // we draw the other; any difference reads as a flash.
                background_color: '#F4F2ED',
                theme_color: '#F4F2ED',
                categories: ['productivity', 'utilities'],
                /**
                 * Puts Stash it in the Android share sheet, so a receipt goes
                 * from the mail app to an item without a round trip through
                 * Files. POST because GET share targets can't carry files.
                 *
                 * Android only — iOS has never implemented share targets, and
                 * there the route stays Gmail → save to Files → the picker.
                 */
                share_target: {
                  action: `${base}share`,
                  method: 'POST',
                  enctype: 'multipart/form-data',
                  params: {
                    title: 'title',
                    text: 'text',
                    url: 'url',
                    files: [
                      {
                        name: 'files',
                        accept: ['image/*', 'application/pdf', '.pdf'],
                      },
                    ],
                  },
                },
                icons: [
                  { src: 'icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
                  { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
                  {
                    src: 'icon-maskable-512.png',
                    sizes: '512x512',
                    type: 'image/png',
                    purpose: 'maskable',
                  },
                ],
              },
            }),
          ]),
    ],

    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },

    build: single
      ? {
          outDir: 'dist-single',
          // Inline every asset, mascots included. They're ~167 KB of WebP.
          assetsInlineLimit: 10_000_000,
          cssCodeSplit: false,
        }
      : {},
  };
});
