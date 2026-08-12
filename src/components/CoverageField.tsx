import { useState } from 'react';
import type { CoverageUnit, WarrantyUnit } from '@/db/types';
import {
  blankCoverage,
  COVERAGE_LABELS,
  COVERS_PLACEHOLDER,
  UNIT_LABEL,
  WARRANTY_PRESETS,
  type CoverageDraft,
} from '@/lib/addItem';
import { formatPhoneInput } from '@/lib/format';
import { addDays, addMonths, parseDate, toISODate } from '@/lib/warranty';

/**
 * Every policy on the item, as a list you can add to.
 *
 * One warranty per product was always the simplification. A couch has a
 * lifetime frame, ten years on the cushions and one on the fabric; a heat gun
 * has three years limited cover, a year of free service and ninety days to
 * change your mind. Each of those is a different promise from a different
 * party with a different end date, and folding them into one number loses the
 * only one that matters — whichever runs out first.
 *
 * Two questions per policy, then: what it's for, and what it covers. The
 * second is the one nobody remembers three years later and the one a claim
 * turns on, so it's a field rather than something to bury in notes.
 *
 * The form opens as a single blank row, so an item with one plain warranty is
 * the same three taps it always was.
 */
export function CoverageField({
  purchaseDate,
  coverages,
  onChange,
}: {
  purchaseDate: string;
  coverages: CoverageDraft[];
  onChange: (next: CoverageDraft[]) => void;
}) {
  const patch = (key: string, changes: Partial<CoverageDraft>) =>
    onChange(coverages.map((c) => (c.key === key ? { ...c, ...changes } : c)));

  const real = coverages.filter((c) => c.unit === 'lifetime' || c.amount.trim());

  return (
    <section className="card">
      <div className="cardhead">
        <h3>Cover</h3>
        {real.length > 1 && <span className="countpill">{real.length}</span>}
      </div>

      {coverages.map((c, i) => (
        <CoverageRow
          key={c.key}
          draft={c}
          index={i}
          only={coverages.length === 1}
          purchaseDate={purchaseDate}
          onPatch={(changes) => patch(c.key, changes)}
          onRemove={() => onChange(coverages.filter((x) => x.key !== c.key))}
        />
      ))}

      <button
        type="button"
        className="linkish morelink"
        onClick={() => onChange([...coverages, blankCoverage()])}
      >
        + Add another policy
      </button>
    </section>
  );
}

