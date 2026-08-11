import { createRequire } from 'node:module';
import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
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
 * GitHub Pages serves a project site from /<repo>/, not the domain root, so
 * every asset URL has to be prefixed. The deploy workflow sets BASE_PATH from
 * the repo name; local builds stay at '/'.
 */
const base = process.env.BASE_PATH ?? '/';

export default defineConfig(({ mode }) => {
  const single = mode === 'single';

  return {
    // A single file can be opened from any path, so its asset URLs must be
    // relative — it has no idea where it will be served from.
    base: single ? './' : base,

    define: {
      __APP_VERSION__: JSON.stringify(version),
    },

    plugins: [
      react(),
      ...(single
        ? [viteSingleFile()]
        : [
            VitePWA({
              registerType: 'prompt',
              includeAssets: ['apple-touch-icon.png'],
              workbox: {
                globPatterns: ['**/*.{js,css,html,woff2,svg,webp}'],
                // Install icons are fetched by the OS at install time and never
                // again — precaching half a megabyte of them buys nothing.
                globIgnores: ['**/icon-*.png', '**/apple-touch-icon.png'],
                // Any unknown path inside the app resolves to the shell. Needed
                // once routing exists, harmless now.
                navigateFallback: `${base}index.html`,
              },
              manifest: {
                id: base,
                name: 'Stash it',
                short_name: 'Stash it',
                description: 'Warranties, receipts and manuals for everything you own.',
                start_url: base,
                scope: base,
                display: 'standalone',
                orientation: 'portrait',
                // Matches the HTML splash exactly. The OS draws this one and
                // we draw the other; any difference reads as a flash.
                background_color: '#F4F2ED',
                theme_color: '#F4F2ED',
                categories: ['productivity', 'utilities'],
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
