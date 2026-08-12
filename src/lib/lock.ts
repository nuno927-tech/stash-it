/**
 * Locking the app behind the device's own biometrics.
 *
 * This is WebAuthn with a platform authenticator: the same Face ID, Touch ID or
 * fingerprint check the OS already trusts, asked for by the browser. We create
 * one credential when the lock is switched on and ask the device to prove it on
 * each launch.
 *
 * ── What this does and does not do ────────────────────────────────────────
 * It is a lock on the door, not a safe. WebAuthn authenticates; it does not
 * encrypt, and the database sits in IndexedDB in the clear either way. Someone
 * who picks up your unlocked phone is stopped. Someone with the phone, a cable
 * and a devtools window is not. The copy in Settings says "locks the app" and
 * never "encrypts", because promising the second would be a lie.
 *
 * (Real at-rest encryption is possible — the PRF extension can derive a key
 * from the same credential — but it isn't universally supported and would need
 * a passcode fallback and a change to the backup format. Deliberately not done
 * here.)
 *
 * ── Getting locked out ────────────────────────────────────────────────────
 * A lock with a visible bypass isn't a lock, so cancelling the prompt just
 * leaves you at the sheet. But a credential can genuinely cease to exist — the
 * user removes their fingerprints, the passkey is deleted — and then no amount
 * of trying will ever succeed. `lockVerdict` distinguishes those two: only when
 * the device reports no platform authenticator at all does the escape hatch
 * appear, and reaching that state on a stolen phone requires the passcode.
 */

import { db } from '@/db/db';

const RP_NAME = 'Stash it';
const USER_NAME = 'This device';

export type UnlockOutcome = 'unlocked' | 'cancelled' | 'failed' | 'unsupported';

/* ------------------------------------------------------------ capability */

export function webAuthnSupported(): boolean {
  return typeof window !== 'undefined' && typeof window.PublicKeyCredential === 'function';
}

/**
 * Whether this device has a built-in authenticator we can use. A security key
 * in a USB port is not what anyone means by "use my fingerprint", so the
 * platform check matters more than the API check.
 */
export async function biometricsAvailable(): Promise<boolean> {
  if (!webAuthnSupported()) return false;
  try {
    return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
  } catch {
    return false;
  }
}

/* ------------------------------------------------------------- enrolment */

/**
 * Turn the lock on. Returns the credential id to store, or null if the user
 * backed out of the OS prompt.
 *
 * `residentKey: 'discouraged'` on purpose: we always know which credential to
 * ask for, so there's no reason to consume one of the authenticator's limited
 * discoverable slots.
 */
export async function enrolBiometrics(): Promise<string | null> {
  if (!webAuthnSupported()) return null;

  const challenge = randomBytes(32);
  const userId = randomBytes(16);

  try {
    const cred = (await navigator.credentials.create({
      publicKey: {
        challenge,
        rp: { name: RP_NAME, id: window.location.hostname },
        user: { id: userId, name: USER_NAME, displayName: USER_NAME },
        // ES256 then RS256. We never verify a signature — there's no server to
        // verify it against — but the list is required.
        pubKeyCredParams: [
          { type: 'public-key', alg: -7 },
          { type: 'public-key', alg: -257 },
        ],
        authenticatorSelection: {
          authenticatorAttachment: 'platform',
          userVerification: 'required',
          residentKey: 'discouraged',
        },
        timeout: 60_000,
        attestation: 'none',
      },
    })) as PublicKeyCredential | null;

    return cred ? toBase64Url(new Uint8Array(cred.rawId)) : null;
  } catch {
    // Cancelled, timed out, or unsupported in this context. All the same to
    // the caller: the lock did not get switched on.
    return null;
  }
}

/**
 * Ask the device to prove it's the same person. The signature is never checked
 * — there is no server and no secret to protect — so what we rely on is the
 * platform's promise that it won't hand back an assertion without a successful
 * user-verification gesture.
 */
export async function verifyBiometrics(credentialId: string): Promise<UnlockOutcome> {
  if (!webAuthnSupported()) return 'unsupported';

  try {
    const assertion = await navigator.credentials.get({
      publicKey: {
        challenge: randomBytes(32),
        allowCredentials: [{ type: 'public-key', id: fromBase64Url(credentialId) }],
        userVerification: 'required',
        timeout: 60_000,
      },
    });
    return assertion ? 'unlocked' : 'failed';
  } catch (e) {
    // NotAllowedError covers both "user cancelled" and "user failed the
    // gesture"; the spec deliberately refuses to say which, so neither can we.
    return (e as Error)?.name === 'NotAllowedError' ? 'cancelled' : 'failed';
  }
}

/* ----------------------------------------------------------------- state */

export interface LockState {
  /** The user's setting. */
  enabled: boolean;
  /** What enrolment produced. Without it there's nothing to verify against. */
  credentialId?: string;
  /** Whether the device still has a usable platform authenticator. */
  available: boolean;
}

export type LockVerdict = 'open' | 'locked' | 'stranded';

/**
 * Pure, because the combinations are where the bugs live: a lock that stays up
 * when it can never be satisfied is a data-loss event, and one that quietly
 * lets you past because a field was missing is worse than not having it.
 */
export function lockVerdict(state: LockState): LockVerdict {
  if (!state.enabled) return 'open';
  if (!state.credentialId) return 'open'; // enrolment never completed
  if (!state.available) return 'stranded'; // the authenticator is gone
  return 'locked';
}

/** Whether Settings should offer the switch at all. */
export function canOfferLock(available: boolean): boolean {
  return available;
}

/* ----------------------------------------------------------------- store */

export async function saveLock(credentialId: string): Promise<void> {
  await db.settings.update('singleton', { biometricLock: true, lockCredentialId: credentialId });
}

/** Clearing the credential too — a stale id would strand the next enrolment. */
export async function clearLock(): Promise<void> {
  await db.settings.update('singleton', { biometricLock: false, lockCredentialId: undefined });
}

/* ----------------------------------------------------------------- bytes */

/**
 * Backed by an explicit ArrayBuffer, not just `new Uint8Array(n)`. WebAuthn's
 * BufferSource excludes SharedArrayBuffer-backed views, and the default type
 * argument leaves that open.
 */
function randomBytes(n: number): Uint8Array<ArrayBuffer> {
  const b = new Uint8Array(new ArrayBuffer(n));
  crypto.getRandomValues(b);
  return b;
}

export function toBase64Url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function fromBase64Url(s: string): Uint8Array<ArrayBuffer> {
  const padded = s.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(s.length / 4) * 4, '=');
  const raw = atob(padded);
  const bytes = new Uint8Array(new ArrayBuffer(raw.length));
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}
