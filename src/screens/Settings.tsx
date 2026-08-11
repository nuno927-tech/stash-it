import { useEffect, useRef, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItemCount } from '@/db/repo';
import { FREE_ITEM_LIMIT } from '@/db/types';
import { clearDemoItems, seedDemoItems } from '@/dev/seed';
import {
  BundleError,
  exportBundle,
  parseBundle,
  restoreBundle,
  saveBundle,
  type ParsedBundle,
  type RestoreMode,
  type RestoreResult,
} from '@/lib/backup';
import {
  formatBytes,
  persistenceState,
  requestPersistence,
  storageUsage,
  type PersistState,
  type StorageUsage,
} from '@/lib/storage';
import { feedback, hapticsSupported, previewCue } from '@/lib/feedback';
import {
  forgetDismissal,
  hasNativePrompt,
  installOfferIgnoringDismissal,
  isIOSSafari,
  isStandalone,
  promptInstall,
} from '@/lib/install';
import {
  BACKUP_REMINDER_CHOICES,
  CURRENCIES,
  prefsFrom,
  REMINDER_CHOICES,
  setPref,
  type RoomsView,
  type ThemeChoice,
} from '@/lib/prefs';

type Notice = { tone: 'ok' | 'bad'; text: string } | null;

export function Settings({
  propertyId,
  onOpenRooms,
}: {
  propertyId: string;
  onOpenRooms: () => void;
}) {
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const count = useLiveQuery(() => activeItemCount(propertyId), [propertyId]) ?? 0;

  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<Notice>(null);
  const [pending, setPending] = useState<ParsedBundle | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  if (!settings) return null;

  const run = async (fn: () => Promise<unknown>) => {
    setBusy(true);
    setNotice(null);
    try {
      await fn();
    } catch (e) {
      feedback('error');
      setNotice({
        tone: 'bad',
        text: e instanceof BundleError ? e.message : `Something went wrong: ${(e as Error).message}`,
      });
    } finally {
      setBusy(false);
    }
  };

  const onExport = () =>
    run(async () => {
      const { blob, filename } = await exportBundle();
      const how = await saveBundle(blob, filename);
      feedback('save');
      setNotice({
        tone: 'ok',
        text: how === 'shared' ? `Shared ${filename}.` : `Saved ${filename} to your downloads.`,
      });
    });

  const onPickFile = (file: File | undefined) => {
    if (!file) return;
    run(async () => {
      const bundle = await parseBundle(file);
      setPending(bundle);
    });
  };

  const onRestore = (mode: RestoreMode) => {
    const bundle = pending;
    if (!bundle) return;
    run(async () => {
      const r = await restoreBundle(bundle, mode);
      feedback('save');
      setPending(null);
      setNotice({ tone: 'ok', text: describe(r) });
    });
  };

  const setPro = (proUnlock: boolean) =>
    db.settings.update('singleton', {
      entitlements: { ...settings.entitlements, proUnlock },
    });

  return (
    <>
      <header className="apphead">
        <div className="apptitle">Settings</div>
      </header>

      {notice && <div className={`notice ${notice.tone}`}>{notice.text}</div>}

      <Appearance settings={settings} />

      <div className="seclabel" style={{ marginTop: 28 }}>
        <span>Your home</span>
      </div>

      <button type="button" className="navrow" onClick={onOpenRooms}>
        <span>
          <h4>Rooms</h4>
          <p>Add, rename and reorder the rooms items can live in.</p>
        </span>
        <svg
          width="17"
          height="17"
          viewBox="0 0 24 24"
          fill="none"
          stroke="var(--muted)"
          strokeWidth="2.4"
          strokeLinecap="round"
        >
          <path d="M9 5l7 7-7 7" />
        </svg>
      </button>

      <div className="setrow">
        <div>
          <h4>Currency</h4>
          <p>Used for new items. Each item keeps the currency it was saved with.</p>
        </div>
        <select
          className="compact"
          value={settings.currency}
          aria-label="Default currency"
          onChange={(e) => db.settings.update('singleton', { currency: e.target.value })}
        >
          {[...new Set([settings.currency, ...CURRENCIES])].map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
      </div>

      <div className="setrow">
        <div>
          <h4>Items open</h4>
          <p>Whether rooms start shut or already showing what's inside.</p>
        </div>
        <select
          className="compact"
          value={prefsFrom(settings).roomsView}
          aria-label="How the Items list opens"
          onChange={(e) => setPref('roomsView', e.target.value as RoomsView)}
        >
          <option value="collapsed">Collapsed</option>
          <option value="expanded">Expanded</option>
        </select>
      </div>

      <div className="setrow">
        <div>
          <h4>Warn me before a warranty ends</h4>
          <p>How much notice you want on the home screen.</p>
        </div>
        <select
          className="compact"
          value={settings.reminderOffsetsDays[0] ?? 30}
          aria-label="Warranty warning lead time"
          onChange={(e) =>
            db.settings.update('singleton', { reminderOffsetsDays: [Number(e.target.value)] })
          }
        >
          {REMINDER_CHOICES.map((r) => (
            <option key={r.days} value={r.days}>
              {r.label}
            </option>
          ))}
        </select>
      </div>

      <div className="seclabel" style={{ marginTop: 28 }}>
        <span>Backup</span>
        <span>{settings.lastBackupAt ? `Last ${settings.lastBackupAt.slice(0, 10)}` : 'Never'}</span>
      </div>

      <div className="setrow">
        <div>
          <h4>Export everything</h4>
          <p>
            One file with every item, document and photo. Save it somewhere you'll still have it if
            you lose this phone.
          </p>
        </div>
        <button type="button" className="minibtn" disabled={busy} onClick={onExport}>
          Export
        </button>
      </div>

      <div className="setrow">
        <div>
          <h4>Restore from a backup</h4>
          <p>Reads a .stashit file. You'll choose how it merges before anything changes.</p>
        </div>
        <button
          type="button"
          className="minibtn ghost"
          disabled={busy}
          onClick={() => fileInput.current?.click()}
        >
          Choose file
        </button>
        <input
          ref={fileInput}
          type="file"
          accept=".stashit,application/zip"
          hidden
          onChange={(e) => {
            onPickFile(e.target.files?.[0]);
            e.target.value = '';
          }}
        />
      </div>

      <div className="setrow">
        <div>
          <h4>Remind me to back up</h4>
          <p>Nothing leaves this device on its own, so the reminder is the safety net.</p>
        </div>
        <select
          className="compact"
          value={settings.backupReminderDays}
          aria-label="Backup reminder frequency"
          onChange={(e) =>
            db.settings.update('singleton', { backupReminderDays: Number(e.target.value) })
          }
        >
          {BACKUP_REMINDER_CHOICES.map((b) => (
            <option key={b.days} value={b.days}>
              {b.label}
            </option>
          ))}
        </select>
      </div>

      {pending && (
        <RestoreChoice
          bundle={pending}
          busy={busy}
          onCancel={() => setPending(null)}
          onChoose={onRestore}
        />
      )}

      <InstallRow />

      <StorageSection />

      <div className="seclabel" style={{ marginTop: 28 }}>
        <span>Developer</span>
        <span>
          {count} / {settings.entitlements.proUnlock ? '∞' : FREE_ITEM_LIMIT}
        </span>
      </div>

      <div className="setrow">
        <div>
          <h4>Pro unlock</h4>
          <p>Lifts the {FREE_ITEM_LIMIT}-item cap. Entitlement flag, no purchase.</p>
        </div>
        <button
          type="button"
          className={`toggle${settings.entitlements.proUnlock ? ' on' : ''}`}
          role="switch"
          aria-checked={settings.entitlements.proUnlock}
          aria-label="Pro unlock"
          onClick={() => setPro(!settings.entitlements.proUnlock)}
        >
          <span />
        </button>
      </div>

      <div className="setrow">
        <div>
          <h4>Demo items</h4>
          <p>The four mockup items, dated to land on covered, ending soon and expired.</p>
        </div>
        <div className="setactions">
          <button
            type="button"
            className="minibtn"
            disabled={busy}
            onClick={() => run(() => seedDemoItems(propertyId))}
          >
            Seed
          </button>
          <button
            type="button"
            className="minibtn ghost"
            disabled={busy}
            onClick={() => run(clearDemoItems)}
          >
            Clear
          </button>
        </div>
      </div>

      <About schemaVersion={settings.schemaVersion} />
    </>
  );
}

/**
 * Version, schema and storage estimate in one place. The schema version is
 * here on purpose: when a backup won't restore, it's the first thing worth
 * knowing, and asking someone to find it in DevTools is not a support plan.
 */
function About({ schemaVersion }: { schemaVersion: number }) {
  return (
    <>
      <div className="seclabel" style={{ marginTop: 28 }}>
        <span>About</span>
      </div>
      <dl className="facts">
        <div className="row">
          <dt>Version</dt>
          <dd style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>{__APP_VERSION__}</dd>
        </div>
        <div className="row">
          <dt>Data schema</dt>
          <dd style={{ fontFamily: 'var(--font-mono)', fontSize: 12 }}>v{schemaVersion}</dd>
        </div>
      </dl>
      <p className="hint" style={{ marginTop: 14 }}>
        Stash it keeps everything on this device. Nothing is uploaded, so your backup file is the
        only copy that survives losing the phone.
      </p>
    </>
  );
}

const THEMES: { value: ThemeChoice; label: string }[] = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'system', label: 'Match device' },
];

