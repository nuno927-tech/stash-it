/**
 * Backing up to Google Drive, from a page with no server behind it.
 *
 * ── Why this is possible at all ───────────────────────────────────────────
 * The `drive.file` scope only grants access to files this app created. It is
 * classified non-sensitive, so it needs no security assessment, no annual
 * recertification and no verification — unlike anything that can read a whole
 * Drive or an inbox. It is also exactly the access a backup needs: Stash it
 * can see its own backups and nothing else in your Drive, and that limit is
 * enforced by Google rather than promised by me.
 *
 * ── The client ID ─────────────────────────────────────────────────────────
 * There's no server to hold a secret, so this uses the browser token flow: a
 * public client ID, locked to an origin, and no client secret anywhere. The ID
 * has to be created by whoever deploys the app (see docs/google-drive.md) and
 * is stored in settings. It isn't a credential — publishing it does nothing
 * for an attacker, because Google will only issue tokens to the origins listed
 * on it.
 *
 * ── The token ─────────────────────────────────────────────────────────────
 * Held in memory for its hour and never written down. A token in IndexedDB
 * would outlive the session in a database that is, by design, not encrypted —
 * and unlike the data beside it, a leaked token grants access to something
 * outside this device.
 *
 * Every network call goes through an injectable `DriveApi`, so the logic that
 * decides what to upload, which backup is newest and when one is overdue can
 * be tested without a network or a Google account.
 */

import { backupFilename } from './backup';

export const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive.file';
export const FOLDER_NAME = 'Stash it';
const FOLDER_MIME = 'application/vnd.google-apps.folder';

export class DriveError extends Error {}

export interface DriveFile {
  id: string;
  name: string;
  createdTime: string;
  size?: string;
}

/** The four calls this feature makes. Injected so the rest can be tested. */
export interface DriveApi {
  findFolder(name: string): Promise<string | null>;
  createFolder(name: string): Promise<string>;
  upload(folderId: string, filename: string, blob: Blob): Promise<DriveFile>;
  list(folderId: string): Promise<DriveFile[]>;
  download(fileId: string): Promise<Blob>;
}

/* ----------------------------------------------------------------- policy */

export type DriveState = 'unconfigured' | 'configured';

export function driveState(clientId: string | undefined): DriveState {
  return isClientId(clientId) ? 'configured' : 'unconfigured';
}

/**
 * Google's web client IDs all look like `<digits>-<hash>.apps.googleusercontent.com`.
 * Checking the shape catches the most likely setup mistake — pasting the
 * project number, the API key or the client *secret* — at the point where the
 * user can still see what they pasted, rather than as a sign-in failure ten
 * minutes later.
 */
export function isClientId(value: string | undefined): boolean {
  return /^[\w-]+\.apps\.googleusercontent\.com$/.test((value ?? '').trim());
}

/**
 * Newest first. Drive returns creation time as an ISO string and the filenames
 * carry only a date, so two backups made on the same day are only separable by
 * createdTime — which is why it, not the name, is the sort key.
 */
export function sortBackups(files: DriveFile[]): DriveFile[] {
  return [...files]
    .filter((f) => f.name.endsWith('.stashit'))
    .sort((a, b) => (a.createdTime < b.createdTime ? 1 : a.createdTime > b.createdTime ? -1 : 0));
}

export function latestBackup(files: DriveFile[]): DriveFile | undefined {
  return sortBackups(files)[0];
}

/**
 * Whether to nudge. `everyDays === 0` is the user saying never, and must not
 * be read as "every zero days" — which is how a reminder feature becomes a
 * thing people turn off entirely.
 */
export function backupOverdue(
  lastAt: string | undefined,
  everyDays: number,
  now = new Date(),
): boolean {
  if (everyDays <= 0) return false;
  if (!lastAt) return true;
  const last = new Date(lastAt).getTime();
  if (Number.isNaN(last)) return true;
  return now.getTime() - last >= everyDays * 86_400_000;
}

