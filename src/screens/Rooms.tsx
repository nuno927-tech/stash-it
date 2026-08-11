import { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  activeRooms,
  createRoom,
  deleteRoom,
  itemCountsByRoom,
  moveRoom,
  renameRoom,
  RoomNameTakenError,
  type RoomDeleteStrategy,
} from '@/db/repo';
import { feedback } from '@/lib/feedback';
import type { Room } from '@/db/types';

/**
 * Rooms are real records, seeded per property and fully editable.
 *
 * The rule that shapes this screen: deleting a room never cascades. If it
 * holds items, the user decides where they go first — losing a dishwasher
 * because you tidied up your room list would be unforgivable.
 */
export function Rooms({ propertyId, onBack }: { propertyId: string; onBack: () => void }) {
  const rooms = useLiveQuery(() => activeRooms(propertyId), [propertyId]) ?? [];
  const counts = useLiveQuery(() => itemCountsByRoom(propertyId), [propertyId]);

  const [adding, setAdding] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState('');
  const [deleting, setDeleting] = useState<Room | null>(null);
  const [error, setError] = useState<string>();

  const byRoom = counts?.byRoom ?? new Map<string, number>();

  const add = async () => {
    const name = adding.trim();
    if (!name) return;
    setError(undefined);
    try {
      await createRoom(propertyId, name);
      feedback('save');
      setAdding('');
    } catch (e) {
      feedback('error');
      setError(e instanceof RoomNameTakenError ? e.message : (e as Error).message);
    }
  };

  const commitRename = async (room: Room) => {
    const name = draft.trim();
    setError(undefined);
    if (!name || name === room.name) {
      setEditingId(null);
      return;
    }
    try {
      await renameRoom(room.id, name);
      setEditingId(null);
    } catch (e) {
      setError(e instanceof RoomNameTakenError ? e.message : (e as Error).message);
    }
  };

  const remove = async (strategy: RoomDeleteStrategy) => {
    if (!deleting) return;
    await deleteRoom(deleting.id, strategy);
    feedback('delete');
    setDeleting(null);
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
          Rooms
        </div>
        <span style={{ width: 34 }} />
      </header>

      {error && <div className="notice bad">{error}</div>}

      <div className="seclabel">
        <span>{rooms.length} rooms</span>
        <span>{counts ? `${counts.unassigned} unassigned` : ''}</span>
      </div>

      {rooms.map((room, i) => {
        const count = byRoom.get(room.id) ?? 0;
        const editing = editingId === room.id;

        return (
          <div key={room.id} className="roomrow">
            <div className="roommove">
              <button
                type="button"
                className="iconbtn small"
                disabled={i === 0}
                aria-label={`Move ${room.name} up`}
                onClick={() => moveRoom(room.id, -1)}
              >
                <Chevron up />
              </button>
              <button
                type="button"
                className="iconbtn small"
                disabled={i === rooms.length - 1}
                aria-label={`Move ${room.name} down`}
                onClick={() => moveRoom(room.id, 1)}
              >
                <Chevron />
              </button>
            </div>

            {editing ? (
              <input
                type="text"
                value={draft}
                autoFocus
                onChange={(e) => setDraft(e.target.value)}
                onBlur={() => commitRename(room)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') commitRename(room);
                  if (e.key === 'Escape') setEditingId(null);
                }}
              />
            ) : (
              <button
                type="button"
                className="roomname"
                onClick={() => {
                  setEditingId(room.id);
                  setDraft(room.name);
                }}
              >
                <span>{room.name}</span>
                <small>
                  {count} {count === 1 ? 'item' : 'items'}
                  {room.isSeed ? '' : ' · yours'}
                </small>
              </button>
            )}

            <button
              type="button"
              className="iconbtn small"
              aria-label={`Delete ${room.name}`}
              onClick={() => setDeleting(room)}
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
          </div>
        );
      })}

      <div className="addroom">
        <input
          type="text"
          value={adding}
          placeholder="Add a room"
          onChange={(e) => setAdding(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && add()}
        />
        <button type="button" className="minibtn" disabled={!adding.trim()} onClick={add}>
          Add
        </button>
      </div>

      {deleting && (
        <DeleteRoom
          room={deleting}
          itemCount={byRoom.get(deleting.id) ?? 0}
          others={rooms.filter((r) => r.id !== deleting.id)}
          onCancel={() => setDeleting(null)}
          onConfirm={remove}
        />
      )}

      <p className="hint" style={{ marginTop: 22 }}>
        Tap a room to rename it. Deleting one never deletes what's inside — you'll be asked where
        those items should go.
      </p>
    </>
  );
}

function DeleteRoom({
  room,
  itemCount,
  others,
  onCancel,
  onConfirm,
}: {
  room: Room;
  itemCount: number;
  others: Room[];
  onCancel: () => void;
  onConfirm: (s: RoomDeleteStrategy) => void;
}) {
  const [toRoomId, setToRoomId] = useState(others[0]?.id ?? '');

  if (itemCount === 0) {
    return (
      <div className="sheet">
        <h4>Delete {room.name}? It's empty, so nothing moves.</h4>
        <div className="photoactions">
          <button type="button" className="minibtn" onClick={() => onConfirm({ kind: 'unassign' })}>
            Delete
          </button>
          <button type="button" className="minibtn ghost" onClick={onCancel}>
            Cancel
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="sheet">
      <h4>
        {room.name} holds {itemCount} {itemCount === 1 ? 'item' : 'items'}. Where should{' '}
        {itemCount === 1 ? 'it' : 'they'} go?
      </h4>

      {others.length > 0 && (
        <>
          <label className="field">
            <span className="fieldlabel">Move to</span>
            <select value={toRoomId} onChange={(e) => setToRoomId(e.target.value)}>
              {others.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.name}
                </option>
              ))}
            </select>
          </label>
          <button
            type="button"
            className="choice"
            onClick={() => onConfirm({ kind: 'reassign', toRoomId })}
          >
            <b>Move and delete</b>
            <span>Everything lands in the room you picked.</span>
          </button>
        </>
      )}

      <button type="button" className="choice" onClick={() => onConfirm({ kind: 'unassign' })}>
        <b>Leave them unassigned</b>
        <span>The items stay, with no room set. You can assign them later.</span>
      </button>

      <button type="button" className="btn ghost" onClick={onCancel}>
        Cancel
      </button>
    </div>
  );
}

function Chevron({ up }: { up?: boolean }) {
  return (
    <svg
      width="15"
      height="15"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.4"
      strokeLinecap="round"
      strokeLinejoin="round"
      style={up ? { transform: 'rotate(180deg)' } : undefined}
    >
      <path d="M6 9l6 6 6-6" />
    </svg>
  );
}