function CoverageRow({
  draft,
  index,
  only,
  purchaseDate,
  onPatch,
  onRemove,
}: {
  draft: CoverageDraft;
  index: number;
  only: boolean;
  purchaseDate: string;
  onPatch: (changes: Partial<CoverageDraft>) => void;
  onRemove: () => void;
}) {
  const presets = draft.unit === 'lifetime' ? [] : WARRANTY_PRESETS[draft.unit];
  const amount = Number(draft.amount);
  const known = presets.includes(amount);
  const [custom, setCustom] = useState(!!draft.amount.trim() && !known);
  const [more, setMore] = useState(false);

  const ends = coverEnds(purchaseDate, draft.unit, draft.amount);

  return (
    <div className={`covrow${index > 0 ? ' extra' : ''}`}>
      {index > 0 && <div className="covrule" />}

      <div className="covhead">
        <input
          type="text"
          className="covname"
          value={draft.label}
          onChange={(e) => onPatch({ label: e.target.value })}
          placeholder={index === 0 ? 'Warranty' : 'What is this one for?'}
          aria-label="What this policy is for"
        />
        {!only && (
          <button
            type="button"
            className="iconbtn small"
            aria-label={`Remove ${draft.label.trim() || 'this policy'}`}
            onClick={onRemove}
          >
            <svg
              width="15"
              height="15"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
            >
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          </button>
        )}
      </div>

      {/* Only offered while the name is still empty. Once it says "Fabric"
          these are six ways to overwrite it by accident. */}
      {!draft.label.trim() && (
        <div className="chiprow">
          {COVERAGE_LABELS.map((name) => (
            <button
              key={name}
              type="button"
              className="pick"
              onClick={() => onPatch({ label: name })}
            >
              {name}
            </button>
          ))}
        </div>
      )}

      <input
        type="text"
        className="covcovers"
        value={draft.covers}
        onChange={(e) => onPatch({ covers: e.target.value })}
        placeholder={COVERS_PLACEHOLDER}
        aria-label="What this policy covers"
      />

      <div className="seg">
        {(Object.keys(UNIT_LABEL) as CoverageUnit[]).map((u) => (
          <button
            key={u}
            type="button"
            className={draft.unit === u ? 'on' : ''}
            onClick={() => {
              // A preset from the old unit means nothing in the new one — two
              // years and two days are not the same answer typed twice.
              const wasPreset =
                draft.unit !== 'lifetime' && WARRANTY_PRESETS[draft.unit].includes(amount);
              onPatch({ unit: u, amount: wasPreset ? '' : draft.amount });
              setCustom(false);
            }}
          >
            {UNIT_LABEL[u]}
          </button>
        ))}
      </div>

      {draft.unit === 'lifetime' ? (
        <p className="hint">Never counts down, and never warns you. Listed as a fact of the item.</p>
      ) : (
        <>
          <div className="chiprow">
            {presets.map((n) => (
              <button
                key={n}
                type="button"
                className={`pick${!custom && draft.amount === String(n) ? ' on' : ''}`}
                onClick={() => {
                  setCustom(false);
                  onPatch({ amount: draft.amount === String(n) ? '' : String(n) });
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
                if (next && presets.includes(amount)) onPatch({ amount: '' });
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
              value={draft.amount}
              onChange={(e) => onPatch({ amount: e.target.value })}
              placeholder={draft.unit === 'days' ? '90 days' : '18 months'}
              aria-label={`Number of ${draft.unit}`}
              autoFocus
            />
          )}

          {draft.amount.trim() && (
            <p className="hint">
              {ends
                ? `Ends ${ends}.`
                : 'Add a purchase date and Scout can track when this expires.'}
            </p>
          )}
        </>
      )}

      <button
        type="button"
        className="linkish morelink"
        aria-expanded={more}
        onClick={() => setMore((m) => !m)}
      >
        {more ? 'Hide who to call' : 'Who to call, policy number'}
      </button>

      {more && (
        <>
          <label className="field">
            <span className="fieldlabel">Provider</span>
            <input
              type="text"
              value={draft.provider}
              onChange={(e) => onPatch({ provider: e.target.value })}
              placeholder="Bosch Home"
            />
          </label>

          <div className="fieldpair">
            <label className="field">
              <span className="fieldlabel">Policy number</span>
              <input
                type="text"
                value={draft.policyNumber}
                onChange={(e) => onPatch({ policyNumber: e.target.value })}
              />
            </label>
            <label className="field">
              <span className="fieldlabel">Claims phone</span>
              <input
                type="tel"
                value={draft.phone}
                onChange={(e) => onPatch({ phone: formatPhoneInput(e.target.value) })}
                placeholder="(860) 555-1234"
              />
            </label>
          </div>

          <label className="field">
            <span className="fieldlabel">Policy page</span>
            <input
              type="url"
              value={draft.url}
              onChange={(e) => onPatch({ url: e.target.value })}
              placeholder="https://"
            />
          </label>
        </>
      )}
    </div>
  );
}

/** Live preview of the computed expiry, using the same maths as the list. */
function coverEnds(purchaseDate: string, unit: CoverageUnit, amount: string): string | null {
  if (unit === 'lifetime') return null;
  const n = Number(amount);
  if (!purchaseDate || !amount.trim() || !Number.isFinite(n) || n <= 0) return null;
  try {
    const from = parseDate(purchaseDate);
    const rounded = Math.round(n);
    const end =
      unit === 'days'
        ? addDays(from, rounded)
        : addMonths(from, (unit as WarrantyUnit) === 'years' ? rounded * 12 : rounded);
    return new Date(toISODate(end)).toLocaleDateString(undefined, {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
  } catch {
    return null;
  }
}
