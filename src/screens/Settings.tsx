import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItemCount } from '@/db/repo';
import { FREE_ITEM_LIMIT, type Settings as SettingsRecord } from '@/db/types';
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
import { appUrl, shareApp, shareMessage } from '@/lib/share';
import {
  formatBytes,
  persistenceState,
  requestPersistence,
  storageUsage,
  type PersistState,
  type StorageUsage,
} from '@/lib/storage';

type Notice = { tone: 'ok' | 'bad'; text: string } | null;

/**
 * Settings, grouped by whose question it answers.
 *
 * The old page was one flat run of rows at identical weight — appearance next
 * to backups next to developer toggles — so finding anything meant reading all
 * of it. Now: how it looks, how your home is set up, keeping your data safe,
 * the app itself. Developer is folded away, because it exists for exactly one
 * person and it isn't the one holding the phone.
 */
export function Settings({
  propertyId,
  onOpenRooms,
}: {
  propertyId: string;
  onOpenRooms: () => void;
}) {
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const [notice, setNotice] = useState<Notice>(null);

  if (!settings) return null;

  return (
    <>
      <header className="apphead">
        <div className="apptitle">Settings</div>
      </header>

      {notice && <div className={`notice ${notice.tone}`}>{notice.text}</div>}

      <Appearance settings={settings} />
      <YourHome settings={settings} onOpenRooms={onOpenRooms} />
      <Backup settings={settings} onNotice={setNotice} />
      <StorageCard />
      <AboutApp onNotice={setNotice} schemaVersion={settings.schemaVersion} />
      <Developer settings={settings} propertyId={propertyId} />
    </>
  );
}

/* ------------------------------------------------------------ primitives */

function Card({ title, aside, children }: { title: string; aside?: ReactNode; children: ReactNode }) {
  return (
    <section className="card setcard">
      <div className="cardhead">
        <h3>{title}</h3>
        {aside}
      </div>
      {children}
    </section>
  );
}

/** A labelled row. The control sits right, the explanation under the label. */
function Row({
  label,
  note,
  control,
  onClick,
}: {
  label: string;
  note?: string;
  control?: ReactNode;
  onClick?: () => void;
}) {
  const body = (
    <>
      <span className="setrow-txt">
        <strong>{label}</strong>
        {note && <small>{note}</small>}
      </span>
      {control}
    </>
  );

  return onClick ? (
    <button type="button" className="setrow tappable" onClick={onClick}>
      {body}
      <Chevron />
    </button>
  ) : (
    <div className="setrow">{body}</div>
  );
}

function Toggle({
  on,
  label,
  onChange,
}: {
  on: boolean;
  label: string;
  onChange: (next: boolean) => void;
}) {
  return (
    <button
      type="button"
      className={`toggle${on ? ' on' : ''}`}
      role="switch"
      aria-checked={on}
      aria-label={label}
      data-cue="none"
      onClick={() => onChange(!on)}
    >
      <span />
    </button>
  );
}

function Pick<T extends string | number>({
  value,
  label,
  options,
  onChange,
}: {
  value: T;
  label: string;
  options: { value: T; label: string }[];
  onChange: (v: string) => void;
}) {
  return (
    <select
      className="compact"
      value={value}
      aria-label={label}
      onChange={(e) => onChange(e.target.value)}
    >
      {options.map((o) => (
        <option key={o.value} value={o.value}>
          {o.label}
        </option>
      ))}
    </select>
  );
}

function Chevron() {
  return (
    <svg
      className="rowgo"
      width="17"
      height="17"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.4"
      strokeLinecap="round"
      aria-hidden="true"
    >
      <path d="M9 5l7 7-7 7" />
    </svg>
  );
}

/* ------------------------------------------------------------ appearance */

const THEMES: { value: ThemeChoice; label: string }[] = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'system', label: 'Auto' },
];

function Appearance({ settings }: { settings: SettingsRecord }) {
  const prefs = prefsFrom(settings);
  const canBuzz = hapticsSupported();

  return (
    <Card title="Appearance">
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

      <Row
        label="Sounds"
        note="Clicks as you tap, and short tones when something saves."
        control={
          <Toggle
            on={prefs.sounds}
            label="Sounds"
            onChange={(next) => {
              setPref('sounds', next);
              if (next) previewCue('save', { sounds: true, haptics: false });
            }}
          />
        }
      />

      <Row
        label="Haptics"
        note={
          canBuzz
            ? 'A gentle tick as you tap, firmer when something saves or is deleted.'
            : 'This browser has no vibration support, so this does nothing here.'
        }
        control={
          <Toggle
            on={prefs.haptics}
            label="Haptics"
            onChange={(next) => {
              setPref('haptics', next);
              if (next) previewCue('save', { sounds: false, haptics: true });
            }}
          />
        }
      />
    </Card>
  );
}

