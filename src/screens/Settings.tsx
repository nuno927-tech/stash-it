import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeItemCount } from '@/db/repo';
import { FREE_ITEM_LIMIT, type Settings as SettingsRecord } from '@/db/types';
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
import { NO_TAPS, tap, tapHint, unlocked, type TapState } from '@/lib/devmode';
import { feedback, hapticsSupported, previewCue } from '@/lib/feedback';
import { cleanName, MAX_NAME_LENGTH } from '@/lib/greeting';
import {
  forgetDismissal,
  hasNativePrompt,
  installOfferIgnoringDismissal,
  isAndroid,
  isIOSSafari,
  isStandalone,
  promptInstall,
} from '@/lib/install';
import {
  biometricsAvailable,
  canOfferLock,
  clearLock,
  enrolBiometrics,
  saveLock,
} from '@/lib/lock';
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
import { formatBytes, storageUsage, type StorageUsage } from '@/lib/storage';
import { DriveCard } from '@/components/DriveCard';

type Notice = { tone: 'ok' | 'bad'; text: string } | null;

/**
 * Settings, grouped by whose question it answers.
 *
 * The old page was one flat run of rows at identical weight — appearance next
 * to backups next to developer toggles — so finding anything meant reading all
 * of it. Now: how it looks, how your home is set up, keeping your data safe,
 * the app itself. Developer isn't on the page at all until you ask for it by
 * tapping the version pill ten times.
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
  const [taps, setTaps] = useState<TapState>(NO_TAPS);
  const [pending, setPending] = useState<ParsedBundle | null>(null);

  if (!settings) return null;

  return (
    <>
      <header className="apphead">
        <div className="apptitle">Settings</div>
      </header>

      {notice && <div className={`notice ${notice.tone}`}>{notice.text}</div>}

      <Appearance settings={settings} />
      <LockCard settings={settings} onNotice={setNotice} />
      <YourHome settings={settings} onOpenRooms={onOpenRooms} />
      <Backup
        settings={settings}
        onNotice={setNotice}
        pending={pending}
        setPending={setPending}
      />
      <DriveCard settings={settings} onNotice={setNotice} onRestore={setPending} />
      <AboutApp
        onNotice={setNotice}
        taps={taps}
        onTapVersion={() => setTaps((t) => tap(t, Date.now()))}
      />
      {unlocked(taps) && (
        <Developer
          settings={settings}
          propertyId={propertyId}
          onHide={() => setTaps(NO_TAPS)}
        />
      )}
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
  stacked,
}: {
  label: string;
  note?: string;
  control?: ReactNode;
  onClick?: () => void;
  /** Puts the control on its own line. For anything you type into. */
  stacked?: boolean;
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
    <div className={`setrow${stacked ? ' setfield' : ''}`}>{body}</div>
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

/* ------------------------------------------------------------------ lock */

/**
 * The switch, and the truth about what it does.
 *
 * The note says "locks the app" rather than "protects your data", because
 * WebAuthn authenticates and does not encrypt: the database is readable to
 * anyone with the phone, a cable and a devtools window either way. Overstating
 * it would be the kind of promise someone plans around.
 */
