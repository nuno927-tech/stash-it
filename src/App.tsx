import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, ensureFirstRun } from '@/db/db';
import { activeItemCount, canAddItem, purgeExpiredDeletes } from '@/db/repo';
import { configureFeedback, feedback, installClickSounds } from '@/lib/feedback';
import {
  hasNativePrompt,
  installOffer,
  isAndroid,
  isIOSSafari,
  isStandalone,
  watchInstallability,
  type InstallOffer,
} from '@/lib/install';
import { clearBack, pushBack } from '@/lib/backstack';
import {
  biometricsAvailable,
  clearLock,
  lockVerdict,
  verifyBiometrics,
  type LockVerdict,
} from '@/lib/lock';
import { endingSoonDays } from '@/lib/nudges';
import { prefsFrom } from '@/lib/prefs';
import { setEndingSoonDays } from '@/lib/warranty';
import { nextTab } from '@/lib/swipe';
import { remindLater, tourDue } from '@/lib/tour';
import { shareToDraft, type ShareDraft } from '@/lib/shareDraft';
import { forgetShareMarker, looksLikeShare, takeShare } from '@/lib/shareInbox';
import { dismissSplash, raiseSplash, splashRemainingMs } from '@/lib/splash';
import { requestPersistence } from '@/lib/storage';
import { applyTheme, watchSystemTheme } from '@/lib/theme';
import { BottomNav, type Tab } from '@/components/BottomNav';
import { InstallPrompt } from '@/components/InstallPrompt';
import { useSwipeNav } from '@/components/useSwipeNav';
import { Scout } from '@/components/Scout';
import { Tour } from '@/components/Tour';
import { Welcome } from '@/components/Welcome';
import { Home } from '@/screens/Home';
import { ItemDetail } from '@/screens/ItemDetail';
import { ItemForm } from '@/screens/ItemForm';
import { Items, type ItemsFilter } from '@/screens/Items';
import { Placeholder } from '@/screens/Placeholder';
import { Rooms } from '@/screens/Rooms';
import { Settings } from '@/screens/Settings';
import './styles/app.css';

type BootState = { status: 'booting' } | { status: 'ready' } | { status: 'error'; error: Error };

/**
 * Screen state, not routes. There's no router yet — when Item detail needs to
 * be linkable, this is the thing that gets replaced.
 */
/**
 * `from` is a one-level back stack. Without it, Back from an item always
 * dumped you on Items even if you'd opened it from the dashboard — the same
 * screen behaving differently depending on how you got there.
 */
type Origin = 'home' | 'items';

type Screen =
  | { kind: 'home' }
  | { kind: 'items'; filter?: ItemsFilter }
  | { kind: 'settings' }
  | { kind: 'add'; from: Origin }
  | { kind: 'rooms' }
  | { kind: 'detail'; id: string; from: Origin }
  | { kind: 'edit'; id: string; from: Origin };

/** Which nav tab stays lit while a pushed screen is open. */
const TAB_FOR: Record<Screen['kind'], Tab> = {
  home: 'home',
  items: 'items',
  settings: 'settings',
  add: 'items',
  detail: 'items',
  edit: 'items',
  rooms: 'settings',
};

export default function App() {
  const [boot, setBoot] = useState<BootState>({ status: 'booting' });

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        await ensureFirstRun();
        await purgeExpiredDeletes();
        if (!cancelled) setBoot({ status: 'ready' });
        // Not awaited before first paint — a permission decision shouldn't
        // hold up the UI, and nothing on screen depends on the answer.
        void requestPersistence();
      } catch (e) {
        if (!cancelled) setBoot({ status: 'error', error: e as Error });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  if (boot.status === 'error') {
    dismissSplash();
    return (
      <Frame>
        <div className="empty">
          <h3 style={{ color: 'var(--ember)' }}>Database failed to open</h3>
          <p>{boot.error.message}</p>
        </div>
      </Frame>
    );
  }

  return boot.status === 'ready' ? <Gate /> : <Frame>{null}</Frame>;
}