/* -------------------------------------------------------------- the home */

function YourHome({
  settings,
  onOpenRooms,
}: {
  settings: SettingsRecord;
  onOpenRooms: () => void;
}) {
  return (
    <Card title="Your home">
      <Row
        label="Rooms"
        note="Add, rename and reorder the rooms items live in."
        onClick={onOpenRooms}
      />

      <Row
        label="Items open"
        note="Whether rooms start shut or already showing what's inside."
        control={
          <Pick
            value={prefsFrom(settings).roomsView}
            label="How the Items list opens"
            options={[
              { value: 'collapsed', label: 'Collapsed' },
              { value: 'expanded', label: 'Expanded' },
            ]}
            onChange={(v) => setPref('roomsView', v as RoomsView)}
          />
        }
      />

      <Row
        label="Currency"
        note="Used for new items. Each item keeps what it was saved with."
        control={
          <Pick
            value={settings.currency}
            label="Default currency"
            options={[...new Set([settings.currency, ...CURRENCIES])].map((c) => ({
              value: c,
              label: c,
            }))}
            onChange={(v) => db.settings.update('singleton', { currency: v })}
          />
        }
      />

      <Row
        label="Warn me before a warranty ends"
        note="How much notice you want on the home screen."
        control={
          <Pick
            value={settings.reminderOffsetsDays[0] ?? 30}
            label="Warranty warning lead time"
            options={REMINDER_CHOICES.map((r) => ({ value: r.days, label: r.label }))}
            onChange={(v) =>
              db.settings.update('singleton', { reminderOffsetsDays: [Number(v)] })
            }
          />
        }
      />
    </Card>
  );
}

/* ---------------------------------------------------------------- backup */

