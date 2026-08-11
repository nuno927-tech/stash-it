import { useEffect, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db, ensureFirstRun } from '@/db/db';
import { activeItemCount, canAddItem, purgeExpiredDeletes } from '@/db/repo';
import { requestPersistence } from '@/lib/storage';
import { BottomNav, type Tab } from '@/components/BottomNav';
import { Home } from '@/screens/Home';
import { ItemDetail } from '@/screens/ItemDetail';
import { ItemForm } from '@/screens/ItemForm';
import { Items } from '@/screens/Items';
import { Placeholder } from '@/screens/Placeholder';
import { Search } from '@/screens/Search';
import { Settings } from '@/screens/Settings';
import './styles/app.css';

type BootState = { status: 'booting' } | { status: 'ready' } | { status: 'error'; error: Error };

/**
 * Screen state, not routes. There's no router yet — when Item detail needs to
 * be linkable, this is the thing that gets replaced.
 */
type Screen =
  | { kind: Tab }
  | { kind: 'add' }
  | { kind: 'detail'; id: string }
  | { kind: 'edit'; id: string };

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
  const count =
    useLiveQuery(async () => (property ? activeItemCount(property.id) : 0), [property]) ?? 0;

  const focusId = screen.kind === 'detail' || screen.kind === 'edit' ? screen.id : undefined;
  const focused = useLiveQuery(async () => (focusId ? db.items.get(focusId) : undefined), [focusId]);

  if (!property || !settings) return <Frame>{null}</Frame>;

  const mayAdd = canAddItem(count, settings.entitlements);
  const tab: Tab =
    screen.kind === 'add' || screen.kind === 'edit'
      ? 'items'
      : screen.kind === 'detail'
        ? 'items'
        : screen.kind;

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
          onSeeEndingSoon={() => setScreen({ kind: 'items' })}
        />
      )}

      {screen.kind === 'items' && (
        <Items
          propertyId={property.id}
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

      {screen.kind === 'search' && (
        <Search
          propertyId={property.id}
          onOpenItem={(id) => setScreen({ kind: 'detail', id })}
        />
      )}

      {screen.kind === 'settings' && <Settings propertyId={property.id} />}
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
