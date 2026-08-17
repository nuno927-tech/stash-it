import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeRooms, createRoom, RoomNameTakenError } from '@/db/repo';
import type { Item } from '@/db/types';
import {
  emptyForm,
  formFromItem,
  ItemLimitError,
  saveEditedItem,
  saveNewItem,
  ValidationError,
  type AddItemForm,
  type PhotoEdit,
} from '@/lib/addItem';
import { attachStaged, stageDocs, type StagedDoc } from '@/lib/docs';
import { feedback } from '@/lib/feedback';
import { completeMoneyInput, currencySymbol, formatMoneyInput } from '@/lib/format';
import { PhotoError, storePhoto } from '@/lib/photo';
import { ChoiceSheet } from '@/components/ChoiceSheet';
import { Scout } from '@/components/Scout';
import { CoverageField } from '@/components/CoverageField';
import { DocsField } from '@/components/DocsField';
import { useAutoAdvance } from '@/components/useAutoAdvance';

/**
 * One form, two modes: pass an `item` to edit it, omit one to create.
 *
 * FOUR SECTIONS, AND THE WORD "OPTIONAL".
 *
 * The screen has been through three shapes. It was cards grouped by nothing in
 * particular — identity, room, purchase, coverage, documents — which read as
 * paperwork. Then it was three questions with everything else behind a door,
 * which was less crowded but hid fields people wanted to fill in at the time.
 *
 * This is the third and it solves the original complaint differently. The
 * problem was never how many fields there are; it was that twelve fields at
 * one visual weight give no clue which ones matter. Hiding them answered that
 * by concealment. Saying "Optional" in the field answers it by telling the
 * truth, and costs nothing — you can see the whole shape of the record and
 * still know, at a glance, that seven of the nine boxes can be left alone.
 *
 * Two things are therefore not marked optional, and both are load-bearing:
 *
 *   name      an item with no name can't be found again
 *   date      the countdown is arithmetic on this date; without it a warranty
 *             length is a number with nothing to subtract from
 *
 * The date can't carry the word inside itself in any case: a native date input
 * ignores `placeholder` entirely and draws its own mm/dd/yyyy from `lang`.
 *
 * Save is a sticky bar rather than a button at each end. On a screen this long
 * a top-right Save is out of thumb reach, and two of them is one too many.
 */

/** What goes in an optional text field, so the label doesn't have to say it. */
const OPTIONAL = 'Optional';