function Backup({
  settings,
  onNotice,
}: {
  settings: SettingsRecord;
  onNotice: (n: Notice) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState<ParsedBundle | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const run = async (fn: () => Promise<unknown>) => {
    setBusy(true);
    onNotice(null);
    try {
      await fn();
    } catch (e) {
      feedback('error');
      onNotice({
        tone: 'bad',
        text: e instanceof BundleError ? e.message : `Something went wrong: ${(e as Error).message}`,
      });
    } finally {
      setBusy(false);
    }
  };

  const last = settings.lastBackupAt;

  return (
    <Card
      title="Backup"
      aside={<span className="countpill">{last ? last.slice(0, 10) : 'Never'}</span>}
    >
      {/* The export is the most consequential button on the screen, so it gets
          the full-width treatment rather than being a control at the end of a
          row of explanation. */}
      <button
        type="button"
        className="btn wide"
        disabled={busy}
        onClick={() =>
          run(async () => {
            const { blob, filename } = await exportBundle();
            const how = await saveBundle(blob, filename);
            feedback('save');
            onNotice({
              tone: 'ok',
              text: how === 'shared' ? `Shared ${filename}.` : `Saved ${filename}.`,
            });
          })
        }
      >
        Export everything
      </button>
      <p className="hint">
        One file with every item, document and photo. Nothing leaves this device on its own, so
        this is the only copy that survives losing the phone.
      </p>

      <Row
        label="Restore from a backup"
        note="You'll choose how it merges before anything changes."
        control={
          <button
            type="button"
            className="minibtn ghost"
            disabled={busy}
            onClick={() => fileInput.current?.click()}
          >
            Choose file
          </button>
        }
      />

      <Row
        label="Remind me"
        note="A nudge to export, since nothing syncs anywhere."
        control={
          <Pick
            value={settings.backupReminderDays}
            label="Backup reminder frequency"
            options={BACKUP_REMINDER_CHOICES.map((b) => ({ value: b.days, label: b.label }))}
            onChange={(v) => db.settings.update('singleton', { backupReminderDays: Number(v) })}
          />
        }
      />

      <input
        ref={fileInput}
        type="file"
        accept=".stashit,application/zip"
        hidden
        onChange={(e) => {
          const file = e.target.files?.[0];
          e.target.value = '';
          if (file) run(async () => setPending(await parseBundle(file)));
        }}
      />

      {pending && (
        <RestoreChoice
          bundle={pending}
          busy={busy}
          onCancel={() => setPending(null)}
          onChoose={(mode) =>
            run(async () => {
              const r = await restoreBundle(pending, mode);
              feedback('save');
              setPending(null);
              onNotice({ tone: 'ok', text: describe(r) });
            })
          }
        />
      )}
    </Card>
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

/* --------------------------------------------------------------- storage */

const PERSIST_COPY: Record<PersistState, { label: string; note: string }> = {
  persisted: {
    label: 'Protected',
    note: 'This device has promised to keep your data until you delete it.',
  },
  'best-effort': {
    label: 'Best effort',
    note: 'The browser may clear your data if it needs space. Installing usually earns protection.',
  },
  unsupported: {
    label: 'Unknown',
    note: "This browser won't say whether your data is protected. Keep a backup.",
  },
};

function StorageCard() {
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
    <Card
      title="Storage"
      aside={usage ? <span className="countpill">{formatBytes(usage.usedBytes)}</span> : undefined}
    >
      <Row
        label={copy.label}
        note={copy.note}
        control={
          state === 'best-effort' ? (
            <button
              type="button"
              className="minibtn ghost"
              onClick={() => requestPersistence().then(refresh)}
            >
              Request
            </button>
          ) : undefined
        }
      />
    </Card>
  );
}

/* ------------------------------------------------------------- the app */

function AboutApp({
  onNotice,
  schemaVersion,
}: {
  onNotice: (n: Notice) => void;
  schemaVersion: number;
}) {
  const url = appUrl();
  const installed = isStandalone();
  const offer = installOfferIgnoringDismissal({
    standalone: installed,
    dismissed: false,
    nativePrompt: hasNativePrompt(),
    iosSafari: isIOSSafari(),
  });

  return (
    <Card title="Stash it" aside={<span className="countpill">v{__APP_VERSION__}</span>}>
      {installed ? (
        <Row
          label="Installed"
          note="Which is also what earns your data the browser's strongest storage promise."
        />
      ) : offer !== 'none' ? (
        <Row
          label="Add to home screen"
          note={
            offer === 'native'
              ? 'Opens full screen, and makes the browser far less willing to clear your data.'
              : 'In Safari, tap Share then Add to Home Screen. That also protects your data.'
          }
          control={
            offer === 'native' ? (
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
            ) : undefined
          }
        />
      ) : null}

      <Row
        label="Share Stash it"
        note="There's no account to sign up for, so it's just an address."
        control={
          <button
            type="button"
            className="minibtn ghost"
            data-cue="none"
            onClick={async () => {
              const outcome = await shareApp(url);
              feedback(outcome === 'cancelled' ? 'tap' : 'save');
              const text = shareMessage(outcome, url);
              onNotice(text ? { tone: 'ok', text } : null);
            }}
          >
            Share
          </button>
        }
      />

      <p className="hint">
        Everything you add stays on this device. Data schema v{schemaVersion} — worth knowing if a
        backup ever refuses to restore.
      </p>
    </Card>
  );
}

/* ------------------------------------------------------------- developer */

/**
 * Folded away by default. It exists for exactly one person, and it isn't the
 * one holding the phone — but it's the only way to exercise the paywall and
 * populate a screen without typing, so it stays reachable.
 */
function Developer({ settings, propertyId }: { settings: SettingsRecord; propertyId: string }) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const count = useLiveQuery(() => activeItemCount(propertyId), [propertyId]) ?? 0;

  const run = (fn: () => Promise<unknown>) => {
    setBusy(true);
    void fn().finally(() => setBusy(false));
  };

  if (!open) {
    return (
      <button
        type="button"
        className="expander"
        aria-expanded={false}
        onClick={() => setOpen(true)}
      >
        Developer
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
        >
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>
    );
  }

  return (
    <Card
      title="Developer"
      aside={
        <button type="button" className="linkish" aria-expanded onClick={() => setOpen(false)}>
          Hide
        </button>
      }
    >
      <Row
        label="Pro unlock"
        note={`Lifts the ${FREE_ITEM_LIMIT}-item cap. Currently ${count} ${count === 1 ? 'item' : 'items'}.`}
        control={
          <Toggle
            on={settings.entitlements.proUnlock}
            label="Pro unlock"
            onChange={(proUnlock) =>
              db.settings.update('singleton', {
                entitlements: { ...settings.entitlements, proUnlock },
              })
            }
          />
        }
      />

      <Row
        label="Demo items"
        note="Four fixtures dated to land on covered, ending soon and expired."
        control={
          <span className="setactions">
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
          </span>
        }
      />
    </Card>
  );
}
