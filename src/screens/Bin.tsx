import { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import {
  activeItemCount,
  deletedItems,
  emptyBin,
  purgeItemNow,
  PURGE_AFTER_DAYS,
  restoreItem,
} from '@/db/repo';
import type { Item } from '@/db/types';
import {
  binCount,
  canRestore,
  daysLeft,
  daysLeftLabel,
  restoreBlockedReason,
} from '@/lib/bin';
import { feedback } from '@/lib/feedback';
import { ItemIcon } from '@/components/ItemIcon';
import { Scout } from '@/components/Scout';
import { ScoutDialog } from '@/components/ScoutDialog';

/**
 * Recently deleted.
 *
 * The delete dialog has always said an item goes to the bin for thirty days so
 * you can change your mind. That was true of the database and of nothing else:
 * items were soft-deleted, counted down and purged, and `restoreItem` sat in
 * the repo with no caller. A recovery window you can't reach is just a delay
 * before the deletion.
 *
 * It lives off the Items list rather than in Settings, because a bin belongs
 * with the things it holds — you go looking for a deleted item where the items
 * are, the same way you look for a deleted photo in the photo app and not in
 * the phone's settings. And it only appears when it has something in it: an
 * empty bin is a row that answers no question, and the moment the promise is
 * made is a moment there is certainly something inside.
 */
export function Bin({ propertyId, onBack }: { propertyId: string; onBack: () => void }) {
  const items = useLiveQuery(() => deletedItems(propertyId), [propertyId]);
  const active = useLiveQuery(() => activeItemCount(propertyId), [propertyId]) ?? 0;
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);

  const [blocked, setBlocked] = useState<string>();
  const [purging, setPurging] = useState<Item | null>(null);
  const [emptying, setEmptying] = useState(false);

  if (!items || !settings) return null;

  const room = canRestore(active, settings.entitlements);

  const restore = async (item: Item) => {
    if (!room) {
      feedback('error');
      setBlocked(restoreBlockedReason(active));
      return;
    }
    setBlocked(undefined);
    await restoreItem(item.id);
    feedback('save');
  };

  return (
    <>
      <header className="apphead">
        <button type="button" className="iconbtn" onClick={onBack} aria-label="Back">
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
          >
            <path d="M15 5l-7 7 7 7" />
          </svg>
        </button>
        <div className="apptitle" style={{ fontSize: 19 }}>
          Recently deleted
        </div>
        <span style={{ width: 34 }} />
      </header>

      {items.length === 0 ? (
        <div className="empty">
          <Scout pose="resting" height={150} motion={['breathe']} shadow alt="" />
          <h3>Nothing in here</h3>
          <p>
            Deleted items wait {PURGE_AFTER_DAYS} days before they're erased. None are waiting.
          </p>
        </div>
      ) : (
        <>
          {/* Scout up to his elbows in the wastepaper basket, which is the
              screen's whole proposition — nothing here has gone yet. */}
          <div className="binmark">
            <Scout pose="bin" height={130} motion={['breathe']} alt="" />
            <p>
              Nothing has gone yet. Anything here can come straight back, with its photos and
              documents, until its {PURGE_AFTER_DAYS} days run out.
            </p>
          </div>

          <div className="seclabel">
            <span>{binCount(items.length)}</span>
            <span>Erased after {PURGE_AFTER_DAYS} days</span>
          </div>

          {blocked && <div className="notice bad">{blocked}</div>}

          <ul className="binlist">
            {items.map((item) => {
              const left = daysLeft(item.deletedAt ?? '');
              return (
                <li key={item.id} className="binrow">
                  <ItemIcon item={item} size={38} />

                  <span className="bintxt">
                    <strong>{item.name}</strong>
                    {/* The countdown is the whole reason for the screen, so it
                        goes red as it runs out rather than staying grey. */}
                    <small className={left <= 3 ? 'urgent' : undefined}>
                      {daysLeftLabel(left)}
                    </small>
                  </span>

                  <button
                    type="button"
                    className="minibtn"
                    onClick={() => void restore(item)}
                    aria-label={`Restore ${item.name}`}
                  >
                    Restore
                  </button>

                  <button
                    type="button"
                    className="iconbtn small"
                    aria-label={`Delete ${item.name} permanently`}
                    onClick={() => setPurging(item)}
                  >
                    <svg
                      width="17"
                      height="17"
                      viewBox="0 0 24 24"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                    >
                      <path d="M6 6l12 12M18 6L6 18" />
                    </svg>
                  </button>
                </li>
              );
            })}
          </ul>

          <button
            type="button"
            className="btn ghost wide"
            style={{ marginTop: 18 }}
            aria-haspopup="dialog"
            onClick={() => setEmptying(true)}
          >
            Empty the bin
          </button>

          <p className="hint">
            Restoring puts an item back exactly as it was, with its photos and documents. Until
            then it doesn't count towards the free tier — which is why restoring can be blocked
            when you're full, and why nothing in here is ever removed to make room.
          </p>
        </>
      )}

      {purging && (
        <ScoutDialog
          pose="alert"
          height={190}
          title={`Erase ${purging.name}?`}
          alt="Scout, ears up"
          onClose={() => setPurging(null)}
        >
          <p>
            This one skips the wait. It and its photos and documents go now, and there's no
            getting them back.
          </p>
          <div className="dlgactions">
            <button
              type="button"
              className="choice danger"
              onClick={() => {
                void purgeItemNow(purging.id).then(() => feedback('delete'));
                setPurging(null);
              }}
            >
              <b>Erase permanently</b>
              <span>Gone for good, right now.</span>
            </button>
            <button type="button" className="btn ghost wide" onClick={() => setPurging(null)}>
              Leave it here
            </button>
          </div>
        </ScoutDialog>
      )}

      {emptying && (
        <ScoutDialog
          pose="alert"
          height={190}
          title={`Erase all ${binCount(items.length)}?`}
          alt="Scout, ears up"
          onClose={() => setEmptying(false)}
        >
          <p>
            Everything in here goes now, with its photos and documents. Nothing outside the bin is
            touched.
          </p>
          <div className="dlgactions">
            <button
              type="button"
              className="choice danger"
              onClick={() => {
                void emptyBin(propertyId).then(() => feedback('delete'));
                setEmptying(false);
              }}
            >
              <b>Empty the bin</b>
              <span>Gone for good, right now.</span>
            </button>
            <button type="button" className="btn ghost wide" onClick={() => setEmptying(false)}>
              Keep them
            </button>
          </div>
        </ScoutDialog>
      )}
    </>
  );
}
