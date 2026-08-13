import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import {
  activeRooms,
  createRoom,
  deleteRoom,
  itemCountsByRoom,
  moveRoom,
  renameRoom,
  reorderRooms,
  RoomNameTakenError,
  type RoomDeleteStrategy,
} from '@/db/repo';
import { feedback } from '@/lib/feedback';
import { dropTarget, moveWithin } from '@/lib/reorder';
import { RoomIcon } from '@/components/RoomIcon';
import type { Room } from '@/db/types';

/**
 * Rooms are real records, seeded per property and fully editable.
 *
 * The rule that shapes this screen: deleting a room never cascades. If it
 * holds items, the user decides where they go first — losing a dishwasher
 * because you tidied up your room list would be unforgivable.
 */
/* A stable empty array. `useLiveQuery(...) ?? []` builds a fresh one on every
   render until the query resolves, and the reorder hook watches that value —
   a new reference each render meant it reset its own state each render. */
const NO_ROOMS: Room[] = [];

export function Rooms({ propertyId, onBack }: { propertyId: string; onBack: () => void }) {
  const rooms = useLiveQuery(() => activeRooms(propertyId), [propertyId]) ?? NO_ROOMS;
  const counts = useLiveQuery(() => itemCountsByRoom(propertyId), [propertyId]);

  const [adding, setAdding] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState('');
  const [deleting, setDeleting] = useState<Room | null>(null);
  const [error, setError] = useState<string>();

  const drag = useDragOrder(rooms, (ids) => reorderRooms(propertyId, ids));
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

      {/* The two numbers have to add up to what you own, so the total is
          stated rather than left to be inferred from a list you'd have to
          sum yourself. */}
      <div className="seclabel">
        <span>{rooms.length} rooms</span>
        <span>
          {counts
            ? `${counts.total} ${counts.total === 1 ? 'item' : 'items'}${
                counts.unassigned ? ` · ${counts.unassigned} unassigned` : ''
              }`
            : ''}
        </span>
      </div>

      <ul
        className="roomlist"
        onPointerMove={drag.onPointerMove}
        onPointerUp={drag.onPointerUp}
        onPointerCancel={drag.onPointerCancel}
      >
        {drag.order.map((room, i) => {
          const count = byRoom.get(room.id) ?? 0;
          const editing = editingId === room.id;
          const held = drag.heldId === room.id;

          return (
            <li
              key={room.id}
              ref={drag.rowRef(i)}
              className={`roomrow${held ? ' held' : ''}`}
              style={held ? { transform: `translateY(${drag.offset}px)` } : undefined}
            >
              {/*
                A grip rather than the whole row: the row is also the rename
                target, and a list where touching a name might drag it instead
                is a list nobody trusts. Drawn as a button — a filled chip with
                a border — because as six bare dots it read as decoration and
                nobody knew the list could be reordered at all.
              */}
              <button
                type="button"
                className="grip"
                aria-label={`Reorder ${room.name}. Currently ${i + 1} of ${drag.order.length}. Use the arrow keys to move it.`}
                data-cue="none"
                onPointerDown={(e) => drag.start(e, i)}
                onKeyDown={(e) => {
                  if (e.key !== 'ArrowUp' && e.key !== 'ArrowDown') return;
                  e.preventDefault();
                  feedback('tap');
                  void moveRoom(room.id, e.key === 'ArrowUp' ? -1 : 1);
                }}
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                  <circle cx="9" cy="6" r="1.5" />
                  <circle cx="15" cy="6" r="1.5" />
                  <circle cx="9" cy="12" r="1.5" />
                  <circle cx="15" cy="12" r="1.5" />
                  <circle cx="9" cy="18" r="1.5" />
                  <circle cx="15" cy="18" r="1.5" />
                </svg>
              </button>

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
                  <span className="roomtitle">
                    <i className="roomglyph">
                      <RoomIcon name={room.name} size={19} />
                    </i>
                    {room.name}
                  </span>
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
                aria-expanded={deleting?.id === room.id}
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
            </li>
          );
        })}
      </ul>

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
        Drag the handle to reorder, tap a room to rename it. Deleting one never deletes what's
        inside — you'll be asked where those items should go.
      </p>
    </>
  );
}

/**
 * Pointer-based drag reordering.
 *
 * Pointer events rather than HTML5 drag and drop, which simply doesn't fire on
 * touch — the API predates phones and was never retrofitted. Pointer events
 * cover mouse, touch and pen with one code path.
 *
 * The list reorders live as you drag, so the gap under your finger is always
 * where the row will land. Nothing is written until you let go.
 */
function useDragOrder(rooms: Room[], commit: (ids: string[]) => Promise<unknown>) {
  const [order, setOrder] = useState<Room[]>(rooms);
  const [heldId, setHeldId] = useState<string | null>(null);
  const [offset, setOffset] = useState(0);

  const rows = useRef<(HTMLLIElement | null)[]>([]);
  const from = useRef(0);
  const startY = useRef(0);
  const live = useRef<Room[]>(rooms);

  // Follow the database unless a drag is in flight, in which case the local
  // order is the truth until it's committed.
  useEffect(() => {
    if (heldId) return;
    setOrder(rooms);
    live.current = rooms;
  }, [rooms, heldId]);

  const rowRef = (i: number) => (el: HTMLLIElement | null) => {
    rows.current[i] = el;
  };

  const start = (e: ReactPointerEvent, index: number) => {
    e.preventDefault();
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
    from.current = index;
    startY.current = e.clientY;
    live.current = order;
    setHeldId(order[index]?.id ?? null);
    setOffset(0);
    feedback('tap');
  };

  const move = (e: ReactPointerEvent) => {
    if (!heldId) return;
    const dy = e.clientY - startY.current;
    setOffset(dy);

    // Which row is the pointer over now? Measured rather than assumed, because
    // rows aren't all the same height once one is being renamed — and skipping
    // the held row, whose box follows the finger and would otherwise match
    // every time. See src/lib/reorder.ts.
    const spans = rows.current.map((el) => (el ? el.getBoundingClientRect() : null));
    const at = dropTarget(spans, e.clientY, from.current);
    if (at === null) return;

    const next = moveWithin(live.current, from.current, at);
    if (next === live.current) return;

    live.current = next;
    from.current = at;
    startY.current = e.clientY;
    setOffset(0);
    setOrder(next);
    feedback('tap');
  };

  const end = () => {
    if (!heldId) return;
    setHeldId(null);
    setOffset(0);
    const ids = live.current.map((r) => r.id);
    void commit(ids).then((written) => {
      if (written) feedback('save');
    });
  };

  return {
    order,
    heldId,
    offset,
    rowRef,
    start,
    // Attached to the row rather than the grip: a finger that outruns the
    // handle mid-drag shouldn't drop the row.
    onPointerMove: move,
    onPointerUp: end,
    onPointerCancel: end,
  };
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