/**
 * The lock, between boot and the app — and with no screen of its own.
 *
 * There used to be a card here reading "Stash it is locked, use your
 * fingerprint or face". It was a screen whose entire content described the
 * dialog that was about to cover it. The splash is already up, already says
 * which app this is, and Android's prompt occupies the bottom two thirds — so
 * the mark simply moves into the third it leaves alone and the platform asks
 * the question. One screen, not two.
 *
 * Nothing of the app renders behind it either way, so there's no arrangement
 * of screenshots or scroll position that leaks what's inside before the check
 * passes.
 */
function Gate() {
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const [available, setAvailable] = useState<boolean | null>(null);
  const [unlocked, setUnlocked] = useState(false);
  const [stuck, setStuck] = useState<'no' | 'retry' | 'stranded'>('no');
  const asked = useRef(false);

  useEffect(() => {
    void biometricsAvailable().then(setAvailable);
  }, []);

  const verdict: LockVerdict =
    !settings || available === null
      ? 'locked' // still asking; assume the strictest answer
      : unlocked
        ? 'open'
        : lockVerdict({
            enabled: settings.biometricLock ?? false,
            credentialId: settings.lockCredentialId,
            available,
          });

  const credentialId = settings?.lockCredentialId ?? '';
  const ready = !!settings && available !== null;

  const unlock = useCallback(async () => {
    setStuck('no');
    raiseSplash();
    const outcome = await verifyBiometrics(credentialId);
    if (outcome === 'unlocked') {
      // No separate "saved" cue here: the launch chime a moment later is the
      // confirmation, and two tones a few hundred milliseconds apart read as
      // one muddled sound rather than two meanings.
      //
      // Fades from where it is rather than sliding back to centre first —
      // recentring on the way out is a movement that means nothing.
      dismissSplash(() => feedback('launch'));
      setUnlocked(true);
      return;
    }
    feedback('error');
    // Cancelled is a decision; anything else suggests the credential itself
    // is broken, which is the only case that earns a way past.
    setStuck(outcome === 'cancelled' ? 'retry' : 'stranded');
  }, [credentialId]);

  useEffect(() => {
    if (!ready || asked.current) return;

    if (verdict === 'open') {
      // Nothing to ask. The splash clears and the dashboard is underneath.
      asked.current = true;
      // Latch it. `settings` is a live query, so turning the lock on from the
      // Settings screen used to flip this verdict back to 'locked' under a
      // running app: the gate stopped rendering the shell, the effect had
      // already fired, and the screen went blank until a reload. A session
      // that has been let in stays in — which is also what the confirmation
      // promises, that you'll be asked next time the app opens.
      setUnlocked(true);
      dismissSplash(() => feedback('launch'));
      return;
    }
    if (verdict === 'stranded') {
      asked.current = true;
      raiseSplash();
      setStuck('stranded');
      return;
    }
    // Once. React runs effects twice in development and a second WebAuthn
    // call aborts the first, which looks exactly like a broken sensor.
    asked.current = true;
    void unlock();
  }, [ready, verdict, unlock]);

  if (verdict === 'open' && ready) return <Shell />;

  // The splash is the screen. This is only the minimum needed so that a
  // cancelled check, or a credential that no longer exists, isn't a locked
  // door with no handle.
  return (
    <>
      <Frame>{null}</Frame>
      {stuck !== 'no' && (
        <div className="lockfoot">
          {stuck === 'stranded' ? (
            <>
              <p>This device can no longer do the check.</p>
              <button type="button" className="btn ghost" onClick={() => void clearLock()}>
                Turn the lock off
              </button>
            </>
          ) : (
            <button type="button" className="btn" onClick={() => void unlock()}>
              Unlock
            </button>
          )}
        </div>
      )}
    </>
  );
}

/**
 * A receipt shared in from the mail app.
 *
 * Read once, on the first render after the worker's redirect. It can't be a
 * render-time read because the payload lives in Cache Storage and everything
 * about getting it is async.
 */