function LockCard({
  settings,
  onNotice,
}: {
  settings: SettingsRecord;
  onNotice: (n: Notice) => void;
}) {
  const [available, setAvailable] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const on = prefsFrom(settings).biometricLock;

  useEffect(() => {
    void biometricsAvailable().then(setAvailable);
  }, []);

  // Nothing to offer on a device with no sensor, and a dead switch invites the
  // question "why won't this work" rather than answering it.
  if (available === null || !canOfferLock(available)) return null;

  const toggle = async (next: boolean) => {
    setBusy(true);
    onNotice(null);
    try {
      if (!next) {
        await clearLock();
        feedback('delete');
        return;
      }
      const id = await enrolBiometrics();
      if (!id) {
        feedback('error');
        onNotice({ tone: 'bad', text: 'The device did not confirm. The lock is still off.' });
        return;
      }
      await saveLock(id);
      feedback('save');
      onNotice({ tone: 'ok', text: 'Locked. You will be asked next time the app opens.' });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card title="Lock">
      <Row
        label="Unlock with biometrics"
        note="Ask for your fingerprint or face before the app opens."
        control={
          <Toggle
            on={on}
            label="Unlock with biometrics"
            onChange={(next) => {
              if (!busy) void toggle(next);
            }}
          />
        }
      />
      <p className="hint">
        This locks the app, not the data. What you've saved is stored unencrypted, the way every
        browser database is — so the lock stops someone picking up your phone, not someone with
        your phone and a laptop.
      </p>
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
      {/* Used in exactly one place — the greeting on the dashboard — so the
          note says so rather than implying an account exists. */}
      <Row
        label="Your name"
        note="What the dashboard calls you. Leave it empty for a plain greeting."
        stacked
        control={
          <input
            type="text"
            className="setinput"
            defaultValue={prefsFrom(settings).displayName}
            placeholder="Name"
            aria-label="Your name"
            maxLength={MAX_NAME_LENGTH}
            enterKeyHint="done"
            // On blur, not on every keystroke: a write per character is a
            // write per character, and the greeting has no reason to flicker
            // through half-typed names.
            onBlur={(e) => void setPref('displayName', cleanName(e.target.value))}
            onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()}
          />
        }
      />

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
  pending,
  setPending,
}: {
  settings: SettingsRecord;
  onNotice: (n: Notice) => void;
  /* Lifted, because a bundle can now arrive from the file picker or from
     Drive, and both must land in the same merge-or-replace decision. */
  pending: ParsedBundle | null;
  setPending: (b: ParsedBundle | null) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [usage, setUsage] = useState<StorageUsage | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  // How much there is to lose belongs next to the thing that saves it, not in
  // a card of its own.
  useEffect(() => {
    void storageUsage().then(setUsage);
  }, []);

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

      {usage && (
        <Row
          label="On this device"
          note="Items, documents and photos, as they sit in the browser's storage."
          control={<span className="setval">{formatBytes(usage.usedBytes)}</span>}
        />
      )}

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

/* ------------------------------------------------------------- the app */

function AboutApp({
  onNotice,
  taps,
  onTapVersion,
}: {
  onNotice: (n: Notice) => void;
  taps: TapState;
  onTapVersion: () => void;
}) {
  const url = appUrl();
  const offer = installOfferIgnoringDismissal({
    standalone: isStandalone(),
    dismissed: false,
    nativePrompt: hasNativePrompt(),
    iosSafari: isIOSSafari(),
  });
  const hint = tapHint(taps);

  return (
    <Card
      title="Stash it"
      aside={
        /* Ten taps here reveals the developer card. Nothing about the pill
           advertises that, which is the point. */
        <button type="button" className="countpill tappill" data-cue="none" onClick={onTapVersion}>
          {hint ?? `v${__APP_VERSION__}`}
        </button>
      }
    >
      {offer !== 'none' && (
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
      )}

      {/* A share target is invisible: nothing in the app hints that Stash it
          is now in the Android share sheet, and nobody goes looking. One line
          here is the only place it can be said. */}
      <Row
        label="Import from email"
        note={
          isAndroid()
            ? 'Open a receipt in your mail app, tap Share, choose Stash it. The attachment and what it says get filled into a new item.'
            : 'On Android, receipts can be shared straight from the mail app. On this device, save the attachment and add it to an item.'
        }
      />

      <button
        type="button"
        className="btn wide"
        data-cue="none"
        onClick={async () => {
          const outcome = await shareApp(url);
          feedback(outcome === 'cancelled' ? 'tap' : 'save');
          const text = shareMessage(outcome, url);
          onNotice(text ? { tone: 'ok', text } : null);
        }}
      >
        <ShareGlyph />
        Share Stash it
      </button>
    </Card>
  );
}

function ShareGlyph() {
  return (
    <svg
      width="17"
      height="17"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M12 15V3.5M12 3.5L8 7.5M12 3.5l4 4" />
      <path d="M5 13v6.5a1 1 0 001 1h12a1 1 0 001-1V13" />
    </svg>
  );
}

/* ------------------------------------------------------------- developer */

/**
 * Off the page entirely until the version pill is tapped ten times. A switch
 * that lifts the item cap shouldn't be one stray thumb from someone's theme
 * setting, but it's still the only way to exercise the paywall.
 */
function Developer({
  settings,
  propertyId,
  onHide,
}: {
  settings: SettingsRecord;
  propertyId: string;
  onHide: () => void;
}) {
  const count = useLiveQuery(() => activeItemCount(propertyId), [propertyId]) ?? 0;

  return (
    <Card
      title="Developer"
      aside={
        <button type="button" className="linkish" onClick={onHide}>
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
    </Card>
  );
}