/**
 * Drive keeps every upload with the same name as a separate file, so without
 * pruning a weekly backup becomes fifty-two copies of every photo. Keeps the
 * newest `keep` and returns the rest for deletion — oldest first, so a partial
 * failure still deletes the least valuable ones.
 */
export function pruneable(files: DriveFile[], keep = 10): DriveFile[] {
  return sortBackups(files).slice(keep).reverse();
}

/* --------------------------------------------------------------- the flow */

/** Uploads a bundle, creating the folder on first use. */
export async function backupToDrive(api: DriveApi, blob: Blob, now = new Date()): Promise<DriveFile> {
  const folderId = (await api.findFolder(FOLDER_NAME)) ?? (await api.createFolder(FOLDER_NAME));
  return api.upload(folderId, backupFilename(now), blob);
}

export async function listDriveBackups(api: DriveApi): Promise<DriveFile[]> {
  const folderId = await api.findFolder(FOLDER_NAME);
  // No folder means nothing has ever been uploaded. Creating one here, as a
  // side effect of looking, would leave empty folders in the Drive of anyone
  // who merely opened the screen.
  if (!folderId) return [];
  return sortBackups(await api.list(folderId));
}

/* ------------------------------------------------------------------ auth */

interface TokenResponse {
  access_token?: string;
  expires_in?: number;
  error?: string;
}

interface TokenClient {
  requestAccessToken(overrides?: { prompt?: string }): void;
  callback: (r: TokenResponse) => void;
}

declare global {
  interface Window {
    google?: {
      accounts?: {
        oauth2?: {
          initTokenClient(config: {
            client_id: string;
            scope: string;
            callback: (r: TokenResponse) => void;
            error_callback?: (e: { type?: string }) => void;
          }): TokenClient;
          revoke(token: string, done?: () => void): void;
        };
      };
    };
  }
}

const GIS_SRC = 'https://accounts.google.com/gsi/client';

let scriptLoad: Promise<void> | null = null;

function loadGis(): Promise<void> {
  if (window.google?.accounts?.oauth2) return Promise.resolve();
  // Loaded on demand rather than in index.html: someone who never connects
  // Drive should not be fetching Google's script, and the offline app should
  // not be waiting on a third-party origin at boot.
  scriptLoad ??= new Promise<void>((resolve, reject) => {
    const el = document.createElement('script');
    el.src = GIS_SRC;
    el.async = true;
    el.onload = () => resolve();
    el.onerror = () => {
      scriptLoad = null;
      reject(new DriveError("Couldn't reach Google. Check your connection."));
    };
    document.head.appendChild(el);
  });
  return scriptLoad;
}

let token: { value: string; expiresAt: number } | null = null;

export function signedIn(): boolean {
  return token !== null && token.expiresAt > Date.now();
}

export function forgetToken(): void {
  const held = token?.value;
  token = null;
  if (held) window.google?.accounts?.oauth2?.revoke(held);
}

/**
 * A token, asking the user only when it has to.
 *
 * `prompt: ''` means "don't show the account chooser if you already know the
 * answer" — after the first grant, renewals are silent. The first call, and
 * any call after the grant is withdrawn, shows Google's consent screen.
 */
export async function getToken(clientId: string, interactive = true): Promise<string> {
  if (token && token.expiresAt > Date.now() + 60_000) return token.value;
  if (!isClientId(clientId)) throw new DriveError('That client ID does not look right.');

  await loadGis();
  const oauth2 = window.google?.accounts?.oauth2;
  if (!oauth2) throw new DriveError("Google's sign-in script did not load.");

  return new Promise<string>((resolve, reject) => {
    const client = oauth2.initTokenClient({
      client_id: clientId,
      scope: DRIVE_SCOPE,
      callback: (r) => {
        if (!r.access_token) {
          reject(new DriveError(r.error ?? 'Google did not return a token.'));
          return;
        }
        // A minute of slack, so a call started just before expiry doesn't
        // fail halfway through a multi-megabyte upload.
        token = { value: r.access_token, expiresAt: Date.now() + (r.expires_in ?? 3600) * 1000 };
        resolve(r.access_token);
      },
      error_callback: (e) => reject(new DriveError(signInMessage(e?.type))),
    });
    client.requestAccessToken({ prompt: interactive ? '' : 'none' });
  });
}