function usePendingShare(currency: string): ShareDraft | null {
  const [draft, setDraft] = useState<ShareDraft | null>(null);
  const done = useRef(false);

  useEffect(() => {
    if (done.current || !looksLikeShare(location.search)) return;
    done.current = true;
    void takeShare().then((payload) => {
      forgetShareMarker();
      if (!payload) return;
      setDraft(shareToDraft(payload, currency));
    });
    // Currency is read once, at the moment the share arrives. Re-running this
    // on a currency change would try to consume a share that's already gone.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return draft;
}

/** The three tabs are a place you switch to; everything else is a push. */
const PUSHED: Record<Screen['kind'], boolean> = {
  home: false,
  items: false,
  settings: false,
  add: true,
  detail: true,
  edit: true,
  rooms: true,
};

function Shell() {
  const [screen, setScreen] = useState<Screen>({ kind: 'home' });
  const current = useRef(screen);
  current.current = screen;

  /**
   * Every screen change goes through here, so the system Back gesture has
   * something to pop.
   *
   * Without it, back on an item detail exited the app — the browser saw one
   * page the whole time, so "back" meant "leave". Now anything pushed takes a
   * history entry and gives it up when it closes.
   *
   * Tab switches clear the stack instead of adding to it. Tapping Settings
   * from three screens deep is a jump, not a step, and walking back through
   * screens the user has visibly left is worse than leaving.
   */
  const go = (next: Screen) => {
    const from = current.current;
    if (PUSHED[next.kind]) {
      const release = pushBack(() => setScreen(from));
      releaseRef.current.push(release);
    } else {
      clearBack();
      releaseRef.current = [];
    }
    setScreen(next);
  };

  // Held so a close-by-button can hand the history entry back rather than
  // leaving a dead one that makes the next Back press appear to do nothing.
  const releaseRef = useRef<(() => void)[]>([]);

  /** Closing a pushed screen from inside it: drop its entry, then move. */
  const pop = (to: Screen) => {
    releaseRef.current.pop()?.();
    setScreen(to);
  };

  const property = useLiveQuery(() => db.properties.filter((p) => !p.deletedAt).first(), []);
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);

  // Preferences live in the database, so they arrive a tick after first paint
  // and follow a restore without a reload.
  const prefs = prefsFrom(settings);
  useEffect(() => {
    applyTheme(prefs.theme);
    return watchSystemTheme(() => applyTheme(prefs.theme));
  }, [prefs.theme]);
  useEffect(() => {
    configureFeedback({ sounds: prefs.sounds, haptics: prefs.haptics });
  }, [prefs.sounds, prefs.haptics]);

  // "Warn me before a warranty ends" was writing to the database and being
  // read by nothing: the amber threshold was a hard-coded 30 days. Published
  // here, once, so every screen agrees — see setEndingSoonDays.
  const warnDays = endingSoonDays(settings);
  useEffect(() => {
    setEndingSoonDays(warnDays);
  }, [warnDays]);

  // One delegated listener for the whole app; the cue is chosen from what was
  // clicked. Silent unless the sounds preference is on.
  useEffect(() => installClickSounds(), []);

  const offer = useInstallOffer();
  const share = usePendingShare(settings?.currency ?? 'USD');

  const [tour, setTour] = useState(false);
  const dueTour = tourDue({
    doneAt: settings?.tourDoneAt,
    remindAt: settings?.tourRemindAt,
  });

  // A share is an instruction: the user picked this app out of the sheet to
  // put a receipt somewhere. Opening anything other than the form would be
  // asking them to say it twice.
  const shareSeen = useRef(false);
  useEffect(() => {
    if (share && !shareSeen.current) {
      shareSeen.current = true;
      go({ kind: 'add', from: 'home' });
    }
  }, [share]);

  const count =
    useLiveQuery(async () => (property ? activeItemCount(property.id) : 0), [property]) ?? 0;

  const focusId = screen.kind === 'detail' || screen.kind === 'edit' ? screen.id : undefined;
  const origin: Origin =
    screen.kind === 'detail' || screen.kind === 'edit' || screen.kind === 'add'
      ? screen.from
      : 'items';
  const back = (): Screen => (origin === 'home' ? { kind: 'home' } : { kind: 'items' });
  const focused = useLiveQuery(async () => (focusId ? db.items.get(focusId) : undefined), [focusId]);

  if (!property || !settings) return <Frame>{null}</Frame>;

  const mayAdd = canAddItem(count, settings.entitlements);
  const tab: Tab = TAB_FOR[screen.kind];
  const onTab = !PUSHED[screen.kind];

  // A deleted or missing record must not leave the user on a blank screen.
  if ((screen.kind === 'detail' || screen.kind === 'edit') && focused === undefined) {
    return <Frame>{null}</Frame>;
  }

  return (
    <Frame
      swipe={onTab ? { tab, onChange: (t) => go({ kind: t }) } : undefined}
      nav={
        <BottomNav
          active={tab}
          onChange={(t) => go({ kind: t })}
          /* The add button belongs to the three tabs, and to two of them.
             Not Settings: nothing there is about adding an item. Not any
             pushed screen either — on a form it offers to start the thing
             you're already doing, over the Save bar that matters; on an item
             it floats over that item's own controls while meaning something
             else entirely. A floating action that doesn't belong to the
             screen it's floating over is just a thing in the way. */
          onAdd={
            !onTab || tab === 'settings'
              ? undefined
              : () => go({ kind: 'add', from: tab === 'home' ? 'home' : 'items' })
          }
          addDisabled={!mayAdd}
        />
      }
    >
      {screen.kind === 'home' && (
        <Home
          propertyId={property.id}
          onAdd={() => go({ kind: 'add', from: 'home' })}
          onOpenItem={(id) => go({ kind: 'detail', id, from: 'home' })}
          onBrowse={(filter) => go({ kind: 'items', filter })}
          onSettings={() => go({ kind: 'settings' })}
        />
      )}

      {screen.kind === 'items' && (
        <Items
          key={screen.filter ?? 'all'}
          propertyId={property.id}
          filter={screen.filter}
          onOpenItem={(id) => go({ kind: 'detail', id, from: 'items' })}
          onAdd={() => go({ kind: 'add', from: 'items' })}
        />
      )}

      {screen.kind === 'detail' && focused && (
        <ItemDetail
          item={focused}
          onBack={() => pop(back())}
          onEdit={() => go({ kind: 'edit', id: focused.id, from: origin })}
          onDeleted={() => pop(back())}
        />
      )}

      {screen.kind === 'edit' && focused && (
        <ItemForm
          propertyId={property.id}
          currency={settings.currency}
          item={focused}
          onSaved={(id) => pop({ kind: 'detail', id, from: origin })}
          onCancel={() => pop({ kind: 'detail', id: focused.id, from: origin })}
        />
      )}

      {screen.kind === 'add' &&
        (mayAdd ? (
          <ItemForm
            propertyId={property.id}
            currency={settings.currency}
            prefill={share?.prefill}
            prestaged={share?.staged}
            banner={share?.banner}
            onSaved={(id) => pop({ kind: 'detail', id, from: origin })}
            onCancel={() => pop(back())}
          />
        ) : (
          <Placeholder
            title="Free tier is full"
            note={`You're at ${count} items. Everything you've saved stays editable and exportable — only new items are blocked.`}
          />
        ))}

      {screen.kind === 'settings' && (
        <Settings
          propertyId={property.id}
          onOpenRooms={() => go({ kind: 'rooms' })}
          onTour={() => setTour(true)}
        />
      )}

      {screen.kind === 'rooms' && (
        <Rooms propertyId={property.id} onBack={() => pop({ kind: 'settings' })} />
      )}

      {/*
        One sheet at a time, in the order a person would expect: hello, then
        the tour they asked for, then — last — the invitation to install.
        Being asked to install before anyone has said hello is the wrong way
        round, and two stacked sheets on a first launch is how an app gets
        deleted.
      */}
      {!settings.onboardedAt ? (
        <Welcome onTour={() => setTour(true)} />
      ) : tour ? (
        <Tour onClose={() => setTour(false)} />
      ) : dueTour ? (
        <TourNudge
          onTake={() => setTour(true)}
          onLater={() =>
            void db.settings.update('singleton', { tourRemindAt: remindLater() })
          }
        />
      ) : (
        offer.show !== 'none' && <InstallPrompt offer={offer.show} onClose={offer.dismiss} />
      )}
    </Frame>
  );
}

/**
 * Whether to invite the user to install, recomputed when the browser decides
 * we're installable — which can happen a second or two after load.
 *
 * Held back until the splash has cleared: a dialog appearing over a launch
 * screen reads as an error, not an invitation.
 *
 * `settled` is the grace period for `beforeinstallprompt`. Chromium fires it
 * whenever it likes and sometimes never; waiting a few seconds before showing
 * the written instructions means the real button wins whenever it turns up.
 */
function useInstallOffer() {
  const [show, setShow] = useState<InstallOffer>('none');
  const [settled, setSettled] = useState(false);

  useEffect(() => {
    const at = window.setTimeout(() => setSettled(true), 3500);
    return () => window.clearTimeout(at);
  }, []);

  useEffect(() => {
    let cancelled = false;

    const evaluate = () => {
      const next = installOffer({
        standalone: isStandalone(),
        nativePrompt: hasNativePrompt(),
        iosSafari: isIOSSafari(),
        android: isAndroid(),
        settled,
      });
      // A beat after the splash, so the app is visible behind it first.
      window.setTimeout(() => {
        if (!cancelled) setShow(next);
      }, splashRemainingMs() + 700);
    };

    evaluate();
    const stop = watchInstallability(evaluate);
    return () => {
      cancelled = true;
      stop();
    };
  }, [settled]);

  // Dismissal lasts as long as this session and no longer. Nothing is written
  // down, so the next launch asks again — until the app is installed, which
  // answers the question permanently on its own.
  return { show, dismiss: () => setShow('none') };
}

/**
 * Three days later, as promised.
 *
 * Small on purpose. The tour is six screens; being dropped into it unasked
 * would be worse than never being offered, so this is the smallest thing that
 * can carry a yes and a no.
 */
function TourNudge({ onTake, onLater }: { onTake: () => void; onLater: () => void }) {
  return createPortal(
    <div className="sheetscrim" role="dialog" aria-modal="true" aria-label="Take the tour">
      <div className="sheetcard">
        <Scout pose="waving" height={96} motion={['breathe']} alt="" />
        <h4>Ready for that tour?</h4>
        <p className="hint">Six short screens. You can stop at any point.</p>

        <button type="button" className="btn wide" onClick={onTake}>
          Take the tour
        </button>
        <button type="button" className="btn ghost" onClick={onLater}>
          In a few days
        </button>
      </div>
    </div>,
    document.body,
  );
}

/**
 * The shell. Given `swipe`, the scrolling body also moves between tabs on a
 * horizontal drag — offered only on the tabs themselves, because a swipe out
 * of a half-filled form would be a way to lose work by accident.
 */
function Frame({
  children,
  nav,
  swipe,
}: {
  children: ReactNode;
  nav?: ReactNode;
  swipe?: { tab: Tab; onChange: (t: Tab) => void };
}) {
  const body = useRef<HTMLDivElement>(null);
  const tab = swipe?.tab;

  useSwipeNav(body, !!swipe, (direction) => {
    if (!swipe) return;
    const to = nextTab(swipe.tab, direction);
    // Nothing beyond the ends. A silent no-op at the edge reads as "that's
    // all there is", which is true and is what the bottom bar already shows.
    if (!to || to === swipe.tab) return;
    feedback('nav');
    swipe.onChange(to);
  });

  // The container survives a tab change, so its scroll position does too —
  // arriving at Settings already scrolled halfway down.
  useEffect(() => {
    if (body.current) body.current.scrollTop = 0;
  }, [tab]);

  return (
    <div className="app">
      {/*
        The listener node must not be keyed. Keying it made React build a new
        DOM element on every tab change while the effect that attached the
        pointer listeners — keyed on `enabled`, which never changed — kept
        holding the old, detached one. One swipe worked; every swipe after it
        went to an element no longer in the document.

        So the container is stable and the animation moved inside it.
      */}
      <div ref={body} className="app-body">
        <div className="screen" key={tab ?? 'pushed'}>
          {children}
        </div>
      </div>
      {nav}
    </div>
  );
}
