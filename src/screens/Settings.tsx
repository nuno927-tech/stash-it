import { useEffect, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, nowISO } from '@/db/db';
import { pushBack } from '@/lib/backstack';
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
import { money, monthlyDue, TIERS, venmoUrl } from '@/lib/donate';
import { feedback, hapticsSupported, previewCue } from '@/lib/feedback';
import { cleanName, MAX_NAME_LENGTH } from '@/lib/greeting';
import {
  hasNativePrompt,
  installOffer,
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
import { ScoutGallery } from '@/components/ScoutGallery';
import { Scout } from '@/components/Scout';

type Notice = { tone: 'ok' | 'bad'; text: string } | null;

/**
 * Enough taps that nobody arrives by accident, few enough that someone who
 * suspects there's something there will keep going. The gap rule in `tap`
 * means they have to be deliberate and continuous.
 */
const EGG_TAPS = 25;

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
  onTour,
}: {
  propertyId: string;
  onOpenRooms: () => void;
  onTour: () => void;
}) {
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const [notice, setNotice] = useState<Notice>(null);
  const [taps, setTaps] = useState<TapState>(NO_TAPS);
  const [pending, setPending] = useState<ParsedBundle | null>(null);
  const [eggTaps, setEggTaps] = useState<TapState>(NO_TAPS);
  const [album, setAlbum] = useState(false);

  if (!settings) return null;

  return (
    <>
      <header className="apphead">
        {/*
          Twenty-five taps opens Scout's album. It looks and reads as the
          heading it is — an easter egg that announces itself is a feature
          with a silly name.
        */}
        <button
          type="button"
          className="apptitle titletap"
          data-cue="none"
          onClick={() => {
            const next = tap(eggTaps, Date.now());
            setEggTaps(next);
            if (next.count >= EGG_TAPS) {
              setEggTaps(NO_TAPS);
              setAlbum(true);
            }
          }}
        >
          Settings
        </button>
      </header>

      {album && <ScoutGallery onClose={() => setAlbum(false)} />}

      {/* His own card rather than a decoration in the header. It's the one
          screen that's entirely about adjusting things, and he's at a control
          desk doing exactly that. */}
      <div className="card scoutcard">
        <p>Everything below changes how Stash it behaves. Nothing here leaves the device.</p>
        <Scout pose="settings" height={110} motion={['breathe']} alt="" />
      </div>

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
        onTour={onTour}
      />
      <Support settings={settings} />
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

/**
 * Merge or replace, asked as a dialog.
 *
 * It used to appear as another block at the bottom of the Backup card, below
 * the fold on most phones — you picked a file, the screen appeared not to
 * react, and the question you now had to answer was somewhere further down. A
 * choice this consequential has to arrive in front of you.
 *
 * No default, by design: both options destroy something if picked carelessly,
 * and there is no third option that means "do the safe thing".
 */
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

  useEffect(() => pushBack(onCancel), [onCancel]);

  return createPortal(
    <div className="sheetscrim" role="dialog" aria-modal="true" aria-labelledby="restore-title">
      <div className="sheetcard" onClick={(e) => e.stopPropagation()}>
        <h4 id="restore-title">Restore this backup?</h4>
        <p className="hint" style={{ textAlign: 'center', marginBottom: 16 }}>
          From {exportedAt.slice(0, 10)} — {counts.items} items, {counts.docs} documents,{' '}
          {counts.blobs} files.
        </p>

        <button type="button" className="choice" disabled={busy} onClick={() => onChoose('merge')}>
          <span className="choice-txt">
            <b>Merge</b>
            <span>Keep both. Where the same record exists in each, the newer edit wins.</span>
          </span>
        </button>

        <button
          type="button"
          className="choice danger"
          disabled={busy}
          onClick={() => onChoose('replace')}
        >
          <span className="choice-txt">
            <b>Replace</b>
            <span>Wipe what's on this phone and restore the backup exactly. For a new device.</span>
          </span>
        </button>

        <button type="button" className="btn ghost" disabled={busy} onClick={onCancel}>
          Cancel
        </button>
      </div>
    </div>,
    document.body,
  );
}

function describe(r: RestoreResult): string {
  if (r.mode === 'replace') {
    return `Replaced. ${r.added} records and ${r.blobsAdded} files restored.`;
  }
  return `Merged. ${r.added} added, ${r.updated} updated, ${r.skipped} already current.`;
}


/* --------------------------------------------------------------- support */

/**
 * The tip jar.
 *
 * Below everything functional and above nothing, because it's the one card
 * that asks rather than offers. Four amounts with plain descriptions instead
 * of a number field: naming what the money buys is easier to say yes to than
 * being asked to value someone's work on the spot.
 *
 * The link opens Venmo with the amount and note already filled in. Nothing
 * about the payment passes through this app — there's no integration to have,
 * which is also why the monthly option is a reminder rather than a standing
 * order. See src/lib/donate.ts.
 */
function Support({ settings }: { settings: SettingsRecord }) {
  const [picked, setPicked] = useState(TIERS[1]!);
  const monthly = settings.donateMonthly ?? false;
  const due = monthlyDue(settings.donateLastAt);

  const send = () => {
    feedback('save');
    void db.settings.update('singleton', { donateLastAt: nowISO() });
  };

  return (
    <section className="card supportcard">
      {/* Across the top rather than beside the text: this pose is wide, and
          squeezed into a column it becomes a small piece of furniture with a
          squirrel somewhere in it. */}
      <div className="supporthead">
        <Scout pose="lounge" height={136} motion={['breathe']} alt="" />
        <h3>Buy Scout a drink</h3>
        <p>
          Stash it is free, has no ads and sells nothing. If it saved you a warranty, you can say
          so.
        </p>
      </div>

      {monthly && due && (
        <p className="hint warnhint">It's been a month since the last one, if you still want to.</p>
      )}

      <div className="tiers">
        {TIERS.map((t) => (
          <button
            key={t.amount}
            type="button"
            className={`tier${picked.amount === t.amount ? ' on' : ''}`}
            aria-pressed={picked.amount === t.amount}
            onClick={() => setPicked(t)}
          >
            <b>{money(t.amount)}</b>
            <span>{t.label}</span>
          </button>
        ))}
      </div>

      <Row
        label="Make it monthly"
        note="Venmo can't schedule a payment from a link, so Stash it will remind you instead."
        control={
          <Toggle
            on={monthly}
            label="Make it monthly"
            onChange={(next) =>
              db.settings.update('singleton', {
                donateMonthly: next,
                donateLastAt: next ? (settings.donateLastAt ?? nowISO()) : undefined,
              })
            }
          />
        }
      />

      {/* An anchor, not a button: it leaves the app, and the long-press menu
          that gives — copy the link, open in a new tab — is worth keeping. */}
      <a
        className="btn wide"
        href={venmoUrl({ amount: picked.amount, note: picked.note, monthly })}
        target="_blank"
        rel="noreferrer"
        onClick={send}
      >
        <VenmoGlyph />
        Send {money(picked.amount)} on Venmo
      </a>

      <p className="hint">
        Opens Venmo with the amount filled in — you confirm it there. Marked private, so it doesn't
        appear in anyone's feed.
      </p>
    </section>
  );
}

function VenmoGlyph() {
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
      <path d="M3 7.5h18v11a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18.5z" />
      <path d="M3 7.5 7 4h10l4 3.5M8 12h4" />
    </svg>
  );
}

/* ------------------------------------------------------------- the app */

function AboutApp({
  onNotice,
  taps,
  onTapVersion,
  onTour,
}: {
  onNotice: (n: Notice) => void;
  taps: TapState;
  onTapVersion: () => void;
  onTour: () => void;
}) {
  const url = appUrl();
  // `settled` is true here on purpose: by the time someone is reading
  // Settings, the browser has long since decided whether it will offer a
  // button, and the written steps are better than an empty space.
  const offer = installOffer({
    standalone: isStandalone(),
    nativePrompt: hasNativePrompt(),
    iosSafari: isIOSSafari(),
    android: isAndroid(),
    settled: true,
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
              : offer === 'ios'
                ? 'In Safari, tap Share then Add to Home Screen. That also protects your data.'
                : 'From the browser menu, choose Add to Home screen. That also protects your data.'
          }
          control={
            offer === 'native' ? (
              <button type="button" className="minibtn" onClick={() => void promptInstall()}>
                Install
              </button>
            ) : undefined
          }
        />
      )}

      <Row
        label="Take the tour"
        note="Six short screens on what the app does. Nothing changes by watching it."
        onClick={onTour}
      />

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
