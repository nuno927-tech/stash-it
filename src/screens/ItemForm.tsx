import { useEffect, useRef, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { activeRooms } from '@/db/repo';
import type { Item, WarrantyUnit } from '@/db/types';
import {
  emptyForm,
  formFromItem,
  ItemLimitError,
  saveEditedItem,
  saveNewItem,
  ValidationError,
  UNIT_LABEL,
  WARRANTY_PRESETS,
  type AddItemForm,
  type PhotoEdit,
} from '@/lib/addItem';
import { attachStaged, type StagedDoc } from '@/lib/docs';
import { feedback } from '@/lib/feedback';
import { PhotoError, storePhoto } from '@/lib/photo';
import { addDays, addMonths, parseDate, toISODate } from '@/lib/warranty';
import { DocsField } from '@/components/DocsField';
import { ItemIcon } from '@/components/ItemIcon';

/**
 * One form, two modes. Passing an `item` switches it to editing that record;
 * without one it creates. Keeping them together means the field list, the
 * validation and the expiry preview can never drift apart.
 */
export function ItemForm({
  propertyId,
  currency,
  item,
  onSaved,
  onCancel,
}: {
  propertyId: string;
  currency: string;
  item?: Item;
  onSaved: (id: string) => void;
  onCancel: () => void;
}) {
  const editing = !!item;
  const rooms = useLiveQuery(() => activeRooms(propertyId), [propertyId]) ?? [];

  const [form, setForm] = useState<AddItemForm>(() =>
    item ? formFromItem(item, currency) : emptyForm(currency),
  );
  // undefined = untouched, PhotoRefs = replaced, null = removed.
  const [photo, setPhoto] = useState<PhotoEdit>(undefined);
  const [preview, setPreview] = useState<string>();
  const [removed, setRemoved] = useState(false);
  const [custom, setCustom] = useState(false);
  const [staged, setStaged] = useState<StagedDoc[]>([]);
  const [more, setMore] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const cameraInput = useRef<HTMLInputElement>(null);
  const libraryInput = useRef<HTMLInputElement>(null);

  // Show the photo an edited item already has, until a new one replaces it.
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

  const onPhoto = async (file: File | undefined) => {
    if (!file) return;
    setBusy(true);
    setError(undefined);
    try {
      const refs = await storePhoto(file);
      feedback('attach');
      setPhoto(refs);
      setPreview((old) => {
        if (old) URL.revokeObjectURL(old);
        return URL.createObjectURL(file);
      });
    } catch (e) {
      setError(e instanceof PhotoError ? e.message : `Could not read that photo.`);
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

      // Staged files are written only once the item exists, so a save that
      // fails validation leaves no half-attached paperwork behind.
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

  const termSummary = !hasTerm
    ? null
    : endsOn
      ? `${amount} ${amount === 1 ? form.warrantyUnit.replace(/s$/, '') : form.warrantyUnit} of cover, ending ${endsOn}.`
      : 'Add a purchase date and Nutsy can track when this expires.';

  return (
    <>
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
        <button type="button" className="minibtn" disabled={busy} onClick={onSave}>
          Save
        </button>
      </header>

      {error && <div className="notice bad">{error}</div>}

      <div className="photodrop">
        {preview ? (
          <img src={preview} alt="" />
        ) : (
          <span className="photohint">
            <ItemIcon item={{ name: form.name, brand: form.brand }} size={30} />
            {form.name.trim()
              ? 'No photo yet — this icon stands in'
              : 'No photo yet'}
          </span>
        )}
      </div>

      {/*
        Two inputs, not one. `capture` sends you straight to the camera with no
        way back to the library, so a single button can only ever offer one of
        the two. Splitting them is the only way to give both.
      */}
      <div className="photoactions">
        <button
          type="button"
          className="minibtn"
          onClick={() => cameraInput.current?.click()}
          disabled={busy}
        >
          Take photo
        </button>
        <button
          type="button"
          className="minibtn ghost"
          onClick={() => libraryInput.current?.click()}
          disabled={busy}
        >
          Choose photo
        </button>
        {preview && (
          <button
            type="button"
            className="minibtn ghost"
            disabled={busy}
            onClick={() => {
              URL.revokeObjectURL(preview);
              setPreview(undefined);
              setPhoto(null);
              setRemoved(true);
            }}
          >
            Remove
          </button>
        )}
      </div>

      <input
        ref={cameraInput}
        type="file"
        accept="image/*"
        capture="environment"
        hidden
        onChange={(e) => {
          void onPhoto(e.target.files?.[0]);
          e.target.value = '';
        }}
      />
      <input
        ref={libraryInput}
        type="file"
        accept="image/*"
        hidden
        onChange={(e) => {
          void onPhoto(e.target.files?.[0]);
          e.target.value = '';
        }}
      />

      <Field label="Name">
        <input
          type="text"
          value={form.name}
          onChange={(e) => set('name', e.target.value)}
          placeholder="Bosch dishwasher"
          autoFocus
        />
      </Field>

      <Field label="Room">
        <select value={form.roomId} onChange={(e) => set('roomId', e.target.value)}>
          <option value="">Not assigned</option>
          {rooms.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name}
            </option>
          ))}
        </select>
      </Field>

      <div className="fieldpair">
        <Field label="Purchase date">
          <input
            type="date"
            value={form.purchaseDate}
            onChange={(e) => set('purchaseDate', e.target.value)}
          />
        </Field>
        <Field label={`Price (${form.currency})`}>
          <input
            type="text"
            inputMode="decimal"
            value={form.price}
            onChange={(e) => set('price', e.target.value)}
            placeholder="849.00"
          />
        </Field>
      </div>

      <div className="fieldlabel">Warranty length</div>

      <div className="seg">
        {(Object.keys(UNIT_LABEL) as WarrantyUnit[]).map((u) => (
          <button
            key={u}
            type="button"
            className={form.warrantyUnit === u ? 'on' : ''}
            onClick={() => {
              // Switching units keeps any custom number the user typed — 90
              // days becoming 90 months is nonsense, but so is silently
              // wiping what they entered, so only presets are cleared.
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
            if (next && WARRANTY_PRESETS[form.warrantyUnit].includes(Number(form.warrantyAmount))) {
              set('warrantyAmount', '');
            }
          }}
        >
          Custom
        </button>
        <button
          type="button"
          className={`pick${form.warrantyAmount === '' && !custom ? ' on' : ''}`}
          onClick={() => {
            setCustom(false);
            set('warrantyAmount', '');
          }}
        >
          None
        </button>
      </div>

      {custom && (
        <Field label={`Number of ${form.warrantyUnit}`}>
          <input
            type="number"
            inputMode="numeric"
            min="1"
            value={form.warrantyAmount}
            onChange={(e) => set('warrantyAmount', e.target.value)}
            placeholder={form.warrantyUnit === 'days' ? '90' : '18'}
            autoFocus
          />
        </Field>
      )}

      {termSummary && <p className="hint">{termSummary}</p>}

      <DocsField
        itemId={item?.id}
        staged={staged}
        onStage={(d) => setStaged((list) => [...list, d])}
        onUnstage={(key) => setStaged((list) => list.filter((s) => s.key !== key))}
        onRetype={(key, kind) =>
          setStaged((list) => list.map((s) => (s.key === key ? { ...s, kind } : s)))
        }
      />

      <button type="button" className="expander" onClick={() => setMore((m) => !m)}>
        {more ? 'Fewer details' : 'More details'}
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
          style={{ transform: more ? 'rotate(180deg)' : undefined }}
        >
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>

      {more && (
        <>
          <div className="fieldpair">
            <Field label="Brand">
              <input
                type="text"
                value={form.brand}
                onChange={(e) => set('brand', e.target.value)}
              />
            </Field>
            <Field label="Model">
              <input
                type="text"
                value={form.model}
                onChange={(e) => set('model', e.target.value)}
              />
            </Field>
          </div>

          <div className="fieldpair">
            <Field label="Serial number">
              <input
                type="text"
                value={form.serial}
                onChange={(e) => set('serial', e.target.value)}
              />
            </Field>
            <Field label="Retailer">
              <input
                type="text"
                value={form.retailer}
                onChange={(e) => set('retailer', e.target.value)}
              />
            </Field>
          </div>

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
                onChange={(e) => set('warrantyPhone', e.target.value)}
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
        </>
      )}

      <button type="button" className="btn wide" disabled={busy} onClick={onSave}>
        {busy ? 'Saving…' : editing ? 'Save changes' : 'Save item'}
      </button>
    </>
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