/**
 * Appearance and feedback. Both toggles fire their own cue when switched on,
 * so you hear or feel exactly what you've just agreed to rather than finding
 * out the next time you save something.
 */
function Appearance({ settings }: { settings: import('@/db/types').Settings }) {
  const prefs = prefsFrom(settings);
  const canBuzz = hapticsSupported();

  return (
    <>
      <div className="seclabel">
        <span>Appearance</span>
      </div>

      <div className="seg">
        {THEMES.map((t) => (
          <button
            key={t.value}
            type="button"
            className={prefs.theme === t.value ? 'on' : ''}
            onClick={() => setPref('theme', t.value)}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="setrow">
        <div>
          <h4>Sounds</h4>
          <p>Clicks as you tap, and short tones when something saves, attaches or fails.</p>
        </div>
        <button
          type="button"
          className={`toggle${prefs.sounds ? ' on' : ''}`}
          role="switch"
          aria-checked={prefs.sounds}
          aria-label="Sounds"
          data-cue="none"
          onClick={() => {
            const next = !prefs.sounds;
            setPref('sounds', next);
            if (next) previewCue('save', { sounds: true, haptics: false });
          }}
        >
          <span />
        </button>
      </div>

      <div className="setrow">
        <div>
          <h4>Haptics</h4>
          <p>
            {canBuzz
              ? 'A gentle tick as you tap, and a firmer one when something saves or is deleted.'
              : 'This browser has no vibration support, so this does nothing here. It will on a phone that does.'}
          </p>
        </div>
        <button
          type="button"
          className={`toggle${prefs.haptics ? ' on' : ''}`}
          role="switch"
          aria-checked={prefs.haptics}
          aria-label="Haptics"
          data-cue="none"
          onClick={() => {
            const next = !prefs.haptics;
            setPref('haptics', next);
            if (next) previewCue('save', { sounds: false, haptics: true });
          }}
        >
          <span />
        </button>
      </div>
    </>
  );
}

/**
 * The install option, still reachable after the first-run sheet was dismissed.
 * Someone who tapped "Not now" and later changed their mind shouldn't have to
 * clear site data to find it again.
 */
function InstallRow() {
  const offer = installOfferIgnoringDismissal({
    standalone: isStandalone(),
    dismissed: false,
    nativePrompt: hasNativePrompt(),
    iosSafari: isIOSSafari(),
  });

  if (isStandalone()) {
    return (
      <>
        <div className="seclabel" style={{ marginTop: 28 }}>
          <span>Home screen</span>
        </div>
        <p className="hint">
          Installed. That's also what earns your data the browser's strongest storage promise.
        </p>
      </>
    );
  }

  if (offer === 'none') return null;

  return (
    <>
      <div className="seclabel" style={{ marginTop: 28 }}>
        <span>Home screen</span>
      </div>
      <div className="setrow">
        <div>
          <h4>Install Stash it</h4>
          <p>
            {offer === 'native'
              ? 'Opens full screen, and makes the browser far less willing to clear your data.'
              : 'In Safari, tap Share then Add to Home Screen. That also protects your data from being cleared.'}
          </p>
        </div>
        {offer === 'native' && (
          <button
            type="button"
            className="minibtn"
            onClick={() => {
              forgetDismissal();
              void promptInstall();
            }}
          >
            Install
          </button>
        )}
      </div>
    </>
  );
}

const PERSIST_COPY: Record<PersistState, { label: string; note: string }> = {
  persisted: {
    label: 'Protected',
    note: 'This device has promised to keep your data until you delete it.',
  },
  'best-effort': {
    label: 'Best effort',
    note: 'The browser may clear your data if it needs space. Installing the app to your home screen usually earns protection — export a backup either way.',
  },
  unsupported: {
    label: 'Unknown',
    note: "This browser won't say whether your data is protected. Export a backup.",
  },
};

function StorageSection() {
  const [state, setState] = useState<PersistState>('unsupported');
  const [usage, setUsage] = useState<StorageUsage | null>(null);

  const refresh = () =>
    Promise.all([persistenceState(), storageUsage()]).then(([s, u]) => {
      setState(s);
      setUsage(u);
    });

  useEffect(() => {
    void refresh();
  }, []);

  const copy = PERSIST_COPY[state];

  return (
    <>
      <div className="seclabel" style={{ marginTop: 28 }}>
        <span>Storage</span>
        <span>{usage ? `${formatBytes(usage.usedBytes)} used` : '—'}</span>
      </div>

      <div className="setrow">
        <div>
          <h4>Data durability — {copy.label}</h4>
          <p>{copy.note}</p>
        </div>
        {state === 'best-effort' && (
          <button
            type="button"
            className="minibtn ghost"
            onClick={() => requestPersistence().then(refresh)}
          >
            Request
          </button>
        )}
      </div>
    </>
  );
}

/** No default, by design — both options destroy something if picked carelessly. */
function RestoreChoice({
  bundle,
  busy,
  onCancel,
  onChoose,
}: {
  bundle: ParsedBundle;
  busy: boolean;
  onCancel: () => void;
  onChoose: (m: RestoreMode) => void;
}) {
  const { counts, exportedAt } = bundle.manifest;

  return (
    <div className="sheet">
      <h4>
        Backup from {exportedAt.slice(0, 10)} — {counts.items} items, {counts.docs} documents,{' '}
        {counts.blobs} files
      </h4>

      <button type="button" className="choice" disabled={busy} onClick={() => onChoose('merge')}>
        <b>Merge</b>
        <span>Keep both. Where the same record exists in each, the newer edit wins.</span>
      </button>

      <button type="button" className="choice" disabled={busy} onClick={() => onChoose('replace')}>
        <b>Replace</b>
        <span>Wipe what's on this phone and restore the backup exactly. For a new device.</span>
      </button>

      <button type="button" className="btn ghost" disabled={busy} onClick={onCancel}>
        Cancel
      </button>
    </div>
  );
}

function describe(r: RestoreResult): string {
  if (r.mode === 'replace') {
    return `Replaced. ${r.added} records and ${r.blobsAdded} files restored.`;
  }
  return `Merged. ${r.added} added, ${r.updated} updated, ${r.skipped} already current.`;
}
