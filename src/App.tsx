import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, ensureFirstRun } from '@/db/db';
import { activeItemCount, canAddItem, purgeExpiredDeletes } from '@/db/repo';
import { configureFeedback, feedback, installClickSounds } from '@/lib/feedback';
import {
  hasNativePrompt,
  installOffer,
  isIOSSafari,
  isStandalone,
  wasDismissed,
  watchInstallability,
  type InstallOffer,
} from '@/lib/install';
import { clearBack, pushBack } from '@/lib/backstack';
import { biometricsAvailable, lockVerdict, type LockVerdict } from '@/lib/lock';
import { prefsFrom } from '@/lib/prefs';
import { nextTab } from '@/lib/swipe';
import { shareToDraft, type ShareDraft } from '@/lib/shareDraft';
import { forgetShareMarker, looksLikeShare, takeShare } from '@/lib/shareInbox';
import { dismissSplash, splashRemainingMs } from '@/lib/splash';
import { requestPersistence } from '@/lib/storage';
import { applyTheme, watchSystemTheme } from '@/lib/theme';
import { BottomNav, type Tab } from '@/components/BottomNav';
import { InstallPrompt } from '@/components/InstallPrompt';
import { LockScreen } from '@/components/LockScreen';
import { useSwipeNav } from '@/components/useSwipeNav';
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

  // Fade the launch splash once there's something worth revealing. It's static
  // markup in index.html, so the shell has already mounted underneath it by the
  // time this runs — the dashboard is painted and settled before it clears.
  if (boot.status !== 'booting') dismissSplash();

  if (boot.status === 'error') {
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
 * The lock, between boot and the app.
 *
 * Nothing renders behind it — an empty shell, not a blurred dashboard — so
 * there's no arrangement of screenshots or scroll position that leaks what's
 * inside before the check passes.
 *
 * Unlocking is state, not a reload: the settings record still says the lock is
 * on, so re-reading it would simply lock the app again.
 */
function Gate() {
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const [available, setAvailable] = useState<boolean | null>(null);
  const [unlocked, setUnlocked] = useState(false);

  useEffect(() => {
    void biometricsAvailable().then(setAvailable);
  }, []);

  // `available === null` is still asking. Rendering Shell first and the lock a
  // beat later would show the dashboard to someone who shouldn't see it.
  if (!settings || available === null) return <Frame>{null}</Frame>;

  const verdict: LockVerdict = unlocked
    ? 'open'
    : lockVerdict({
        enabled: settings.biometricLock ?? false,
        credentialId: settings.lockCredentialId,
        available,
      });

  if (verdict === 'open') return <Shell />;

  return (
    <>
      <Frame>{null}</Frame>
      <LockScreen
        credentialId={settings.lockCredentialId ?? ''}
        verdict={verdict}
        onUnlocked={() => setUnlocked(true)}
      />
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

  // One delegated listener for the whole app; the cue is chosen from what was
  // clicked. Silent unless the sounds preference is on.
  useEffect(() => installClickSounds(), []);

  const offer = useInstallOffer();
  const share = usePendingShare(settings?.currency ?? 'USD');

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
          onAdd={() => go({ kind: 'add', from: tab === 'home' ? 'home' : 'items' })}
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
        <Settings propertyId={property.id} onOpenRooms={() => go({ kind: 'rooms' })} />
      )}

      {screen.kind === 'rooms' && (
        <Rooms propertyId={property.id} onBack={() => pop({ kind: 'settings' })} />
      )}

      {/* One sheet at a time, and this one first. Being asked to install
          before anyone has said hello is the wrong order, and two stacked
          sheets on a first launch is how an app gets deleted. */}
      {!settings.onboardedAt ? (
        <Welcome />
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
 */
function useInstallOffer() {
  const [show, setShow] = useState<InstallOffer>('none');

  useEffect(() => {
    const evaluate = () => {
      const next = installOffer({
        standalone: isStandalone(),
        dismissed: wasDismissed(),
        nativePrompt: hasNativePrompt(),
        iosSafari: isIOSSafari(),
      });
      // A beat after the splash, so the app is visible behind it first.
      window.setTimeout(() => setShow(next), splashRemainingMs() + 700);
    };

    evaluate();
    return watchInstallability(evaluate);
  }, []);

  return { show, dismiss: () => setShow('none') };
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

  useSwipeNav(body, !!swipe, (direction) => {
    if (!swipe) return;
    const to = nextTab(swipe.tab, direction);
    // Nothing beyond the ends. A silent no-op at the edge reads as "that's
    // all there is", which is true and is what the bottom bar already shows.
    if (!to || to === swipe.tab) return;
    feedback('nav');
    swipe.onChange(to);
  });

  return (
    <div className="app">
      {/* Keyed by tab so the incoming screen slides from the side it came
          from — without it, the content simply replaces itself and the
          gesture has no visible consequence. */}
      <div ref={body} className="app-body" key={swipe ? swipe.tab : 'pushed'}>
        {children}
      </div>
      {nav}
    </div>
  );
}
