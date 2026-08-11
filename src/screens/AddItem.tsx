import { useRef, useState, type ReactNode } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { activeRooms } from '@/db/repo';
import { ITEM_CATEGORIES, type ItemCategory } from '@/db/types';
import {
  emptyForm,
  ItemLimitError,
  saveNewItem,
  ValidationError,
  WARRANTY_PRESETS,
  type AddItemForm,
  type PhotoRefs,
} from '@/lib/addItem';
import { PhotoError, storePhoto } from '@/lib/photo';
import { addMonths, parseDate, toISODate } from '@/lib/warranty';
import { CategoryIcon } from '@/components/CategoryIcon';

const CATEGORY_LABEL: Record<ItemCategory, string> = {
  appliance: 'Appliance',
  electronics: 'Electronics',
  tools: 'Tools',
  furniture: 'Furniture',
  hvac: 'Heating & air',
  outdoor: 'Outdoor',
  vehicle: 'Vehicle',
  other: 'Other',
};

export function AddItem({
  propertyId,
  currency,
  onSaved,
  onCancel,
}: {
  propertyId: string;
  currency: string;
  onSaved: (id: string) => void;
  onCancel: () => void;
}) {
  const rooms = useLiveQuery(() => activeRooms(propertyId), [propertyId]) ?? [];

  const [form, setForm] = useState<AddItemForm>(() => emptyForm(currency));
  const [photo, setPhoto] = useState<PhotoRefs | null>(null);
  const [preview, setPreview] = useState<string>();
  const [more, setMore] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const fileInput = useRef<HTMLInputElement>(null);

  const set = <K extends keyof AddItemForm>(key: K, value: AddItemForm[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const onPhoto = async (file: File | undefined) => {
    if (!file) return;
    setBusy(true);
    setError(undefined);
    try {
      const refs = await storePhoto(file);
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
      const id = await saveNewItem(form, propertyId, photo ?? undefined);
      if (preview) URL.revokeObjectURL(preview);
      onSaved(id);
    } catch (e) {
      if (e instanceof ValidationError || e instanceof ItemLimitError) setError(e.message);
      else setError(`Could not save: ${(e as Error).message}`);
      setBusy(false);
    }
  };

  const endsOn = coverEnds(form.purchaseDate, form.warrantyMonths);

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
          New item
        </div>
        <button type="button" className="minibtn" disabled={busy} onClick={onSave}>
          Save
        </button>
      </header>

      {error && <div className="notice bad">{error}</div>}

      <button
        type="button"
        className="photodrop"
        onClick={() => fileInput.current?.click()}
        disabled={busy}
      >
        {preview ? (
          <img src={preview} alt="" />
        ) : (
          <span>
            <svg
              width="26"
              height="26"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.7"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M3 8.5A1.5 1.5 0 014.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0121 8.5v9A1.5 1.5 0 0119.5 19h-15A1.5 1.5 0 013 17.5z" />
              <circle cx="12" cy="13" r="3.6" />
            </svg>
            Add a photo
          </span>
        )}
      </button>
      <input
        ref={fileInput}
        type="file"
        accept="image/*"
        capture="environment"
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

      <div className="fieldlabel">Category</div>
      <div className="chiprow">
        {ITEM_CATEGORIES.map((c) => (
          <button
            key={c}
            type="button"
            className={`pick${form.category === c ? ' on' : ''}`}
            onClick={() => set('category', form.category === c ? '' : c)}
          >
            <CategoryIcon category={c} size={16} />
            {CATEGORY_LABEL[c]}
          </button>
        ))}
      </div>

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

      <div className="fieldlabel">Warranty</div>
      <div className="chiprow">
        {WARRANTY_PRESETS.map((p) => (
          <button
            key={p.months}
            type="button"
            className={`pick${form.warrantyMonths === String(p.months) ? ' on' : ''}`}
            onClick={() =>
              set('warrantyMonths', form.warrantyMonths === String(p.months) ? '' : String(p.months))
            }
          >
            {p.label}
          </button>
        ))}
        <input
          type="number"
          className="months"
          min="0"
          value={form.warrantyMonths}
          onChange={(e) => set('warrantyMonths', e.target.value)}
          placeholder="months"
          aria-label="Warranty length in months"
        />
      </div>

      {endsOn && <p className="hint">Cover ends {endsOn}.</p>}
      {form.warrantyMonths && !form.purchaseDate && (
        <p className="hint">Add a purchase date and Nutsy can track when this expires.</p>
      )}

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
        {busy ? 'Saving…' : 'Save item'}
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
function coverEnds(purchaseDate: string, months: string): string | null {
  const n = Number(months);
  if (!purchaseDate || !months.trim() || !Number.isFinite(n) || n <= 0) return null;
  try {
    const end = addMonths(parseDate(purchaseDate), Math.round(n));
    return new Date(toISODate(end)).toLocaleDateString(undefined, {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  } catch {
    return null;
  }
}
