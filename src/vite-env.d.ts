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

/**
 * The VAPID public key for push subscriptions, base64url, or '' when this
 * build has none. Public by design — the browser hands it to the push service.
 * The private half signs sends and is never in this repo.
 */
declare const __VAPID_PUBLIC_KEY__: string;

/**
 * Base URL of the reminder sender, or '' when there isn't one. With no sender
 * the app still computes and shows the schedule; it just never uploads it.
 */
declare const __PUSH_ENDPOINT__: string;
