import { useEffect, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, ensureFirstRun } from '@/db/db';
import { activeItemCount, canAddItem, purgeExpiredDeletes } from '@/db/repo';
import { configureFeedback } from '@/lib/feedback';
import { prefsFrom } from '@/lib/prefs';
import { requestPersistence } from '@/lib/storage';
import { applyTheme, watchSystemTheme } from '@/lib/theme';
import { BottomNav, type Tab } from '@/components/BottomNav';
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
type Screen =
  | { kind: 'home' }
  | { kind: 'items'; filter?: ItemsFilter }
  | { kind: 'settings' }
  | { kind: 'add' }
  | { kind: 'rooms' }
  | { kind: 'detail'; id: string }
  | { kind: 'edit'; id: string };

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

  if (boot.status === 'booting') return <Frame>{null}</Frame>;

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

  return <Shell />;
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
  const count =
    useLiveQuery(async () => (property ? activeItemCount(property.id) : 0), [property]) ?? 0;

  const focusId = screen.kind === 'detail' || screen.kind === 'edit' ? screen.id : undefined;
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
          onAdd={() => setScreen({ kind: 'add' })}
          addDisabled={!mayAdd}
        />
      }
    >
      {screen.kind === 'home' && (
        <Home
          propertyId={property.id}
          onAdd={() => setScreen({ kind: 'add' })}
          onOpenItem={(id) => setScreen({ kind: 'detail', id })}
          onBrowse={(filter) => setScreen({ kind: 'items', filter })}
        />
      )}

      {screen.kind === 'items' && (
        <Items
          key={screen.filter ?? 'all'}
          propertyId={property.id}
          filter={screen.filter}
          onOpenItem={(id) => setScreen({ kind: 'detail', id })}
          onAdd={() => setScreen({ kind: 'add' })}
        />
      )}

      {screen.kind === 'detail' && focused && (
        <ItemDetail
          item={focused}
          onBack={() => setScreen({ kind: 'items' })}
          onEdit={() => setScreen({ kind: 'edit', id: focused.id })}
          onDeleted={() => setScreen({ kind: 'items' })}
        />
      )}

      {screen.kind === 'edit' && focused && (
        <ItemForm
          propertyId={property.id}
          currency={settings.currency}
          item={focused}
          onSaved={(id) => setScreen({ kind: 'detail', id })}
          onCancel={() => setScreen({ kind: 'detail', id: focused.id })}
        />
      )}

      {screen.kind === 'add' &&
        (mayAdd ? (
          <ItemForm
            propertyId={property.id}
            currency={settings.currency}
            onSaved={(id) => setScreen({ kind: 'detail', id })}
            onCancel={() => setScreen({ kind: 'home' })}
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
    </Frame>
  );
}

function Frame({ children, nav }: { children: ReactNode; nav?: ReactNode }) {
  return (
    <div className="app">
      <div className="app-body">{children}</div>
      {nav}
    </div>
  );
}
