import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, nowISO } from '@/db/db';
import { pushBack } from '@/lib/backstack';
import { cappedCount } from '@/db/repo';
import { FREE_ITEM_LIMIT, type Settings as SettingsRecord } from '@/db/types';
import {
  BundleError,
  canShareBundle,
  exportBundle,
  markBackedUp,
  parseBundle,
  restoreBundle,
  saveBundle,
  type ParsedBundle,
  type RestoreMode,
  type RestoreResult,
} from '@/lib/backup';
import {
  NO_TAPS,
  readUnlocked,
  rememberUnlocked,
  tap,
  tapHint,
  unlocked,
  type TapState,
} from '@/lib/devmode';
import {
  PING_COPY,
  diagnose,
  notifyNow,
  pingNow,
  restoreSchedule,
  stageToday,
  type PushDiagnosis,
} from '@/lib/pushDev';
import {
  TIP_DUE_COPY,
  donationDue,
  money,
  TIERS,
  venmoUrl,
  YEARLY_AMOUNT,
  type TipCadence,
} from '@/lib/donate';
import { RunningCosts } from '@/components/RunningCosts';
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
import { VERDICT_COPY, wakeDates, type Wake } from '@/lib/push';
import {
  disablePush,
  enablePush,
  plannedWakes,
  previewSchedule,
  pushVerdict,
  refreshNotes,
  senderConfigured,
  syncSchedule,
} from '@/lib/pushClient';
import { appUrl, shareApp, shareMessage } from '@/lib/share';
import { formatBytes, storageUsage, type StorageUsage } from '@/lib/storage';
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
  /*
    Two separate things, and they were one before.

    `taps` is the run of taps happening right now; `open` is whether the card
    is showing. Keeping only the tap count meant leaving Settings — to look at
    the dashboard, or to check whether a test notification arrived — closed the
    card, and coming back cost ten more taps. See lib/devmode.ts.
  */
  const [taps, setTaps] = useState<TapState>(NO_TAPS);
  const [open, setOpen] = useState(readUnlocked);
  const [pending, setPending] = useState<ParsedBundle | null>(null);
  const [eggTaps, setEggTaps] = useState<TapState>(NO_TAPS);
  const [album, setAlbum] = useState(false);
  /* The running-costs note, and whether the tip jar should be scrolled to
     because that note is what sent them there. */
  const [costs, setCosts] = useState(false);
  const [toJar, setToJar] = useState(false);
  /* Stable, so the scroll effect in Support depends on the flag and not on a
     fresh arrow arriving with every render. */
  const jarDone = useCallback(() => setToJar(false), []);

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
          {/* It used to end "Nothing here leaves the device", which stopped
              being true the moment the Reminders card landed on this page. */}
          <p>How Stash it behaves.</p>
        </div>

        {/* 104, the same as on Items. He was 132 here and 104 there, which read
            as two different Scouts on two tabs — the size is part of how a
            character is recognised, and one number is one character. */}
        <Scout pose="settings" height={104} motion={['breathe']} alt="" />
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
      <Reminders
        settings={settings}
        propertyId={propertyId}
        onNotice={setNotice}
        onEnabled={() => !settings.pushCostShownAt && setCosts(true)}
      />
      <AboutApp onNotice={setNotice} onTour={onTour} />
      <Support settings={settings} focus={toJar} onFocused={jarDone} />

      {costs && (
        <RunningCosts
          onSupport={() => {
            setCosts(false);
            setToJar(true);
          }}
          onClose={() => setCosts(false)}
        />
      )}

      {/* The version, last, in a card of its own. It's a fact about the build
          rather than a setting, and it was riding on the About card's header
          where it read as that card's badge. Ten taps still opens the
          developer tools; nothing about it advertises that. */}
      <VersionCard
        taps={taps}
        onTap={() => {
          const next = tap(taps, Date.now());
          setTaps(next);
          if (unlocked(next)) {
            setTaps(NO_TAPS);
            setOpen(true);
            rememberUnlocked(true);
          }
        }}
      />

      {open && (
        <Developer
          settings={settings}
          propertyId={propertyId}
          onHide={() => {
            setOpen(false);
            rememberUnlocked(false);
          }}
          onHome={onHome}
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

      {/* No note. A toggle called Sounds that makes sounds is not a thing
          anyone needs explained, and the preview fires the moment you flip
          it — which says it better than a sentence could. */}
      <Row
        label="Sounds"
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

      {/* A note only when it will not work. "A gentle tick as you tap" is the
          label again; "this does nothing here" is the one thing you could not
          have guessed by looking at it. */}
      <Row
        label="Haptics"
        note={canBuzz ? undefined : 'This browser has no vibration, so this does nothing.'}
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
      {/* This one stays and stays long. It is the difference between a lock
          and a safe, and someone who reads it wrong plans around a promise the
          app cannot keep. */}
      <p className="hint">
        This locks the app, not the data — what you've saved is stored unencrypted, like any
        browser database. It stops someone picking up your phone, not someone with your phone and
        a laptop.
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
      {/* Kept, because the question it answers is "am I making an account".
          Four words is enough to say no. */}
      <Row
        label="Your name"
        note="Only used in the greeting."
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

      <Row label="Rooms" onClick={onOpenRooms} />

      {/* Relabelled rather than explained. "Items open" needed a sentence to
          say what it meant, which is a label doing its job badly — and the two
          options finish the sentence on their own. */}
      <SegRow
        label="Rooms start"
        value={prefsFrom(settings).roomsView}
        options={[
          { value: 'collapsed', label: 'Collapsed' },
          { value: 'expanded', label: 'Expanded' },
        ]}
        onChange={(v) => setPref('roomsView', v as RoomsView)}
      />

      {/* Left in because it stops a fair worry: changing this does not go back
          and rewrite what you have already saved. */}
      <Row
        label="Currency"
        note="New items only."
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
        value={settings.reminderOffsetsDays[0] ?? 30}
        options={REMINDER_CHOICES.map((r) => ({ value: r.days, label: r.label }))}
        onChange={(days) => db.settings.update('singleton', { reminderOffsetsDays: [days] })}
      />
    </Card>
  );
}