function signInMessage(type: string | undefined): string {
  if (type === 'popup_closed') return 'Sign-in was closed before it finished.';
  if (type === 'popup_failed_to_open') {
    return 'The sign-in window was blocked. Allow pop-ups for this site and try again.';
  }
  return 'Sign-in did not complete.';
}

/* ------------------------------------------------------------- the client */

const API = 'https://www.googleapis.com/drive/v3';
const UPLOAD = 'https://www.googleapis.com/upload/drive/v3/files';

export function liveDrive(clientId: string): DriveApi {
  const auth = async () => ({ Authorization: `Bearer ${await getToken(clientId)}` });

  const json = async (res: Response) => {
    if (!res.ok) throw new DriveError(await driveMessage(res));
    return res.json();
  };

  return {
    async findFolder(name) {
      // `trashed = false` matters: a folder the user deleted still answers a
      // search, and uploading into it would put backups in the bin.
      const q = encodeURIComponent(
        `name = '${name.replace(/'/g, "\\'")}' and mimeType = '${FOLDER_MIME}' and trashed = false`,
      );
      const res = await fetch(`${API}/files?q=${q}&fields=files(id)&pageSize=1`, {
        headers: await auth(),
      });
      const body = (await json(res)) as { files?: { id: string }[] };
      return body.files?.[0]?.id ?? null;
    },

    async createFolder(name) {
      const res = await fetch(`${API}/files?fields=id`, {
        method: 'POST',
        headers: { ...(await auth()), 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, mimeType: FOLDER_MIME }),
      });
      return ((await json(res)) as { id: string }).id;
    },

    /**
     * Resumable rather than multipart. A bundle is every photo and document
     * in the app; multipart is documented for files up to 5 MB, and a backup
     * that silently fails once someone has a phone full of receipts is worse
     * than no backup at all. Sent as a single PUT — a failure retries the
     * whole upload rather than resuming, which is the honest simple version.
     */
    async upload(folderId, filename, blob) {
      const start = await fetch(`${UPLOAD}?uploadType=resumable&fields=id,name,createdTime,size`, {
        method: 'POST',
        headers: {
          ...(await auth()),
          'Content-Type': 'application/json',
          'X-Upload-Content-Type': 'application/zip',
          'X-Upload-Content-Length': String(blob.size),
        },
        body: JSON.stringify({ name: filename, parents: [folderId] }),
      });
      if (!start.ok) throw new DriveError(await driveMessage(start));

      const session = start.headers.get('location');
      if (!session) throw new DriveError('Google did not open an upload session.');

      const res = await fetch(session, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/zip' },
        body: blob,
      });
      return (await json(res)) as DriveFile;
    },

    async list(folderId) {
      const q = encodeURIComponent(`'${folderId}' in parents and trashed = false`);
      const res = await fetch(
        `${API}/files?q=${q}&fields=files(id,name,createdTime,size)&orderBy=createdTime desc&pageSize=50`,
        { headers: await auth() },
      );
      return ((await json(res)) as { files?: DriveFile[] }).files ?? [];
    },

    async download(fileId) {
      const res = await fetch(`${API}/files/${fileId}?alt=media`, { headers: await auth() });
      if (!res.ok) throw new DriveError(await driveMessage(res));
      return res.blob();
    },
  };
}

/**
 * Google's errors are JSON with a usable sentence inside. Surfacing "403" to
 * someone who has just pasted a client ID tells them nothing about which of
 * the four setup steps they missed.
 */
async function driveMessage(res: Response): Promise<string> {
  let detail = '';
  try {
    const body = (await res.json()) as { error?: { message?: string } };
    detail = body.error?.message ?? '';
  } catch {
    /* not JSON */
  }
  if (res.status === 401) return 'Google rejected the sign-in. Try connecting again.';
  if (res.status === 403 && /API has not been used|disabled/i.test(detail)) {
    return 'The Drive API is not enabled on that Google Cloud project yet.';
  }
  return detail || `Drive returned ${res.status}.`;
}
