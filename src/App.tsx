import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, ensureFirstRun } from '@/db/db';
import { canAddItem, cappedCount, purgeExpiredDeletes } from '@/db/repo';
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
import { clearBack, pushBack, replaceTopBack } from '@/lib/backstack';
import {
  biometricsAvailable,
  clearLock,
  lockVerdict,
  verifyBiometrics,
  type LockVerdict,
} from '@/lib/lock';
import { endingSoonDays } from '@/lib/nudges';
import { prefsFrom } from '@/lib/prefs';
import { pushVerdict, refreshNotes, syncSchedule } from '@/lib/pushClient';
import { clearNotifyOffer, notifyOfferArmed, shouldOffer } from '@/lib/notifyOffer';
import { NotifyOffer } from '@/components/NotifyOffer';
import { setEndingSoonDays } from '@/lib/warranty';
import { BACK_DIRECTION, nextTab } from '@/lib/swipe';
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
import { Bin } from '@/screens/Bin';
import { Subs } from '@/screens/Subs';
import { SubForm } from '@/screens/SubForm';
import { Papers } from '@/screens/Papers';
import { PaperForm } from '@/screens/PaperForm';
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
  | { kind: 'bin' }
  | { kind: 'subs' }
  | { kind: 'addsub' }
  | { kind: 'editsub'; id: string }
  | { kind: 'papers' }
  | { kind: 'addpaper' }
  | { kind: 'editpaper'; id: string }
  /*
    `saved` marks the one arrival that came from creating this item, so the
    detail screen can tell you to file the paper copy. It lives on the screen
    rather than on the record: it's a fact about this navigation, not about the
    item, and going back and opening it again builds a fresh screen without it.
  */
  | { kind: 'detail'; id: string; from: Origin; saved?: boolean }
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
  bin: 'items',
  subs: 'subs',
  addsub: 'subs',
  editsub: 'subs',
  papers: 'papers',
  addpaper: 'papers',
  editpaper: 'papers',
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

        /*
          Rewrite what a reminder would say, every launch.

          This is what keeps precomputed notification text honest. The service
          worker cannot run the timeline — it is plain JavaScript imported into
          the Workbox bundle — so the page composes the words and leaves them
          in Cache Storage. Doing it on every launch means the note is only
          ever as old as your last visit, rather than as old as the last sync.

          Not awaited, and failure is silent: a stale note is a slightly wrong
          notification, and blocking the dashboard on it would be worse.
        */
        void (async () => {
          const property = await db.properties.filter((p) => !p.deletedAt).first();
          if (!property) return;
          await refreshNotes(property.id);
          // And tell the sender, if a week has gone by and the dates have
          // moved. `syncSchedule` decides both — see the note there on why it
          // is weekly rather than on every change.
          await syncSchedule(property.id);
        })().catch(() => {});
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
  bin: true,
  subs: false,
  addsub: true,
  editsub: true,
  papers: false,
  addpaper: true,
  editpaper: true,
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

  /*
    "You've saved something with a date on it — want to be told?"

    Decided here rather than in the form, because the form is unmounting: it
    navigates to the detail screen on save, and a dialog owned by a component
    on its way out either flashes or never appears. The form raises a flag; the
    shell reads it on the next render and applies every rule about whether the
    question should be put at all. See lib/notifyOffer.ts.
  */
  const [askNotify, setAskNotify] = useState(false);
  useEffect(() => {
    if (!settings || !notifyOfferArmed()) return;
    setAskNotify(
      shouldOffer({
        asked: !!settings.pushAskedAt,
        enabled: !!settings.pushEnabled,
        verdict: pushVerdict(),
        dated: true,
      }),
    );
    // Read once. Left armed, a "no" would be re-evaluated on every render for
    // the rest of the session.
    clearNotifyOffer();
  }, [settings]);

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
    useLiveQuery(async () => (property ? cappedCount(property.id) : 0), [property]) ?? 0;

  const focusId = screen.kind === 'detail' || screen.kind === 'edit' ? screen.id : undefined;
  const origin: Origin =
    screen.kind === 'detail' || screen.kind === 'edit' || screen.kind === 'add'
      ? screen.from
      : 'items';
  const back = (): Screen => (origin === 'home' ? { kind: 'home' } : { kind: 'items' });

  /**
   * Where the back arrow in the header goes — and so where a swipe back goes,
   * because two ways of stepping up that land in different places would be two
   * different gestures wearing the same name.
   *
   * Takes the screen rather than reading the current one, because `replace`
   * has to ask this about a screen that isn't open yet.
   *
   * Null for the forms. Everything else on this list is something you're
   * reading, where leaving costs nothing.
   */
  const upFrom = (s: Screen): Screen | null => {
    if (s.kind === 'detail') return s.from === 'home' ? { kind: 'home' } : { kind: 'items' };
    if (s.kind === 'rooms') return { kind: 'settings' };
    if (s.kind === 'bin') return { kind: 'items' };
    if (s.kind === 'editsub') return { kind: 'subs' };
    if (s.kind === 'editpaper') return { kind: 'papers' };
    return null;
  };

  /**
   * One pushed screen becoming another at the same depth.
   *
   * The add form saving is the only case: it stops existing, and the item it
   * created takes its place. It used to `pop` — hand the entry back, then land
   * on a screen that never took one of its own. So Back from an item you had
   * just created found an empty stack and left the app, while Back from that
   * same item reached any other way worked perfectly. One screen, two
   * behaviours, depending on how you got there.
   *
   * The entry is kept and handed over instead.
   */
  const replace = (next: Screen) => {
    const up = upFrom(next) ?? { kind: 'items' as const };
    // No entry to inherit — a share that opened the form on a cold start, say.
    // Take one properly rather than assume.
    if (!replaceTopBack(() => setScreen(up))) {
      releaseRef.current.push(pushBack(() => setScreen(up)));
    }
    setScreen(next);
  };
  const focused = useLiveQuery(async () => (focusId ? db.items.get(focusId) : undefined), [focusId]);
  const subId = screen.kind === 'editsub' ? screen.id : undefined;
  const paperId = screen.kind === 'editpaper' ? screen.id : undefined;
  const focusedSub = useLiveQuery(
    async () => (subId ? db.subscriptions.get(subId) : undefined),
    [subId],
  );
  const focusedPaper = useLiveQuery(
    async () => (paperId ? db.papers.get(paperId) : undefined),
    [paperId],
  );

  if (!property || !settings) return <Frame>{null}</Frame>;

  const mayAdd = canAddItem(count, settings.entitlements);
  const tab: Tab = TAB_FOR[screen.kind];
  const onTab = !PUSHED[screen.kind];
  const up = upFrom(screen);

  // A deleted or missing record must not leave the user on a blank screen.
  if ((screen.kind === 'detail' || screen.kind === 'edit') && focused === undefined) {
    return <Frame>{null}</Frame>;
  }

  return (
    <Frame
      swipe={onTab ? { tab, onChange: (t) => go({ kind: t }) } : undefined}
      onSwipeBack={up ? () => pop(up) : undefined}
      hasFab={onTab && tab !== 'settings'}
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
          /* The + offers every kind of record now, so it belongs on the
             subscriptions tab too — but still not on Settings, where nothing
             is about adding anything, and not on a pushed screen. */
          onAdd={
            !onTab || tab === 'settings'
              ? undefined
              : (kind) => {
                  if (kind === 'subscription') return go({ kind: 'addsub' });
                  if (kind === 'paper') return go({ kind: 'addpaper' });
                  return go({ kind: 'add', from: tab === 'home' ? 'home' : 'items' });
                }
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
          onSubs={() => go({ kind: 'subs' })}
          onOpenSub={(id) => go({ kind: 'editsub', id })}
          onOpenPaper={(id) => go({ kind: 'editpaper', id })}
        />
      )}

      {screen.kind === 'items' && (
        <Items
          key={screen.filter ?? 'all'}
          propertyId={property.id}
          filter={screen.filter}
          onOpenItem={(id) => go({ kind: 'detail', id, from: 'items' })}
          onAdd={() => go({ kind: 'add', from: 'items' })}
          onOpenBin={() => go({ kind: 'bin' })}
        />
      )}

      {screen.kind === 'detail' && focused && (
        <ItemDetail
          item={focused}
          justSaved={screen.saved === true}
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
            onSaved={(id) => replace({ kind: 'detail', id, from: origin, saved: true })}
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
          onHome={() => go({ kind: 'home' })}
        />
      )}

      {screen.kind === 'rooms' && (
        <Rooms propertyId={property.id} onBack={() => pop({ kind: 'settings' })} />
      )}

      {screen.kind === 'bin' && (
        <Bin propertyId={property.id} onBack={() => pop({ kind: 'items' })} />
      )}

      {screen.kind === 'subs' && (
        <Subs propertyId={property.id} onOpen={(id) => go({ kind: 'editsub', id })} />
      )}

      {screen.kind === 'addsub' && (
        <SubForm
          propertyId={property.id}
          currency={settings.currency}
          onSaved={() => pop({ kind: 'subs' })}
          onCancel={() => pop({ kind: 'subs' })}
        />
      )}

      {screen.kind === 'editsub' && focusedSub && (
        <SubForm
          propertyId={property.id}
          currency={settings.currency}
          existing={focusedSub}
          onSaved={() => pop({ kind: 'subs' })}
          onCancel={() => pop({ kind: 'subs' })}
        />
      )}

      {screen.kind === 'papers' && (
        <Papers propertyId={property.id} onOpen={(id) => go({ kind: 'editpaper', id })} />
      )}

      {screen.kind === 'addpaper' && (
        <PaperForm
          propertyId={property.id}
          onSaved={() => pop({ kind: 'papers' })}
          onCancel={() => pop({ kind: 'papers' })}
        />
      )}

      {screen.kind === 'editpaper' && focusedPaper && (
        <PaperForm
          propertyId={property.id}
          existing={focusedPaper}
          onSaved={() => pop({ kind: 'papers' })}
          onCancel={() => pop({ kind: 'papers' })}
        />
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
      ) : askNotify ? (
        /*
          Ahead of the install prompt, behind everything else.

          It has just been earned — someone saved a thing with a date on it a
          second ago — and it is about that thing, so it is the most relevant
          sheet on the list. It still yields to the welcome and the tour,
          because being asked about notifications before being told what the
          app is, is the wrong way round.
        */
        <NotifyOffer
          propertyId={property.id}
          onClose={() => {
            clearNotifyOffer();
            setAskNotify(false);
          }}
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
 * The shell. The scrolling body reads a horizontal drag as either a tab change
 * or a step back, depending on where you are — never both, since a screen
 * can't be a tab and a push at the same time.
 *
 * Neither is offered on the add and edit forms: a swipe out of a half-filled
 * form is a way to lose work by accident.
 */
function Frame({
  children,
  nav,
  swipe,
  onSwipeBack,
  hasFab,
}: {
  children: ReactNode;
  nav?: ReactNode;
  swipe?: { tab: Tab; onChange: (t: Tab) => void };
  onSwipeBack?: () => void;
  /** Pads the scroller so the floating button never covers the last row. */
  hasFab?: boolean;
}) {
  const body = useRef<HTMLDivElement>(null);
  const tab = swipe?.tab;

  useSwipeNav(body, !!swipe || !!onSwipeBack, (direction) => {
    if (swipe) {
      const to = nextTab(swipe.tab, direction);
      // Nothing beyond the ends. A silent no-op at the edge reads as "that's
      // all there is", which is true and is what the bottom bar already shows.
      if (!to || to === swipe.tab) return;
      feedback('nav');
      swipe.onChange(to);
      return;
    }

    /*
      Content follows the finger, so dragging right reveals what's to the left
      — which is where you came from. Only right: there is nothing forward of
      a pushed screen to swipe towards.

      This is our own gesture, and useSwipeNav ignores anything starting within
      26px of an edge, so it doesn't fight Android's system back. It's the
      answer to that gesture being the only way out on a phone with no visible
      back button in reach of a thumb.
    */
    if (direction === BACK_DIRECTION && onSwipeBack) {
      feedback('nav');
      onSwipeBack();
    }
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
      <div ref={body} className={`app-body${hasFab ? ' hasfab' : ''}`}>
        <div className="screen" key={tab ?? 'pushed'}>
          {children}
        </div>
      </div>
      {nav}
    </div>
  );
}