/* ------------------------------------------------------------- reminders */

/**
 * Notifications that arrive while the app is closed.
 *
 * ── The card exists to make the trade legible before it is taken ──────────
 * Everything else in this app happens on the device. This is the one feature
 * that cannot, so the card says what a sender would learn — dates, and nothing
 * else — beside the switch rather than in a policy nobody opens.
 *
 * The claim is true because of where the words are written: the notification
 * text is composed here and left in the browser's own cache, and the push that
 * arrives carries no payload at all. See src/lib/push.ts.
 */
function Reminders({
  settings,
  propertyId,
  onNotice,
  onEnabled,
}: {
  settings: SettingsRecord;
  propertyId: string;
  onNotice: (n: Notice) => void;
  /** Fired once the switch is genuinely on, so the costs note can appear. */
  onEnabled: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const state = pushVerdict();
  const on = !!settings.pushEnabled;

  const flip = async () => {
    setBusy(true);
    onNotice(null);
    try {
      if (on) {
        await disablePush();
        onNotice({ tone: 'ok', text: 'Reminders off. The subscription has been dropped.' });
      } else {
        const outcome = await enablePush();
        if (outcome === 'on') {
          await refreshNotes(propertyId);
          // Straight away on this one: the weekly rule exists to stop a sender
          // watching you edit, and turning the switch on is not that.
          const told = await syncSchedule(propertyId, true);
          feedback('save');
          onEnabled();
          onNotice({
            tone: 'ok',
            text: told
              ? 'Reminders on. Your dates have been sent.'
              : senderConfigured()
                ? "Reminders on, but the sender couldn't be reached. It'll try again."
                : 'Reminders on. No sender is configured, so nothing left the phone.',
          });
        } else {
          feedback('error');
          onNotice({ tone: 'bad', text: VERDICT_COPY[outcome] });
        }
      }
    } catch (e) {
      feedback('error');
      onNotice({ tone: 'bad', text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card title="Push Notifications">
      <div className="setrow">
        <span className="setrow-txt">
          <strong>Notify me</strong>
          {/*
            One sentence about the payload, in the place the decision is made.

            The card used to carry a paragraph of preamble and a button that
            printed the exact JSON. Both were honest and neither was read: the
            paragraph explained the feature to someone already looking at its
            switch, and the payload viewer answered a question in a format that
            asks you to parse JSON on a phone. What people need at the moment
            of deciding is one line — what leaves, and what doesn't. The full
            payload still exists, verbatim, in Settings → Developer, which is
            where a claim that needs checking properly belongs.
          */}
          <small>
            {state === 'ready' || on
              ? 'Told on the day, with the app closed. Only the dates leave your phone — never what the reminder is about.'
              : VERDICT_COPY[state]}
          </small>
        </span>
        <button
          type="button"
          className={`toggle${on ? ' on' : ''}`}
          role="switch"
          aria-checked={on}
          aria-label="Reminders"
          data-cue="none"
          disabled={busy || (state !== 'ready' && !on)}
          onClick={() => void flip()}
        >
          <span />
        </button>
      </div>

    </Card>
  );
}

/**
 * The payload, verbatim. Lives in Developer now.
 *
 * It was on the main card, behind "See exactly what would be sent", and the
 * reasoning for putting it there still stands: a privacy claim nobody can check
 * is marketing. What was wrong was the audience. Someone deciding whether to
 * flip a switch needs one sentence; someone auditing the claim needs the actual
 * JSON, and will find it. Keeping both on the same card meant the sentence
 * competed with a code block and neither got read.
 */
function PayloadView({ propertyId }: { propertyId: string }) {
  const [schedule, setSchedule] = useState<Wake[]>([]);
  const [showing, setShowing] = useState(false);
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);

  useEffect(() => {
    void previewSchedule(propertyId).then(setSchedule);
  }, [propertyId]);

  return (
    <>
      <button type="button" className="linkish wide-link" onClick={() => setShowing((v) => !v)}>
        {showing ? 'Hide what would be sent' : 'See exactly what would be sent'}
      </button>

      {showing && (
        <div className="leaks">
          <p className="hint">
            <b>Leaves this phone:</b> a delivery address your browser generates, and these
            moments — nine in the morning, your time, on each day something needs you.
          </p>
          <pre>
            {JSON.stringify(
              { endpoint: settings?.pushEndpoint ?? '(none yet)', wakes: plannedWakes(schedule) },
              null,
              2,
            )}
          </pre>
          <p className="hint">
            Which is to say:{' '}
            {wakeDates(schedule).slice(0, 4).join(', ') || 'nothing due in the next two months'}
            {wakeDates(schedule).length > 4 ? ` and ${wakeDates(schedule).length - 4} more` : ''}.
          </p>
          <p className="hint">
            <b>Never leaves:</b> what the reminder says. The wording is worked out here and kept
            in this browser's cache; the message that arrives on the day is empty, and your phone
            fills it in. Nobody in the middle — including whoever runs the sender — can read a
            notification they did not write.
          </p>
          <p className="hint">
            <b>Worth knowing anyway:</b> the delivery address lives on Google's or Apple's
            servers, so they can see that your phone was pinged and when. A sender sees your IP
            each time this list is refreshed — which is why it refreshes weekly rather than
            whenever you change something, so it can't watch you use the app. And the times give
            away roughly which part of the world you are in, because that is what makes a
            reminder arrive in your morning rather than at three.
          </p>
        </div>
      )}
    </>
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
  /* A finished bundle waiting for a fresh tap — see the note by the button. */
  const [ready, setReady] = useState<{ blob: Blob; filename: string } | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  /*
    Probed once, with an empty file, because `canShare` reads the name and the
    type and never the contents. Deciding this up front is what lets the copy
    below promise the right thing instead of describing a share sheet that this
    browser is never going to open.
  */
  const shareable = canShareBundle();

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
        Nothing syncs anywhere, so a backup only exists if you make one.
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

      {/*
        "Back up now", not "Export everything".

        The mechanism was always a backup; the label described the file format.
        Nobody wakes up wanting to export — they want to know their stuff is
        safe, and the nudge above this card asks them in exactly those words,
        so the button it sends them to should answer in the same ones.

        Full width, because it is the most consequential control on the screen.
      */}
      <button
        type="button"
        className="btn wide"
        disabled={busy}
        onClick={() =>
          run(async () => {
            const { blob, filename } = await exportBundle();
            const how = await saveBundle(blob, filename);

            /*
              A cancel stamps nothing and claims nothing. It used to do both:
              the date was written while the zip was being built, so dismissing
              the share sheet left the app reporting a backup that did not
              exist and sitting quiet for the next thirty days.
            */
            if (how === 'cancelled') {
              onNotice({ tone: 'bad', text: 'Cancelled — nothing was saved.' });
              return;
            }

            /*
              The share sheet wanted a fresh tap. Zipping a photo library takes
              longer than transient activation lasts, so the gesture that
              started the backup had expired by the time the file existed. Hold
              the finished bundle and offer a button; that tap arrives with a
              live gesture and the sheet opens with no second export.
            */
            if (how === 'needs-gesture') {
              setReady({ blob, filename });
              onNotice({ tone: 'ok', text: 'Ready. Choose where to send it.' });
              return;
            }

            await markBackedUp();
            feedback('save');
            onNotice({
              tone: 'ok',
              text:
                how === 'shared'
                  ? `Sent ${filename}. Check it arrived where you sent it.`
                  : `Saved ${filename} to your downloads. Move it somewhere off this phone.`,
            });
          })
        }
      >
        {/* The size rides on the button rather than sitting in a row of its
            own further down. "How much am I about to write out" is a fact
            about this action, and it was being reported as if it were a
            separate setting. */}
        Back up now
        {usage && <span className="btnnote">{formatBytes(usage.usedBytes)}</span>}
      </button>

      {/*
        The second tap, when the browser asked for one. Not shown otherwise —
        a permanently visible "send it" button next to a backup button is two
        controls for one job.
      */}
      {ready && (
        <button
          type="button"
          className="btn wide"
          disabled={busy}
          onClick={() =>
            run(async () => {
              let how = await saveBundle(ready.blob, ready.filename);

              /*
                ── The bug this branch fixes ────────────────────────────────

                'needs-gesture' was not handled here, so a second refusal fell
                through to the success path: the button vanished, the backup
                date was stamped, and the app announced it had sent a file that
                had never left. Nothing on screen for the person to act on, and
                a reminder that would now stay quiet for thirty days.

                A second refusal means the fresh-gesture theory is wrong, so
                stop testing it and write the file out instead. See the note on
                `saveBundle`'s `share` option.
              */
              if (how === 'needs-gesture') {
                how = await saveBundle(ready.blob, ready.filename, { share: false });
              }

              // A cancel stamps nothing and claims nothing. The button stays,
              // because the file is still sitting there ready to go.
              if (how === 'cancelled') {
                onNotice({ tone: 'bad', text: 'Cancelled — nothing was saved.' });
                return;
              }

              setReady(null);
              await markBackedUp();
              feedback('save');
              onNotice({
                tone: 'ok',
                text:
                  how === 'shared'
                    ? `Sent ${ready.filename}. Check it arrived where you sent it.`
                    : `This browser would not open the share sheet, so ${ready.filename} went to your downloads. Move it somewhere off this device.`,
              });
            })
          }
        >
          Send it somewhere
        </button>
      )}

      {/*
        ── The way out, and why it is a button rather than a fallback ────────

        "Send it somewhere" is a request to the browser, and a browser is
        entitled to refuse — silently, repeatedly, for reasons the page cannot
        see. When that happens the person is left tapping a button that plays a
        sound and does nothing, which is the report that led here.

        So the escape is on the screen, always, next to the thing that might
        fail. It writes the file to the downloads folder, which is the one
        route no permission and no user gesture can take away. It is drawn as
        the quieter of the two because sharing is still the better outcome on a
        phone — the file ends up somewhere that is not this device.
      */}
      {ready && (
        <button
          type="button"
          className="btn wide ghost"
          disabled={busy}
          onClick={() =>
            run(async () => {
              await saveBundle(ready.blob, ready.filename, { share: false });
              setReady(null);
              await markBackedUp();
              feedback('save');
              onNotice({
                tone: 'ok',
                text: `Saved ${ready.filename} to your downloads. Move it somewhere off this device.`,
              });
            })
          }
        >
          Save it to this device instead
        </button>
      )}

      <p className="hint">
        {/*
          Two different sentences, because two different things happen and
          promising the wrong one is how this got reported.

          THE SHARE SHEET IS NOT AVAILABLE ON CHROME, and no amount of code
          changes that: Web Share screens files by extension against a list
          that holds images, audio, video, text and pdf. A backup bundle is a
          zip, so Chrome and Android hand it to the downloads folder instead —
          which works, and is a different instruction to give.
        */}
        One file holding every item, document and photo.{' '}
        {shareable
          ? "You'll choose where it goes — a cloud drive, or your own email. Pick somewhere you'll still have if the phone goes."
          : "This browser saves it to your downloads rather than offering to send it, so move it somewhere off the phone afterwards."}{' '}
        Nothing syncs on its own, so this is the only copy that survives.
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
function Support({
  settings,
  focus,
  onFocused,
}: {
  settings: SettingsRecord;
  focus?: boolean;
  /** Fired once the jar has been scrolled to, so it only happens once. */
  onFocused?: () => void;
}) {
  /*
    AN EFFECT, NOT AN INLINE REF, and the difference was a bug.

    A ref written as an inline arrow gets a new identity every render, so React
    tears it down and sets it up again each time — which meant scrolling here
    fired on every single re-render of Settings while the flag was up, and the
    flag was never lowered. Flip any toggle, edit your name, dismiss a notice,
    and the page yanked itself back to the Venmo button.

    Keyed on `focus` and cleared the moment it has done its job.
  */
  const jar = useRef<HTMLAnchorElement>(null);
  useEffect(() => {
    if (!focus || !jar.current) return;
    jar.current.scrollIntoView({ block: 'center', behavior: 'smooth' });
    onFocused?.();
  }, [focus, onFocused]);

  /*
    The old boolean, read once. Anyone who had "Make it monthly" switched on
    before this became a three-way choice keeps their reminder rather than
    silently losing it — a setting that vanishes in an update is worse than one
    that was never offered.
  */
  const cadence: TipCadence = settings.donateCadence ?? (settings.donateMonthly ? 'monthly' : 'never');

  /* Yearly is the one with a number attached to it — it is what a year of the
     notification server costs — so choosing it picks that amount. */
  const [picked, setPicked] = useState(
    () => TIERS.find((t) => t.amount === YEARLY_AMOUNT && cadence === 'yearly') ?? TIERS[1]!,
  );
  const due = donationDue(cadence, settings.donateLastAt);

  const send = () => {
    feedback('save');
    void db.settings.update('singleton', { donateLastAt: nowISO() });
  };

  const setCadence = (next: TipCadence) => {
    if (next === 'yearly') setPicked(TIERS.find((t) => t.amount === YEARLY_AMOUNT) ?? picked);
    void db.settings.update('singleton', {
      donateCadence: next,
      donateMonthly: undefined,
      donateLastAt: next === 'never' ? settings.donateLastAt : (settings.donateLastAt ?? nowISO()),
    });
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

      {due && <p className="hint warnhint">{TIP_DUE_COPY[cadence]}</p>}

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

      {/*
        One control, not two toggles.

        "Make it monthly" and "make it yearly" as separate switches have a
        fourth state where both are on, which means nothing — and whichever way
        that gets resolved in code becomes a rule nobody can see on the screen.
        Three options, one of them chosen, and the state is always readable.

        The note is doing real work. Venmo cannot schedule a payment from a
        link, so this genuinely is a reminder and nothing else. An app that
        implies a standing order it never set up is lying about money, which is
        the worst thing on this page to be wrong about.
      */}
      <SegRow
        label="Remind me again"
        note="Nothing is charged automatically. Stash it just asks."
        value={cadence}
        options={[
          { value: 'never' as TipCadence, label: 'Never' },
          { value: 'monthly' as TipCadence, label: 'Monthly' },
          { value: 'yearly' as TipCadence, label: 'Yearly' },
        ]}
        onChange={setCadence}
      />

      {cadence === 'yearly' && (
        <p className="hint">
          {money(YEARLY_AMOUNT)} a year covers the notification server, which is the only part of
          Stash it that costs anything to run.
        </p>
      )}

      {/* An anchor, not a button: it leaves the app, and the long-press menu
          that gives — copy the link, open in a new tab — is worth keeping. */}
      {/* Arrived here from the running-costs note, which promised a tip jar.
          Landing at the top of Settings instead is how a person concludes the
          button did nothing — see the effect above. */}
      <a
        ref={jar}
        className="btn wide"
        href={venmoUrl({ amount: picked.amount, note: picked.note, cadence })}
        target="_blank"
        rel="noreferrer"
        onClick={send}
      >
        <VenmoGlyph />
        Send {money(picked.amount)} on Venmo
      </a>

      <p className="hint">
        You confirm the payment in Venmo. Marked private, so it isn't in anyone's feed.
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
        /* The instructions stay where there is no button to press; the data
           point stays everywhere, because "installing protects your data" is
           the reason to bother and nobody knows it. */
        <Row
          label="Add to home screen"
          note={
            offer === 'native'
              ? 'Also makes the browser far less willing to clear your data.'
              : offer === 'ios'
                ? 'Safari: Share, then Add to Home Screen. Also protects your data.'
                : 'Browser menu, then Add to Home screen. Also protects your data.'
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
        onClick={onTour}
      />

      {/*
        A real page at a real URL, not a sheet inside the app.

        An app store asks for a policy address, and so does anyone deciding
        whether to trust this before installing it — both need somewhere that
        exists without the app. It opens outward for the same reason.
      */}
      <Row
        label="Privacy policy"
        onClick={() => {
          feedback('nav');
          window.open(`${__SITE_PATH__}privacy.html`, '_blank', 'noopener');
        }}
      />

      {/*
        A mailto, not a form. A form needs somewhere to post to and this app
        has no server — so the mail app the user already has is the only piece
        of infrastructure that's certain to exist. It also means they see the
        whole message, context line included, before anything is sent.
      */}
      {/* One of the three says the mail app opens. Saying it on all three is
          the app repeating itself down a column. */}
      <Row
        label="Ask a question"
        note="Opens your mail app."
        onClick={() => writeIn('question')}
      />

      <Row
        label="Suggest a feature"
        onClick={() => writeIn('idea')}
      />

      <Row
        label="Report something broken"
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
  const count = useLiveQuery(() => cappedCount(propertyId), [propertyId]) ?? 0;

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
        note={`Lifts the ${FREE_ITEM_LIMIT}-record cap. ${count} saved.`}
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
        note="Samples on the dashboard. Leaving it clears them."
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

      <NotificationBench propertyId={propertyId} />
    </Card>
  );
}

/* ------------------------------------------------- the notification bench */

/**
 * Four buttons, in the order the chain actually runs.
 *
 * A reminder crosses four things that can each break on their own: this
 * device's permission, the wording, the worker that reads it, and the trip
 * across the internet. Testing only the whole chain tells you it doesn't work,
 * which you already knew. So each link gets its own button, top to bottom, and
 * the first one that fails is the one to fix.
 *
 * The readout above them is the part worth reading first. It shows what the
 * browser thinks and what the database thinks as separate rows, because the
 * interesting failure is when they disagree — a device the sender will ping
 * every week and that cannot show a thing. Averaged into one "on" that state is
 * invisible; side by side it is obvious.
 */
function NotificationBench({ propertyId }: { propertyId: string }) {
  const [d, setD] = useState<PushDiagnosis | null>(null);
  const [said, setSaid] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [staged, setStaged] = useState(false);

  const look = useCallback(() => {
    void diagnose().then(setD);
  }, []);

  useEffect(look, [look]);

  const run = async (job: () => Promise<string>) => {
    setBusy(true);
    try {
      setSaid(await job());
    } catch (e) {
      setSaid((e as Error).message);
    } finally {
      setBusy(false);
      look();
    }
  };

  return (
    <div className="bench">
      <div className="benchhead">
        <strong>Reminders</strong>
        <button type="button" className="linkish" onClick={look}>
          Refresh
        </button>
      </div>

      {d && (
        <dl className="benchgrid">
          <Stat name="Switch" value={d.enabled ? 'on' : 'off'} ok={d.enabled} />
          <Stat name="Permission" value={d.permission} ok={d.permission === 'granted'} />
          <Stat name="Worker" value={d.workerReady ? 'ready' : 'none'} ok={d.workerReady} />
          <Stat
            name="Subscription"
            value={d.subscribed ? 'live' : 'none'}
            ok={d.subscribed}
            /* The mismatch worth shouting about: registered with the sender,
               unable to receive. */
            warn={!d.subscribed && d.enabled}
          />
          <Stat
            name="Sender"
            value={d.senderConfigured ? 'configured' : 'none'}
            ok={d.senderConfigured}
          />
          <Stat
            name="Last sync"
            value={d.syncedAt ? new Date(d.syncedAt).toLocaleDateString() : 'never'}
            ok={!!d.syncedAt}
          />
          <Stat name="Dates uploaded" value={`${d.uploadedWakes}`} ok={d.uploadedWakes > 0} />
          <Stat name="Days cached" value={`${d.cachedNotes}`} ok={d.cachedNotes > 0} />
        </dl>
      )}

      {d && (
        <p className="hint">
          <b>Today would say:</b>{' '}
          {d.today ? `“${d.today.title} — ${d.today.body}”` : '“Nothing needs you”'}
          {d.verdict !== 'ready' && !d.enabled ? ` · ${VERDICT_COPY[d.verdict]}` : ''}
        </p>
      )}

      <div className="benchrow">
        <button
          type="button"
          className="minibtn ghost"
          disabled={busy}
          onClick={() =>
            void run(async () => {
              const out = await notifyNow();
              return out === 'shown'
                ? 'Shown. If nothing appeared, the OS is suppressing it — check Focus or Do Not Disturb.'
                : out === 'no-permission'
                  ? 'Permission not granted. Turn Reminders on first.'
                  : out === 'no-worker'
                    ? 'No service worker. Run a built copy, not the dev server.'
                    : "The worker refused to show it.";
            })
          }
        >
          1. Show one now
        </button>
        <small>This device only. Proves permission, the icon and what tapping it does.</small>
      </div>

      <div className="benchrow">
        <button
          type="button"
          className="minibtn ghost"
          disabled={busy}
          onClick={() =>
            void run(async () => {
              if (staged) {
                const n = await restoreSchedule(propertyId);
                setStaged(false);
                return `Real schedule back — ${n} day${n === 1 ? '' : 's'} in the next two months.`;
              }
              const w = await stageToday(propertyId);
              setStaged(true);
              return `Today now reads “${w.title}”. Press 1, or send a real ping.`;
            })
          }
        >
          {staged ? '2. Put the real one back' : '2. Fake a reminder for today'}
        </button>
        <small>
          Writes a sample into the note the worker reads, so there is something real-looking to
          show. Cleared on the next launch either way.
        </small>
      </div>

      <div className="benchrow">
        <button
          type="button"
          className="minibtn ghost"
          disabled={busy || !d?.senderConfigured}
          onClick={() => void run(async () => PING_COPY[await pingNow()])}
        >
          3. Send a real push
        </button>
        <small>
          The whole path: sender, then Google or Apple, then this phone. Close the app first — a
          notification that only works in the foreground is not working.
        </small>
      </div>

      {said && <p className="benchsaid">{said}</p>}

      <PayloadView propertyId={propertyId} />
    </div>
  );
}

function Stat({
  name,
  value,
  ok,
  warn,
}: {
  name: string;
  value: string;
  ok: boolean;
  warn?: boolean;
}) {
  return (
    <div className={`stat${warn ? ' warn' : ok ? ' ok' : ''}`}>
      <dt>{name}</dt>
      <dd>{value}</dd>
    </div>
  );
}
