import { useEffect, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, ensureFirstRun } from '@/db/db';
import { activeItemCount, canAddItem, purgeExpiredDeletes } from '@/db/repo';
import { requestPersistence } from '@/lib/storage';
import { BottomNav, type Tab } from '@/components/BottomNav';
import { AddItem } from '@/screens/AddItem';
import { Home } from '@/screens/Home';
import { Placeholder } from '@/screens/Placeholder';
import { Settings } from '@/screens/Settings';
import './styles/app.css';

type BootState = { status: 'booting' } | { status: 'ready' } | { status: 'error'; error: Error };

/** Screens reachable right now. 'add' isn't a tab — the FAB pushes to it. */
type Screen = Tab | 'add';

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

  if (boot.status === 'booting') {
    return <Frame>{null}</Frame>;
  }

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
  const [screen, setScreen] = useState<Screen>('home');

  const property = useLiveQuery(() => db.properties.filter((p) => !p.deletedAt).first(), []);
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);
  const count =
    useLiveQuery(async () => (property ? activeItemCount(property.id) : 0), [property]) ?? 0;

  if (!property || !settings) return <Frame>{null}</Frame>;

  const mayAdd = canAddItem(count, settings.entitlements);
  const tab: Tab = screen === 'add' ? 'home' : screen;

  return (
    <Frame
      nav={
        <BottomNav
          active={tab}
          onChange={setScreen}
          onAdd={() => setScreen('add')}
          addDisabled={!mayAdd}
        />
      }
    >
      {screen === 'home' && (
        <Home
          propertyId={property.id}
          onAdd={() => setScreen('add')}
          onOpenItem={() => setScreen('items')}
          onSeeEndingSoon={() => setScreen('items')}
        />
      )}

      {screen === 'add' &&
        (mayAdd ? (
          <AddItem
            propertyId={property.id}
            currency={settings.currency}
            onSaved={() => setScreen('home')}
            onCancel={() => setScreen('home')}
          />
        ) : (
          <Placeholder
            title="Free tier is full"
            note={`You're at ${count} items. Everything you've saved stays editable and exportable — only new items are blocked.`}
          />
        ))}

      {screen === 'items' && (
        <Placeholder title="Items" note="The full list, with filters by room and category." />
      )}

      {screen === 'search' && (
        <Placeholder title="Search" note="Across names, brands, models and serial numbers." />
      )}

      {screen === 'settings' && <Settings propertyId={property.id} />}
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
