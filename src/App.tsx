import { useEffect, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, ensureFirstRun } from '@/db/db';
import { activeItemCount, canAddItem, purgeExpiredDeletes } from '@/db/repo';
import { configureFeedback, installClickSounds } from '@/lib/feedback';
import {
  hasNativePrompt,
  installOffer,
  isIOSSafari,
  isStandalone,
  wasDismissed,
  watchInstallability,
  type InstallOffer,
} from '@/lib/install';
import { biometricsAvailable, lockVerdict, type LockVerdict } from '@/lib/lock';
import { prefsFrom } from '@/lib/prefs';
import { dismissSplash, splashRemainingMs } from '@/lib/splash';
import { requestPersistence } from '@/lib/storage';
import { applyTheme, watchSystemTheme } from '@/lib/theme';
import { BottomNav, type Tab } from '@/components/BottomNav';
import { InstallPrompt } from '@/components/InstallPrompt';
import { LockScreen } from '@/components/LockScreen';
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

function Shell() {
  const [screen, setScreen] = useState<Screen>({ kind: 'home' });

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

  // A deleted or missing record must not leave the user on a blank screen.
  if ((screen.kind === 'detail' || screen.kind === 'edit') && focused === undefined) {
    return <Frame>{null}</Frame>;
  }

  return (
    <Frame
      nav={
        <BottomNav
          active={tab}
          onChange={(t) => setScreen({ kind: t })}
          onAdd={() => setScreen({ kind: 'add', from: tab === 'home' ? 'home' : 'items' })}
          addDisabled={!mayAdd}
        />
      }
    >
      {screen.kind === 'home' && (
        <Home
          propertyId={property.id}
          onAdd={() => setScreen({ kind: 'add', from: 'home' })}
          onOpenItem={(id) => setScreen({ kind: 'detail', id, from: 'home' })}
          onBrowse={(filter) => setScreen({ kind: 'items', filter })}
        />
      )}

      {screen.kind === 'items' && (
        <Items
          key={screen.filter ?? 'all'}
          propertyId={property.id}
          filter={screen.filter}
          onOpenItem={(id) => setScreen({ kind: 'detail', id, from: 'items' })}
          onAdd={() => setScreen({ kind: 'add', from: 'items' })}
        />
      )}

      {screen.kind === 'detail' && focused && (
        <ItemDetail
          item={focused}
          onBack={() => setScreen(back())}
          onEdit={() => setScreen({ kind: 'edit', id: focused.id, from: origin })}
          onDeleted={() => setScreen(back())}
        />
      )}

      {screen.kind === 'edit' && focused && (
        <ItemForm
          propertyId={property.id}
          currency={settings.currency}
          item={focused}
          onSaved={(id) => setScreen({ kind: 'detail', id, from: origin })}
          onCancel={() => setScreen({ kind: 'detail', id: focused.id, from: origin })}
        />
      )}

      {screen.kind === 'add' &&
        (mayAdd ? (
          <ItemForm
            propertyId={property.id}
            currency={settings.currency}
            onSaved={(id) => setScreen({ kind: 'detail', id, from: origin })}
            onCancel={() => setScreen(back())}
          />
        ) : (
          <Placeholder
            title="Free tier is full"
            note={`You're at ${count} items. Everything you've saved stays editable and exportable — only new items are blocked.`}
          />
        ))}

      {screen.kind === 'settings' && (
        <Settings propertyId={property.id} onOpenRooms={() => setScreen({ kind: 'rooms' })} />
      )}

      {screen.kind === 'rooms' && (
        <Rooms propertyId={property.id} onBack={() => setScreen({ kind: 'settings' })} />
      )}

      {offer.show !== 'none' && (
        <InstallPrompt offer={offer.show} onClose={offer.dismiss} />
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

function Frame({ children, nav }: { children: ReactNode; nav?: ReactNode }) {
  return (
    <div className="app">
      <div className="app-body">{children}</div>
      {nav}
    </div>
  );
}