export function ItemForm({
  propertyId,
  currency,
  item,
  prefill,
  prestaged,
  banner,
  onSaved,
  onCancel,
}: {
  propertyId: string;
  currency: string;
  item?: Item;
  /** Fields filled in from somewhere else — a shared receipt, say. */
  prefill?: Partial<AddItemForm>;
  /** Documents that arrived with it, already staged. */
  prestaged?: StagedDoc[];
  /** A line explaining where all of that came from. */
  banner?: string;
  onSaved: (id: string) => void;
  onCancel: () => void;
}) {
  const editing = !!item;
  const rooms = useLiveQuery(() => activeRooms(propertyId), [propertyId]) ?? [];

  const [form, setForm] = useState<AddItemForm>(() =>
    item ? formFromItem(item, currency) : { ...emptyForm(currency), ...prefill },
  );
  // undefined = untouched, PhotoRefs = replaced, null = removed.
  const [photo, setPhoto] = useState<PhotoEdit>(undefined);
  const [preview, setPreview] = useState<string>();
  const [removed, setRemoved] = useState(false);
  const [staged, setStaged] = useState<StagedDoc[]>(() => prestaged ?? []);
  const [newRoom, setNewRoom] = useState<string | null>(null);
  const [picking, setPicking] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();

  // Two inputs, not one. `capture` is the only way to guarantee the camera
  // opens; without it the picker goes straight to the photo library on some
  // devices, with no way through to the camera at all.
  const cameraInput = useRef<HTMLInputElement>(null);
  const libraryInput = useRef<HTMLInputElement>(null);

  const existingThumb = useLiveQuery(
    async () => (item?.thumbBlobId ? db.blobs.get(item.thumbBlobId) : undefined),
    [item?.thumbBlobId],
  );
  useEffect(() => {
    if (!existingThumb || preview || removed) return;
    const url = URL.createObjectURL(existingThumb.data);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [existingThumb]);

  const set = <K extends keyof AddItemForm>(key: K, value: AddItemForm[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  /*
    The date is required — but requiring it of an item that never had one
    would strand every record saved before this rule, and every record whose
    date is genuinely unknown. Forcing a guess is worse than an empty field:
    an absent date makes the app say "no warranty recorded", while an invented
    one makes it count down to a day that means nothing.

    So: always on a new item, and on an edit only if there was a date to begin
    with. You can't clear one, you're not made to invent one.
  */
  const dateRequired = !editing || !!item?.purchaseDate;
  const missingDate = dateRequired && !form.purchaseDate.trim();
  const canSave = !!form.name.trim() && !missingDate;

  /*
    Move on when a card is finished with. Watched on the answers that arrive as
    a tap — a date picked, a warranty term chosen — never on typing, so the
    page can't jump mid-word. See useAutoAdvance.
  */
  const roomRef = useRef<HTMLElement>(null);
  const coverRef = useRef<HTMLElement>(null);
  const docsRef = useRef<HTMLElement>(null);
  useAutoAdvance(!!form.name.trim() && !!form.purchaseDate.trim(), roomRef);
  useAutoAdvance(!!form.roomId, coverRef);
  useAutoAdvance(
    form.coverages.some((c) => c.unit === 'lifetime' || !!c.amount.trim()),
    docsRef,
  );

  const addRoom = async () => {
    const name = (newRoom ?? '').trim();
    if (!name) return setNewRoom(null);
    try {
      const id = await createRoom(propertyId, name);
      set('roomId', id);
      setNewRoom(null);
      feedback('save');
    } catch (e) {
      feedback('error');
      setError(e instanceof RoomNameTakenError ? e.message : (e as Error).message);
    }
  };

  /**
   * The first picture becomes the item's face; the rest are staged as photo
   * documents. An item has exactly one image that represents it in a list, but
   * no reason to be limited to one image — the serial plate, the damage and
   * the box it came in are all worth keeping, and making someone attach them
   * one at a time through a different control is the reason they don't.
   */
  const onPhotos = async (files: FileList | null) => {
    const picked = files ? [...files] : [];
    if (picked.length === 0) return;

    setBusy(true);
    setError(undefined);
    try {
      const [first, ...rest] = picked;
      const refs = await storePhoto(first!);
      setPhoto(refs);
      setRemoved(false);
      setPreview((old) => {
        if (old) URL.revokeObjectURL(old);
        return URL.createObjectURL(first!);
      });

      if (rest.length) {
        const already = staged.filter((s) => s.kind === 'photo').length;
        for (const doc of stageDocs('photo', rest, already)) setStaged((s) => [...s, doc]);
      }
      feedback('attach');
    } catch (e) {
      feedback('error');
      setError(e instanceof PhotoError ? e.message : 'Could not read that photo.');
    } finally {
      setBusy(false);
    }
  };

  const onSave = async () => {
    setBusy(true);
    setError(undefined);
    try {
      const id = item
        ? await saveEditedItem(item.id, form, propertyId, photo)
        : await saveNewItem(form, propertyId, photo ?? undefined);

      if (staged.length) await attachStaged(id, staged);

      if (preview) URL.revokeObjectURL(preview);
      feedback('save');
      onSaved(id);
    } catch (e) {
      feedback('error');
      if (e instanceof ValidationError || e instanceof ItemLimitError) setError(e.message);
      else setError(`Could not save: ${(e as Error).message}`);
      setBusy(false);
    }
  };

  return (
    <div className="formwrap">
      <header className="apphead">
        <button type="button" className="iconbtn" onClick={onCancel} aria-label="Cancel">
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
          >
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
        <div className="apptitle" style={{ fontSize: 19 }}>
          {editing ? 'Edit item' : 'New item'}
        </div>
        <span style={{ width: 34 }} />
      </header>

      {error && <div className="notice bad">{error}</div>}
      {banner && !error && <div className="notice ok">{banner}</div>}

      {/* ---------------------------------------------- product information */}
      <section className="card formcard">
        <div className="cardhead">
          <h3>Product information</h3>
          {/* Glasses on, pencil out. He's doing the same job the section is,
              and he sits in the heading rather than taking a row of his own —
              the screen was just decluttered and a mascot with its own card
              would be the first thing to put back. */}
          <Scout pose="clipboard" height={62} motion={['breathe']} alt="" />
        </div>

        {/* The photo sits beside the name rather than above it: a full-width
            dropzone pushed the first real question below the fold. */}
        <div className="identity">
          {/* The square says what it is for. A separate button underneath
              repeated a control the user was already looking at — the slot is
              the obvious place to tap, so it should be the one that's
              labelled. */}
          <button
            type="button"
            className="photoslot"
            onClick={() => setPicking(true)}
            disabled={busy}
            aria-label={preview ? 'Replace the photo' : 'Upload a photo'}
          >
            {preview ? (
              <img src={preview} alt="" />
            ) : (
              <>
                <CameraGlyph />
                <small>Upload photo</small>
              </>
            )}
          </button>

          {/* No "optional" here, and that absence is the whole signal: it
              only reads as "required" because every other text field on the
              screen says otherwise. */}
          <label className="field grow">
            <span className="fieldlabel">Product name</span>
            <input
              type="text"
              className="bigname"
              value={form.name}
              onChange={(e) => set('name', e.target.value)}
              placeholder="What is it?"
              autoFocus={!editing}
            />
          </label>
        </div>

        {preview && (
          <div className="photorow">
            <button
              type="button"
              className="linkish"
              onClick={() => {
                URL.revokeObjectURL(preview);
                setPreview(undefined);
                setPhoto(null);
                setRemoved(true);
              }}
            >
              Remove photo
            </button>
          </div>
        )}

        {picking && (
          <ChoiceSheet
            title="Add a photo"
            choices={[
              {
                key: 'camera',
                label: 'Take a photo',
                note: "For the thing itself, when it's in front of you.",
                icon: <CameraGlyph />,
              },
              {
                key: 'gallery',
                label: 'Upload from gallery',
                note: 'Pick one or several — the first becomes the item’s picture.',
                icon: <GalleryGlyph />,
              },
            ]}
            onCancel={() => setPicking(false)}
            onPick={(key) => {
              setPicking(false);
              // `capture` is the only thing that guarantees the camera opens;
              // without it some devices go straight to the library with no way
              // through. That's why these stay two separate inputs.
              (key === 'camera' ? cameraInput : libraryInput).current?.click();
            }}
          />
        )}

        <input
          ref={cameraInput}
          type="file"
          accept="image/*"
          capture="environment"
          multiple
          hidden
          onChange={(e) => {
            void onPhotos(e.target.files);
            e.target.value = '';
          }}
        />
        <input
          ref={libraryInput}
          type="file"
          accept="image/*"
          multiple
          hidden
          onChange={(e) => {
            void onPhotos(e.target.files);
            e.target.value = '';
          }}
        />

        {/* Not marked optional, because the countdown is arithmetic on it.
            `lang` is what decides the order the browser draws the boxes in and
            what it writes in the empty ones — without it the control follows
            the device locale and shows dd/mm/yyyy on half of them. The value
            itself is always ISO either way; this is display only. */}
        <Field label="When did you buy it?">
          <input
            type="date"
            lang="en-US"
            value={form.purchaseDate}
            onChange={(e) => set('purchaseDate', e.target.value)}
          />
        </Field>

        <div className="fieldpair">
          {/* Keeps the worked example rather than saying "Optional": it's the
              only thing on the screen telling you decimals are accepted. */}
          <Field label="Price">
            <div className="moneyfield">
              <span aria-hidden="true">{currencySymbol(form.currency)}</span>
              <input
                type="text"
                inputMode="decimal"
                value={form.price}
                onChange={(e) => set('price', formatMoneyInput(e.target.value, form.currency))}
                onBlur={() => set('price', completeMoneyInput(form.price, form.currency))}
                placeholder="849.00"
              />
            </div>
          </Field>
          <Field label="Brand">
            <input
              type="text"
              value={form.brand}
              onChange={(e) => set('brand', e.target.value)}
              placeholder={OPTIONAL}
            />
          </Field>
        </div>

        <div className="fieldpair">
          <Field label="Model">
            <input
              type="text"
              value={form.model}
              onChange={(e) => set('model', e.target.value)}
              placeholder={OPTIONAL}
            />
          </Field>
          <Field label="Serial number">
            <input
              type="text"
              value={form.serial}
              onChange={(e) => set('serial', e.target.value)}
              placeholder={OPTIONAL}
            />
          </Field>
        </div>

        <Field label="Retailer">
          <input
            type="text"
            value={form.retailer}
            onChange={(e) => set('retailer', e.target.value)}
            placeholder={OPTIONAL}
          />
        </Field>

        <Field label="Notes">
          <textarea
            rows={3}
            value={form.notes}
            onChange={(e) => set('notes', e.target.value)}
            placeholder={OPTIONAL}
          />
        </Field>
      </section>

      {/* ------------------------------------------------------------- room */}
      <section className="card formcard" ref={roomRef}>
        <div className="cardhead">
          <h3>Room</h3>
          <button
            type="button"
            className="linkish"
            aria-expanded={newRoom !== null}
            onClick={() => setNewRoom(newRoom === null ? '' : null)}
          >
            {newRoom === null ? 'New room' : 'Cancel'}
          </button>
        </div>

        <select
          value={form.roomId}
          aria-label="Room"
          onChange={(e) => set('roomId', e.target.value)}
        >
          <option value="">Not assigned</option>
          {rooms.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name}
            </option>
          ))}
        </select>

        {newRoom !== null && (
          <div className="newroom">
            <input
              type="text"
              value={newRoom}
              autoFocus
              placeholder="Nursery"
              aria-label="New room name"
              onChange={(e) => setNewRoom(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  void addRoom();
                }
                if (e.key === 'Escape') setNewRoom(null);
              }}
            />
            <button type="button" className="minibtn" disabled={!newRoom.trim()} onClick={addRoom}>
              Add
            </button>
          </div>
        )}
      </section>

      {/* ------------------------------------------- warranty information */}
      <CoverageField
        title="Warranty information"
        sectionRef={coverRef}
        purchaseDate={form.purchaseDate}
        coverages={form.coverages}
        onChange={(next) => set('coverages', next)}
      />

      {/* -------------------------------------------------------- documents */}
      <DocsField
        sectionRef={docsRef}
        itemId={item?.id}
        staged={staged}
        onStage={(d) => setStaged((list) => [...list, d])}
        onUnstage={(key) => setStaged((list) => list.filter((s) => s.key !== key))}
        onRetype={(key, kind) =>
          setStaged((list) => list.map((s) => (s.key === key ? { ...s, kind } : s)))
        }
      />

      <div className="savebar">
        {/* Says which one is missing rather than sitting there greyed out with
            no explanation — a disabled button with no reason is a dead end. */}
        {!canSave && (
          <p className="savewhy">
            {!form.name.trim() ? 'Give it a name to save.' : 'Add the purchase date to save.'}
          </p>
        )}
        <button
          type="button"
          className="btn wide"
          disabled={busy || !canSave}
          onClick={onSave}
        >
          {busy ? 'Saving…' : editing ? 'Save changes' : 'Save item'}
        </button>
      </div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="field">
      <span className="fieldlabel">{label}</span>
      {children}
    </label>
  );
}

function CameraGlyph() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M3 8.5A1.5 1.5 0 014.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0121 8.5v9A1.5 1.5 0 0119.5 19h-15A1.5 1.5 0 013 17.5z" />
      <circle cx="12" cy="13" r="3.4" />
    </svg>
  );
}

function GalleryGlyph() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <rect x="3" y="5.5" width="18" height="13" rx="2" />
      <circle cx="8.5" cy="10.5" r="1.6" />
      <path d="M4 16.5l4.5-4 3.5 3 3-2.5 4 3.5" />
    </svg>
  );
}
