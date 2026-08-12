import { useState, type ReactNode } from 'react';
import { db } from '@/db/db';
import type { Settings as SettingsRecord } from '@/db/types';
import { exportBundle, parseBundle, type ParsedBundle } from '@/lib/backup';
import {
  backupOverdue,
  backupToDrive,
  DriveError,
  driveState,
  isClientId,
  listDriveBackups,
  liveDrive,
  pruneable,
  type DriveFile,
} from '@/lib/drive';
import { feedback } from '@/lib/feedback';
import { formatBytes } from '@/lib/storage';

/**
 * Drive backup, in two states: not set up, and set up.
 *
 * The unconfigured state is mostly instructions, which is unusual for a
 * settings card and unavoidable here — a static app has no server to hold an
 * OAuth secret, so the client ID has to be made by the person deploying it.
 * Hiding that behind a friendly "Connect" button that then fails would be
 * worse than being upfront about the five minutes it costs.
 */
export function DriveCard({
  settings,
  onNotice,
  onRestore,
}: {
  settings: SettingsRecord;
  onNotice: (n: { tone: 'ok' | 'bad'; text: string } | null) => void;
  onRestore: (bundle: ParsedBundle) => void;
}) {
  const [busy, setBusy] = useState<string | null>(null);
  const [files, setFiles] = useState<DriveFile[] | null>(null);
  const [setup, setSetup] = useState(false);

  const clientId = settings.driveClientId;
  const configured = driveState(clientId) === 'configured';
  const last = settings.lastDriveBackupAt;
  const overdue = backupOverdue(last, settings.backupReminderDays);

  const run = async (what: string, fn: () => Promise<void>) => {
    setBusy(what);
    onNotice(null);
    try {
      await fn();
    } catch (e) {
      feedback('error');
      onNotice({
        tone: 'bad',
        text: e instanceof DriveError ? e.message : `Drive failed: ${(e as Error).message}`,
      });
    } finally {
      setBusy(null);
    }
  };

  const back = () =>
    run('backup', async () => {
      const api = liveDrive(clientId!);
      const { blob } = await exportBundle();
      const file = await backupToDrive(api, blob);
      await db.settings.update('singleton', { lastDriveBackupAt: new Date().toISOString() });

      // Drive keeps same-named uploads as separate files, so without this a
      // weekly backup becomes fifty-two copies of every photo.
      const all = await listDriveBackups(api);
      setFiles(all);
      const old = pruneable(all);
      feedback('save');
      onNotice({
        tone: 'ok',
        text: `Backed up ${file.name}${old.length ? ` · ${old.length} older kept in Drive` : ''}.`,
      });
    });

  const refresh = () =>
    run('list', async () => {
      setFiles(await listDriveBackups(liveDrive(clientId!)));
    });

  const pull = (file: DriveFile) =>
    run(file.id, async () => {
      const blob = await liveDrive(clientId!).download(file.id);
      // Parsed here, restored by the Backup card — one restore path, one set
      // of merge-or-replace consequences, whichever direction the file came
      // from.
      onRestore(await parseBundle(new File([blob], file.name)));
    });

  return (
    <section className="card setcard">
      <div className="cardhead">
        <h3>Google Drive</h3>
        {configured && (
          <span className="countpill">{last ? last.slice(0, 10) : 'Never'}</span>
        )}
      </div>

      {!configured ? (
        <>
          <p className="hint">
            Backups can upload to a folder in your Drive. Stash it only ever sees files it created
            there — that's enforced by Google, not promised by the app.
          </p>

          <button
            type="button"
            className="linkish morelink"
            aria-expanded={setup}
            onClick={() => setSetup(!setup)}
          >
            {setup ? 'Hide the steps' : 'How to set this up'}
          </button>

          {setup && <SetupSteps />}

          <ClientIdField
            initial={clientId ?? ''}
            onSave={(value) =>
              run('save', async () => {
                await db.settings.update('singleton', { driveClientId: value });
                feedback('save');
                onNotice({ tone: 'ok', text: 'Saved. Try a backup to check it works.' });
              })
            }
          />
        </>
      ) : (
        <>
          {overdue && (
            <p className="hint warnhint">
              {last
                ? `Last Drive backup was ${last.slice(0, 10)}. Worth running another.`
                : 'Nothing has been backed up to Drive yet.'}
            </p>
          )}

          <button type="button" className="btn wide" disabled={!!busy} onClick={back}>
            <CloudGlyph />
            {busy === 'backup' ? 'Uploading…' : 'Back up to Drive'}
          </button>

          <Row
            label="Restore from Drive"
            note="Lists what's in the folder. You'll still choose merge or replace."
            control={
              <button type="button" className="minibtn ghost" disabled={!!busy} onClick={refresh}>
                {busy === 'list' ? 'Looking…' : files ? 'Refresh' : 'Show'}
              </button>
            }
          />

          {files && files.length === 0 && <p className="hint">No backups in Drive yet.</p>}

          {files && files.length > 0 && (
            <ul className="drivelist">
              {files.map((f) => (
                <li key={f.id}>
                  <span className="drivefile">
                    <strong>{f.createdTime.slice(0, 10)}</strong>
                    <small>
                      {f.createdTime.slice(11, 16)}
                      {f.size ? ` · ${formatBytes(Number(f.size))}` : ''}
                    </small>
                  </span>
                  <button
                    type="button"
                    className="minibtn ghost"
                    disabled={!!busy}
                    onClick={() => pull(f)}
                  >
                    {busy === f.id ? 'Fetching…' : 'Restore'}
                  </button>
                </li>
              ))}
            </ul>
          )}

          <button
            type="button"
            className="linkish morelink"
            onClick={() =>
              run('forget', async () => {
                await db.settings.update('singleton', { driveClientId: undefined });
                setFiles(null);
                onNotice({ tone: 'ok', text: 'Disconnected. Backups already in Drive stay there.' });
              })
            }
          >
            Disconnect
          </button>
        </>
      )}
    </section>
  );
}

