/// <reference types="vite/client" />
/// <reference types="vite-plugin-pwa/client" />

/** Injected by vite.config.ts from package.json. */
declare const __APP_VERSION__: string;

/**
 * Where the marketing site lives — one level above the app. Injected rather
 * than derived from BASE_URL, because "the parent of the base path" is only
 * true by convention and a convention is not a thing to compute against.
 */
declare const __SITE_PATH__: string;
