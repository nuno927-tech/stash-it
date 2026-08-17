import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import type { CoverageUnit, WarrantyUnit } from '@/db/types';
import {
  blankCoverage,
  COVERAGE_LABELS,
  COVERS_PLACEHOLDER,
  UNIT_LABEL,
  WARRANTY_PRESETS,
  type CoverageDraft,
} from '@/lib/addItem';
import { pushBack } from '@/lib/backstack';
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
/** Policies with an answer in them, as opposed to blank rows waiting for one. */
export function countCoverages(drafts: CoverageDraft[]): number {
  return drafts.filter((c) => c.unit === 'lifetime' || c.amount.trim()).length;
}

export function CoverageField({
  purchaseDate,
  coverages,
  onChange,
  title = 'Coverage',
  sectionRef,
}: {
  purchaseDate: string;
  coverages: CoverageDraft[];
  onChange: (next: CoverageDraft[]) => void;
  /**
   * What the section is called. The item form says "Warranty information",
   * matching the other three section headings on that screen; the word
   * "Coverage" is the model's word and stays the default.
   */
  title?: string;
  /** So the form above can scroll this section into view. */
  sectionRef?: import('react').RefObject<HTMLElement | null>;
}) {
  const patch = (key: string, changes: Partial<CoverageDraft>) =>
    onChange(coverages.map((c) => (c.key === key ? { ...c, ...changes } : c)));

  const real = countCoverages(coverages);

  return (
    <section className="card formcard" ref={sectionRef}>
      <div className="cardhead">
        <h3>{title}</h3>
        {real > 1 && <span className="countpill">{real}</span>}
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
  const [naming, setNaming] = useState(false);

  // A name the user wrote, as opposed to one of the seven on offer.
  const customName = COVERAGE_LABELS.includes(draft.label) ? '' : draft.label.trim();

  const ends = coverEnds(purchaseDate, draft.unit, draft.amount);

  const hasDetails = [draft.covers, draft.provider, draft.policyNumber, draft.phone, draft.url].some(
    (v) => v.trim(),
  );

  return (
    <div className={`covrow${index > 0 ? ' extra' : ''}`}>
      {index > 0 && <div className="covrule" />}

      <div className="covhead">
        {/*
          The name is chosen, not typed. Every policy on a receipt is one of a
          handful of things, and a free-text box asked the user to invent the
          vocabulary — which produced "warranty", "Warranty" and "3yr warr" for
          the same idea. The seven buttons are the vocabulary; Custom is the
          way out, and it asks properly rather than leaving an empty field
          sitting there for everyone who didn't need it.
        */}
        <span className={`covwhat${draft.label.trim() ? '' : ' unset'}`}>
          {draft.label.trim() || 'What is this one for?'}
        </span>
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

      <div className="seg names">
        {COVERAGE_LABELS.slice(0, 3).map((name) => (
          <button
            key={name}
            type="button"
            className={draft.label === name ? 'on' : ''}
            onClick={() => onPatch({ label: name })}
          >
            {name}
          </button>
        ))}
      </div>

      <div className="seg names">
        {COVERAGE_LABELS.slice(3).map((name) => (
          <button
            key={name}
            type="button"
            className={draft.label === name ? 'on' : ''}
            onClick={() => onPatch({ label: name })}
          >
            {name}
          </button>
        ))}
        {/* Shows the custom name once there is one, so the row still says
            what it is without a separate field repeating it back. */}
        <button
          type="button"
          className={customName ? 'on' : ''}
          onClick={() => setNaming(true)}
        >
          {customName || 'Custom'}
        </button>
      </div>

      {naming && (
        <NameDialog
          initial={customName}
          onSave={(name) => {
            onPatch({ label: name });
            setNaming(false);
          }}
          onCancel={() => setNaming(false)}
        />
      )}

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
        {more ? 'Fewer details' : 'Additional details'}
        {/* Collapsed, there is nothing to say whether anything is in there.
            A dot is enough: it means "you filled something in here", which is
            the only question a closed section raises. */}
        {!more && hasDetails && <i className="filleddot" aria-label="has details" />}
      </button>

      {more && (
        <>
          {/*
            What the policy actually pays for, and the first thing behind the
            toggle because it's the one a claim turns on. It used to sit out on
            the row, which put a wide free-text box between the policy's name
            and its term on every single coverage — including the four out of
            five where nobody fills it in.
          */}
          <label className="field">
            <span className="fieldlabel">What it covers</span>
            <textarea
              rows={2}
              value={draft.covers}
              onChange={(e) => onPatch({ covers: e.target.value })}
              placeholder={COVERS_PLACEHOLDER}
            />
          </label>

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

/**
 * Typing a name the buttons don't offer.
 *
 * A dialog rather than a field that's always there: on the overwhelming
 * majority of policies one of the seven names is right, and an empty text box
 * under them would be a question asked of everybody to serve the few. Asking
 * only when Custom is pressed also means the answer arrives complete, instead
 * of being read out of a half-typed field on save.
 */
function NameDialog({
  initial,
  onSave,
  onCancel,
}: {
  initial: string;
  onSave: (name: string) => void;
  onCancel: () => void;
}) {
  const [name, setName] = useState(initial);
  useEffect(() => pushBack(onCancel), [onCancel]);

  const save = () => {
    const clean = name.trim();
    if (clean) onSave(clean);
    else onCancel();
  };

  return createPortal(
    <div className="sheetscrim" role="dialog" aria-modal="true" aria-label="Name this policy">
      <div className="sheetcard" onClick={(e) => e.stopPropagation()}>
        <h4>What is this policy for?</h4>
        <label className="field">
          <span className="fieldlabel">Name</span>
          <input
            type="text"
            value={name}
            autoFocus
            enterKeyHint="done"
            maxLength={40}
            placeholder="Fabric, springs, screen…"
            onChange={(e) => setName(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && save()}
          />
        </label>
        <p className="hint">Whatever the paperwork calls it. It shows on the item as the name of this policy.</p>
        <button type="button" className="btn wide" onClick={save}>
          Use this name
        </button>
        <button type="button" className="btn ghost" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </div>,
    document.body,
  );
}