/** Kept local to the card: the shape is the settings Row, minus the coupling. */
function Row({ label, note, control }: { label: string; note: string; control: ReactNode }) {
  return (
    <div className="setrow">
      <span className="setrow-txt">
        <strong>{label}</strong>
        <small>{note}</small>
      </span>
      {control}
    </div>
  );
}

function ClientIdField({
  initial,
  onSave,
}: {
  initial: string;
  onSave: (value: string) => void;
}) {
  const [value, setValue] = useState(initial);
  const valid = isClientId(value);

  return (
    <div className="clientid">
      <input
        type="text"
        value={value}
        onChange={(e) => setValue(e.target.value.trim())}
        placeholder="…apps.googleusercontent.com"
        aria-label="Google OAuth client ID"
        autoComplete="off"
        spellCheck={false}
      />
      <button type="button" className="minibtn" disabled={!valid} onClick={() => onSave(value)}>
        Save
      </button>
      {value && !valid && (
        <small className="clientid-bad">
          That isn't a client ID. It ends in .apps.googleusercontent.com — not the project number,
          not an API key, and never the client secret.
        </small>
      )}
    </div>
  );
}

/**
 * Four steps, no screenshots. Google's console gets rearranged often enough
 * that a picture is a liability, but the names of the things stay put.
 */
function SetupSteps() {
  return (
    <ol className="installsteps setupsteps">
      <li>
        <span className="stepnum">1</span>
        <span>
          At <b>console.cloud.google.com</b>, make a project — any name.
        </span>
      </li>
      <li>
        <span className="stepnum">2</span>
        <span>
          In <b>APIs and services</b>, enable the <b>Google Drive API</b>.
        </span>
      </li>
      <li>
        <span className="stepnum">3</span>
        <span>
          Under <b>Credentials</b>, create an <b>OAuth client ID</b> of type <b>Web application</b>,
          and add <b>{origin()}</b> as an authorised JavaScript origin.
        </span>
      </li>
      <li>
        <span className="stepnum">4</span>
        <span>Paste the client ID below. It's public — it only works from that origin.</span>
      </li>
    </ol>
  );
}

function origin(): string {
  return typeof location === 'undefined' ? 'your site' : location.origin;
}

function CloudGlyph() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.9"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M7 18.5a4 4 0 01-.4-8A5.5 5.5 0 0117.4 9a3.75 3.75 0 01.4 9.5z" />
      <path d="M12 16v-6M9.5 12.5L12 10l2.5 2.5" />
    </svg>
  );
}
