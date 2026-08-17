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
import { contactUrl, platformWord, type ContactKind } from '@/lib/contact';
import { cleanName, MAX_NAME_LENGTH } from '@/lib/greeting';
import { armNudgePreview } from '@/lib/nudges';
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
import { getEndingSoonDays } from '@/lib/warranty';
import { DriveCard } from '@/components/DriveCard';
import { ScoutGallery } from '@/components/ScoutGallery';
import { Scout } from '@/components/Scout';

type Notice = { tone: 'ok' | 'bad'; text: string } | null;

/**
 * Enough taps that nobody arrives by accident, few enough that someone who
 * suspects there's something there will keep going. The gap rule in `tap`
 * means they have to be deliberate and continuous.
 *
 * Twenty-five was too many — long enough that anyone who hadn't been told it
 * was there would give up before finding it, which makes it not an easter egg
 * but a secret. Ten is the same count the version pill uses for the developer
 * tools; different target, so nothing collides.
 */
const EGG_TAPS = 10;

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
  onHome,
}: {
  propertyId: string;
  onOpenRooms: () => void;
  onTour: () => void;
  onHome: () => void;
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
      {/*
        Title and its explanation as one block, with Scout beside them.

        The subtitle used to sit under a full-width header with the mascot in
        its own row below — three stacked things saying "this is Settings"
        before the first control. As a masthead it's one thing: the words on
        the left in reading order, Scout on the right at a size that earns the
        space he takes.
      */}
      <div className="masthead">
        <div className="masthead-txt">
          {/*
            Ten taps opens Scout's album. It looks and reads as the heading it
            is — an easter egg that announces itself is a feature with a silly
            name.
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
          <p>Everything below changes how Stash it behaves. Nothing here leaves the device.</p>
        </div>

        <Scout pose="settings" height={132} motion={['breathe']} alt="" />
      </div>

      {album && <ScoutGallery onClose={() => setAlbum(false)} />}

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
      <AboutApp onNotice={setNotice} onTour={onTour} />
      <Support settings={settings} />

      {/* The version, last, in a card of its own. It's a fact about the build
          rather than a setting, and it was riding on the About card's header
          where it read as that card's badge. Ten taps still opens the
          developer tools; nothing about it advertises that. */}
      <VersionCard taps={taps} onTap={() => setTaps((t) => tap(t, Date.now()))} />

      {/* Drive lives here rather than beside the file backup. It needs an OAuth
          client ID pasted in before it does anything, which makes it a thing
          for whoever is building the app, not a setting for whoever is using
          it. Hidden with the rest of the developer tools until the version
          pill has been tapped ten times. */}
      {unlocked(taps) && (
        <>
          <Developer
            settings={settings}
            propertyId={propertyId}
            onHide={() => setTaps(NO_TAPS)}
            onHome={onHome}
          />
          <DriveCard settings={settings} onNotice={setNotice} onRestore={setPending} />
        </>
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

/**
 * A setting whose options are few enough to show all at once.
 *
 * A dropdown hides every choice but the current one behind a tap and a native
 * picker; with four or five short options there's no reason for either. The
 * label sits above rather than beside, because a segmented control needs the
 * full width of the card and a control that wide next to a label is a control
 * squeezed into whatever's left.
 */
function SegRow<T extends string | number>({
  label,
  note,
  value,
  options,
  onChange,
}: {
  label: string;
  note?: string;
  value: T;
  options: { value: T; label: string }[];
  onChange: (v: T) => void;
}) {
  return (
    <div className="segrow">
      <span className="setrow-txt">
        <strong>{label}</strong>
        {note && <small>{note}</small>}
      </span>
      <div className={`seg${options.length >= 5 ? ' five' : ''}`} role="group" aria-label={label}>
        {options.map((o) => (
          <button
            key={o.value}
            type="button"
            className={value === o.value ? 'on' : ''}
            aria-pressed={value === o.value}
            onClick={() => onChange(o.value)}
          >
            {o.label}
          </button>
        ))}
      </div>
    </div>
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
        control={
          <input
            type="text"
            className="setinput compact"
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

      <SegRow
        label="Items open"
        note="Whether rooms start shut or already showing what's inside."
        value={prefsFrom(settings).roomsView}
        options={[
          { value: 'collapsed', label: 'Collapsed' },
          { value: 'expanded', label: 'Expanded' },
        ]}
        onChange={(v) => setPref('roomsView', v as RoomsView)}
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

      <SegRow
        label="Warn me before a warranty ends"
        note="How much notice you want on the home screen."
        value={settings.reminderOffsetsDays[0] ?? 30}
        options={REMINDER_CHOICES.map((r) => ({ value: r.days, label: r.label }))}
        onChange={(days) => db.settings.update('singleton', { reminderOffsetsDays: [days] })}
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
      {/* The reminder leads. It's the only setting in the card — the other two
          controls are actions — and it's the one that decides whether the
          actions ever get used. As a dropdown at the bottom it was a footnote
          to two buttons; as a segmented row at the top it's the question the
          card is really asking. */}
      <p className="hint remindhint">
        Nothing syncs anywhere, so a backup only exists if you make one. How
        often should Scout nudge you?
      </p>
      <div className="seg four">
        {BACKUP_REMINDER_CHOICES.map((b) => (
          <button
            key={b.days}
            type="button"
            className={settings.backupReminderDays === b.days ? 'on' : ''}
            onClick={() => db.settings.update('singleton', { backupReminderDays: b.days })}
          >
            {b.label}
          </button>
        ))}
      </div>

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
        {/* The size rides on the button rather than sitting in a row of its
            own further down. "How much am I about to write out" is a fact
            about this action, and it was being reported as if it were a
            separate setting. */}
        Export everything
        {usage && <span className="btnnote">{formatBytes(usage.usedBytes)}</span>}
      </button>
      <p className="hint">
        One file with every item, document and photo. Nothing leaves this device on its own, so
        this is the only copy that survives losing the phone.
      </p>

      {/* Restoring is the other half of the same job, so it gets the same
          button — gold, not the ghost outline it had. Two halves of one pair
          drawn at different weights implied one of them was the safe,
          secondary option, and if anything the reverse is true: export writes
          a file, import can replace everything you own. The merge-or-replace
          dialog is where that gets its warning, not the button that opens a
          file picker. */}
      <button
        type="button"
        className="btn wide"
        disabled={busy}
        onClick={() => fileInput.current?.click()}
      >
        Import from a backup
      </button>
      <p className="hint">You'll choose how it merges before anything changes.</p>

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
  onTour,
}: {
  onNotice: (n: Notice) => void;
  onTour: () => void;
}) {
  const url = appUrl();

  const writeIn = (kind: ContactKind) => {
    feedback('tap');
    // location, not window.open: a mailto in a new tab leaves an empty tab
    // behind on desktop once the mail client takes over.
    window.location.href = contactUrl(kind, {
      version: __APP_VERSION__,
      standalone: isStandalone(),
      platform: platformWord(),
    });
  };
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

  return (
    <Card title="Stash it">
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

      {/*
        A mailto, not a form. A form needs somewhere to post to and this app
        has no server — so the mail app the user already has is the only piece
        of infrastructure that's certain to exist. It also means they see the
        whole message, context line included, before anything is sent.
      */}
      <Row
        label="Ask a question"
        note="Opens your mail app, addressed and with the version filled in."
        onClick={() => writeIn('question')}
      />

      <Row
        label="Suggest a feature"
        note="What should it do that it doesn't? Every version so far came from someone asking."
        onClick={() => writeIn('idea')}
      />

      <Row
        label="Report something broken"
        note="What happened, and what you expected instead."
        onClick={() => writeIn('bug')}
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

/**
 * The build, and the way into the developer tools.
 *
 * Its own card at the foot of the page. As a pill in the About card's header
 * it read as a badge on that card — and it isn't a setting at all, it's a fact
 * about what you're running, which is the sort of thing that belongs at the
 * bottom next to nothing else.
 */
function VersionCard({ taps, onTap }: { taps: TapState; onTap: () => void }) {
  const hint = tapHint(taps);

  return (
    <section className="card versioncard">
      <button type="button" className="tappill" data-cue="none" onClick={onTap}>
        Stash it <span>v{__APP_VERSION__}</span>
      </button>
      <p>{hint ?? 'Everything you own, on your own phone.'}</p>
    </section>
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
  onHome,
}: {
  settings: SettingsRecord;
  propertyId: string;
  onHide: () => void;
  /** The preview belongs on the dashboard, so the button has to go there. */
  onHome: () => void;
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

      {/*
        Every reminder this app has, shown where it actually appears.

        None of them is a push notification — there's no server to send one and
        nothing running while the app is shut, so a reminder is a card on the
        dashboard the next time you open it. Each real one is gated behind a
        date: the backup waits for the interval to lapse, the tip waits a
        month, so without this you'd wait weeks to see whether the copy reads
        well.

        This used to draw the samples right here, under the button. They looked
        fine — and told you nothing, because a reminder is a card in a
        particular place competing with the greeting and the ring for the same
        glance. So the button arms a flag and takes you to the dashboard, and
        leaving the dashboard clears it.
      */}
      <Row
        label="Preview the reminders"
        note="Puts the backup, warranty and tip cards on the dashboard as samples. Leaving the dashboard clears them; nothing is saved."
        control={
          <button
            type="button"
            className="minibtn ghost"
            onClick={() => {
              armNudgePreview();
              feedback('nav');
              onHome();
            }}
          >
            Show on Home
          </button>
        }
      />

      <Row
        label="Warning threshold"
        note={`"Ending soon" means ${getEndingSoonDays()} days or less right now — the value set by "Warn me before a warranty ends".`}
      />
    </Card>
  );
}
