import { useRef, useState, type ReactNode } from 'react';
import { createPaper, deletePaper, updatePaper } from '@/db/repo';
import type { Paper, PaperKind } from '@/db/types';
import { feedback } from '@/lib/feedback';
import {
  DEFAULT_LEAD_DAYS,
  KIND_LABEL,
  KINDS,
  LEAD_REASON,
  REMIND_CHOICES,
  expiryOf,
  leadDaysFor,
  renewBy,
} from '@/lib/papers';
import { ConfirmDelete } from '@/components/ConfirmDelete';
import { PaperIcon } from '@/components/PaperIcon';
import { useAutoAdvance } from '@/components/useAutoAdvance';

/**
 * Adding or editing a document that expires.
 *
 * Three questions are required — what kind, what it's called, when it runs out
 * — and everything else is optional. The fourth card is the one that matters
 * and the one nobody would think to ask for: how much warning this particular
 * document needs.
 *
 * THE LEAD TIME IS SHOWN AS A CONSEQUENCE, not as a number. Nobody has an
 * opinion about "240 days"; everybody has an opinion about "start in October
 * 2026". So the card sets the number and then says the date it produces, live,
 * and the reason that default exists sits underneath it.
 */
export function PaperForm({
  propertyId,
  existing,
  onSaved,
  onCancel,
}: {
  propertyId: string;
  existing?: Paper;
  onSaved: () => void;
  onCancel: () => void;
}) {
  const editing = !!existing;

  const [kind, setKind] = useState<PaperKind>(existing?.kind ?? 'passport');
  const [label, setLabel] = useState(existing?.label ?? '');
  const [holder, setHolder] = useState(existing?.holder ?? '');
  const [expires, setExpires] = useState(existing?.expiresOn ?? '');
  const [issued, setIssued] = useState(existing?.issuedOn ?? '');
  const [lead, setLead] = useState<number | undefined>(existing?.leadDays);
  const [authority, setAuthority] = useState(existing?.authority ?? '');
  const [storedAt, setStoredAt] = useState(existing?.storedAt ?? '');
  const [remind, setRemind] = useState(existing?.remindDays ?? 0);
  const [notes, setNotes] = useState(existing?.notes ?? '');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const [confirming, setConfirming] = useState(false);

  const end = expiryOf({ expiresOn: expires });
  const canSave = !!label.trim() && !!end;

  const datesRef = useRef<HTMLElement>(null);
  const leadRef = useRef<HTMLElement>(null);
  useAutoAdvance(!!label.trim(), datesRef);
  useAutoAdvance(!!end, leadRef);

  const effectiveLead = leadDaysFor({ kind, leadDays: lead });
  const start = end ? renewBy({ kind, leadDays: lead, expiresOn: expires }) : null;

  const pick = (k: PaperKind) => {
    setKind(k);
    feedback('tap');
    // A lead time the user hasn't touched should follow the kind they pick.
    // One they *have* touched is an opinion, and picking a different kind
    // afterwards shouldn't quietly overwrite it.
    if (lead !== undefined && lead === DEFAULT_LEAD_DAYS[kind]) setLead(undefined);
  };

  const save = async () => {
    setBusy(true);
    setError(undefined);
    try {
      const patch = {
        propertyId,
        kind,
        label: label.trim(),
        holder: holder.trim() || undefined,
        expiresOn: expires,
        issuedOn: issued || undefined,
        // Only stored when it differs from the default, so changing the
        // default later moves everyone who never had an opinion.
        leadDays: lead === undefined || lead === DEFAULT_LEAD_DAYS[kind] ? undefined : lead,
        authority: authority.trim() || undefined,
        storedAt: storedAt.trim() || undefined,
        remindDays: remind || undefined,
        notes: notes.trim() || undefined,
      };
      if (existing) await updatePaper(existing.id, patch);
      else await createPaper(patch);
      feedback('save');
      onSaved();
    } catch (e) {
      feedback('error');
      setError((e as Error).message);
      setBusy(false);
    }
  };

  return (
    <div className="formwrap">
      <header className="apphead">
        <button type="button" className="iconbtn" onClick={onCancel} aria-label="Cancel">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
        <div className="apptitle" style={{ fontSize: 19 }}>
          {editing ? 'Edit document' : 'New document'}
        </div>
        <span style={{ width: 34 }} />
      </header>

      {error && <div className="notice bad">{error}</div>}

      {/* ------------------------------------------------------- what it is */}
      <section className="card formcard">
        <div className="cardhead">
          <h3>What is it</h3>
          <PaperIcon kind={kind} state="valid" size={30} />
        </div>

        <div className="kindgrid">
          {KINDS.map((k) => (
            <button
              key={k}
              type="button"
              className={`servicetile${kind === k ? ' on' : ''}`}
              onClick={() => pick(k)}
            >
              <PaperIcon kind={k} state="valid" size={30} />
              <small>{KIND_LABEL[k]}</small>
            </button>
          ))}
        </div>

        <div className="fieldpair">
          <Field label="Call it">
            <input
              type="text"
              value={label}
              placeholder={`${KIND_LABEL[kind]}`}
              onChange={(e) => setLabel(e.target.value)}
            />
          </Field>
          <Field label="Whose">
            <input
              type="text"
              value={holder}
              placeholder="Optional"
              onChange={(e) => setHolder(e.target.value)}
            />
          </Field>
        </div>

        {/*
          Said once, here, where somebody is about to look for the field that
          isn't there. An app that silently lacks a feature reads as unfinished;
          one that says why reads as deliberate.
        */}
        <p className="hint">
          No scans and no document numbers, on purpose — backups aren't encrypted yet, so Scout
          keeps the dates and leaves the document where it is.
        </p>
      </section>

      {/* ---------------------------------------------------------- the dates */}
      <section className="card formcard" ref={datesRef}>
        <div className="cardhead">
          <h3>Dates</h3>
        </div>

        <div className="fieldpair">
          <Field label="Expires">
            <input type="date" lang="en-US" value={expires} onChange={(e) => setExpires(e.target.value)} />
          </Field>
          <Field label="Issued">
            <input type="date" lang="en-US" value={issued} onChange={(e) => setIssued(e.target.value)} />
          </Field>
        </div>

        <div className="fieldpair">
          <Field label="Issued by">
            <input
              type="text"
              value={authority}
              placeholder="Optional"
              onChange={(e) => setAuthority(e.target.value)}
            />
          </Field>
          <Field label="Kept where">
            <input
              type="text"
              value={storedAt}
              placeholder="Fireproof box…"
              onChange={(e) => setStoredAt(e.target.value)}
            />
          </Field>
        </div>
      </section>

      {/* ------------------------------------------------------- the runway */}
      <section className="card formcard" ref={leadRef}>
        <div className="cardhead">
          <h3>How much warning</h3>
        </div>

        <div className="seg">
          {LEAD_CHOICES.map((c) => (
            <button
              key={c.days}
              type="button"
              className={effectiveLead === c.days ? 'on' : ''}
              onClick={() => setLead(c.days)}
            >
              {c.label}
            </button>
          ))}
        </div>

        {/*
          The number turned into the thing it means. "240 days" is not
          something anyone has a view on; "start in October 2026" is.
        */}
        <p className="leadsays">
          {start ? (
            <>
              Scout will start asking in{' '}
              <b>{start.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}</b>
              {end && (
                <>
                  , {effectiveLead === 0 ? 'the day' : `${Math.round(effectiveLead / 30)} months before`} it
                  runs out
                </>
              )}
              .
            </>
          ) : (
            'Add an expiry date and Scout will work out when to start asking.'
          )}
        </p>

        <p className="hint">{LEAD_REASON[kind]}</p>
      </section>

      {/* -------------------------------------------------------- reminders */}
      <section className="card formcard">
        <div className="cardhead">
          <h3>Reminder</h3>
        </div>

        <div className="seg">
          {REMIND_CHOICES.map((d) => (
            <button key={d} type="button" className={remind === d ? 'on' : ''} onClick={() => setRemind(d)}>
              {d === 0 ? 'None' : `${d} day${d === 1 ? '' : 's'}`}
            </button>
          ))}
        </div>

        <p className="hint">
          {remind === 0
            ? "No reminder. It'll still appear on the home screen once it needs starting."
            : `A card appears on the home screen ${remind} day${remind === 1 ? '' : 's'} before it needs starting — the next time you open Stash it. Nothing reaches your phone while the app is closed; that needs a server, and there isn't one yet.`}
        </p>

        <Field label="Notes">
          <textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Optional" />
        </Field>
      </section>

      {editing && (
        <>
          <button type="button" className="btn ghost wide" aria-haspopup="dialog" onClick={() => setConfirming(true)}>
            Delete document
          </button>
          {confirming && (
            <ConfirmDelete
              name={existing.label}
              permanent
              onConfirm={() => {
                void deletePaper(existing.id).then(() => {
                  feedback('delete');
                  onSaved();
                });
              }}
              onCancel={() => setConfirming(false)}
            />
          )}
        </>
      )}

      <div className="savebar">
        {!canSave && (
          <p className="savewhy">
            {!label.trim() ? 'Give it a name.' : 'Add the date it expires.'}
          </p>
        )}
        <button type="button" className="btn wide" disabled={busy || !canSave} onClick={() => void save()}>
          {busy ? 'Saving…' : editing ? 'Save changes' : 'Save document'}
        </button>
      </div>
    </div>
  );
}

/**
 * Offered as spans of time rather than as a slider of days.
 *
 * Nobody wants to dial in 197. The five that matter are "on the day", "a
 * month", "three months", "six months" and "eight months", and the last is
 * there because a passport genuinely needs it.
 */
const LEAD_CHOICES: { days: number; label: string }[] = [
  { days: 0, label: 'On the day' },
  { days: 30, label: '1 mth' },
  { days: 90, label: '3 mths' },
  { days: 180, label: '6 mths' },
  { days: 240, label: '8 mths' },
];

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="field">
      <span className="fieldlabel">{label}</span>
      {children}
    </label>
  );
}
