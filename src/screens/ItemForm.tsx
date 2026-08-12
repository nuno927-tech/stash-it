import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeRooms, createRoom, RoomNameTakenError } from '@/db/repo';
import type { Item, WarrantyUnit } from '@/db/types';
import {
  emptyForm,
  formFromItem,
  ItemLimitError,
  saveEditedItem,
  saveNewItem,
  UNIT_LABEL,
  ValidationError,
  WARRANTY_PRESETS,
  type AddItemForm,
  type PhotoEdit,
} from '@/lib/addItem';
import { attachStaged, stageDocs, type StagedDoc } from '@/lib/docs';
import { feedback } from '@/lib/feedback';
import {
  completeMoneyInput,
  currencySymbol,
  formatMoneyInput,
  formatPhoneInput,
} from '@/lib/format';
import { PhotoError, storePhoto } from '@/lib/photo';
import { addDays, addMonths, parseDate, toISODate } from '@/lib/warranty';
import { ChoiceSheet } from '@/components/ChoiceSheet';
import { DocsField } from '@/components/DocsField';

/**
 * One form, two modes: pass an `item` to edit it, omit one to create.
 *
 * Organised as cards in the order someone actually knows the answers — what it
 * is, where it lives, what it cost, how long it's covered, then the paperwork.
 * The previous single column of fields asked for all of it at one visual
 * weight, which is what made it feel like a form rather than a few questions.
 *
 * Save is a sticky bar rather than a button at each end. On a screen this long
 * a top-right Save is out of thumb reach, and two of them is one too many.
 */
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
  const [custom, setCustom] = useState(false);
  const [staged, setStaged] = useState<StagedDoc[]>(() => prestaged ?? []);
  const [newRoom, setNewRoom] = useState<string | null>(null);
  const [more, setMore] = useState(false);
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

  const endsOn = coverEnds(form.purchaseDate, form.warrantyUnit, form.warrantyAmount);
  const amount = Number(form.warrantyAmount);
  const hasTerm = form.warrantyAmount.trim() !== '' && Number.isFinite(amount) && amount > 0;
  const unitWord = amount === 1 ? form.warrantyUnit.replace(/s$/, '') : form.warrantyUnit;

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

      {/* What it is. The photo sits beside the name rather than above it: a
          full-width dropzone pushed the first real question below the fold. */}
      <section className="card">
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

          <div className="identity-fields">
            <input
              type="text"
              className="bigname"
              value={form.name}
              onChange={(e) => set('name', e.target.value)}
              placeholder="What is it?"
              aria-label="Name"
              autoFocus={!editing}
            />
            <input
              type="text"
              value={form.brand}
              onChange={(e) => set('brand', e.target.value)}
              placeholder="Brand (optional)"
              aria-label="Brand"
            />
          </div>
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
      </section>

      {/* Where it lives. */}
      <section className="card">
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

      {/* What it cost. */}
      <section className="card">
        <div className="cardhead">
          <h3>Purchase</h3>
        </div>
        <div className="fieldpair">
          <label className="field">
            <span className="fieldlabel">Date</span>
            <input
              type="date"
              value={form.purchaseDate}
              onChange={(e) => set('purchaseDate', e.target.value)}
            />
          </label>
          <label className="field">
            <span className="fieldlabel">Price</span>
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
          </label>
        </div>
      </section>

      {/* How long it's covered. */}
      <section className="card">
        <div className="cardhead">
          <h3>Warranty</h3>
          {hasTerm && (
            <button
              type="button"
              className="linkish"
              onClick={() => {
                setCustom(false);
                set('warrantyAmount', '');
              }}
            >
              Clear
            </button>
          )}
        </div>

        <div className="seg">
          {(Object.keys(UNIT_LABEL) as WarrantyUnit[]).map((u) => (
            <button
              key={u}
              type="button"
              className={form.warrantyUnit === u ? 'on' : ''}
              onClick={() => {
                const wasPreset = WARRANTY_PRESETS[form.warrantyUnit].includes(
                  Number(form.warrantyAmount),
                );
                setForm((f) => ({
                  ...f,
                  warrantyUnit: u,
                  warrantyAmount: wasPreset ? '' : f.warrantyAmount,
                }));
                setCustom(false);
              }}
            >
              {UNIT_LABEL[u]}
            </button>
          ))}
        </div>

        <div className="chiprow">
          {WARRANTY_PRESETS[form.warrantyUnit].map((n) => (
            <button
              key={n}
              type="button"
              className={`pick${!custom && form.warrantyAmount === String(n) ? ' on' : ''}`}
              onClick={() => {
                setCustom(false);
                set('warrantyAmount', form.warrantyAmount === String(n) ? '' : String(n));
              }}
            >
              {n}
            </button>
          ))}
          <button
            type="button"
            className={`pick${custom ? ' on' : ''}`}
            onClick={() => {
              const next = !custom;
              setCustom(next);
              if (next && WARRANTY_PRESETS[form.warrantyUnit].includes(Number(form.warrantyAmount)))
                set('warrantyAmount', '');
            }}
          >
            Custom
          </button>
        </div>

        {custom && (
          <input
            type="number"
            inputMode="numeric"
            min="1"
            value={form.warrantyAmount}
            onChange={(e) => set('warrantyAmount', e.target.value)}
            placeholder={form.warrantyUnit === 'days' ? '90 days' : '18 months'}
            aria-label={`Number of ${form.warrantyUnit}`}
            autoFocus
          />
        )}

        {hasTerm && (
          <p className="hint">
            {endsOn
              ? `${amount} ${unitWord} of cover, ending ${endsOn}.`
              : 'Add a purchase date and Scout can track when this expires.'}
          </p>
        )}
      </section>

      <DocsField
        itemId={item?.id}
        staged={staged}
        onStage={(d) => setStaged((list) => [...list, d])}
        onUnstage={(key) => setStaged((list) => list.filter((s) => s.key !== key))}
        onRetype={(key, kind) =>
          setStaged((list) => list.map((s) => (s.key === key ? { ...s, kind } : s)))
        }
      />

      <button
        type="button"
        className="expander"
        aria-expanded={more}
        onClick={() => setMore((m) => !m)}
      >
        {more ? 'Fewer details' : 'More details'}
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
          style={more ? { transform: 'rotate(180deg)' } : undefined}
        >
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>

      {more && (
        <section className="card">
          <div className="fieldpair">
            <Field label="Model">
              <input type="text" value={form.model} onChange={(e) => set('model', e.target.value)} />
            </Field>
            <Field label="Serial number">
              <input
                type="text"
                value={form.serial}
                onChange={(e) => set('serial', e.target.value)}
              />
            </Field>
          </div>

          <Field label="Retailer">
            <input
              type="text"
              value={form.retailer}
              onChange={(e) => set('retailer', e.target.value)}
            />
          </Field>

          <Field label="Warranty provider">
            <input
              type="text"
              value={form.warrantyProvider}
              onChange={(e) => set('warrantyProvider', e.target.value)}
              placeholder="Bosch Home"
            />
          </Field>

          <div className="fieldpair">
            <Field label="Policy number">
              <input
                type="text"
                value={form.policyNumber}
                onChange={(e) => set('policyNumber', e.target.value)}
              />
            </Field>
            <Field label="Claims phone">
              <input
                type="tel"
                value={form.warrantyPhone}
                onChange={(e) => set('warrantyPhone', formatPhoneInput(e.target.value))}
                placeholder="(860) 555-1234"
              />
            </Field>
          </div>

          <Field label="Warranty page">
            <input
              type="url"
              value={form.warrantyUrl}
              onChange={(e) => set('warrantyUrl', e.target.value)}
              placeholder="https://"
            />
          </Field>

          <Field label="Notes">
            <textarea
              rows={3}
              value={form.notes}
              onChange={(e) => set('notes', e.target.value)}
              placeholder="Installed by Kelly Plumbing, filter behind the kickplate"
            />
          </Field>
        </section>
      )}

      <div className="savebar">
        <button type="button" className="btn wide" disabled={busy} onClick={onSave}>
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

/** Live preview of the computed expiry, using the same maths as the list. */
function coverEnds(purchaseDate: string, unit: WarrantyUnit, amount: string): string | null {
  const n = Number(amount);
  if (!purchaseDate || !amount.trim() || !Number.isFinite(n) || n <= 0) return null;
  try {
    const from = parseDate(purchaseDate);
    const end =
      unit === 'days'
        ? addDays(from, Math.round(n))
        : addMonths(from, unit === 'years' ? Math.round(n) * 12 : Math.round(n));
    return new Date(toISODate(end)).toLocaleDateString(undefined, {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  } catch {
    return null;
  }
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
