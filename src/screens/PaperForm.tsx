import { useRef, useState, type ReactNode } from 'react';
import { createPaper, deletePaper, updatePaper } from '@/db/repo';
import type { Paper, PaperKind } from '@/db/types';
import { feedback } from '@/lib/feedback';
import { armNotifyOffer, datedSave } from '@/lib/notifyOffer';
import {
  DEFAULT_LEAD_DAYS,
  KIND_LABEL,
  KINDS,
  expiryOf,
  leadDaysFor,
  renameForKind,
  renewBy,
} from '@/lib/papers';
import { ConfirmDelete } from '@/components/ConfirmDelete';
import { PaperIcon } from '@/components/PaperIcon';
import { cardFilled, useAutoAdvance } from '@/components/useAutoAdvance';

/**
 * Adding or editing a document that expires.
 *
 * Three questions are required — what kind, what it's called, when it runs out
 * — and everything else is optional. The third card is the one that matters and
 * the one nobody would think to ask for: how much warning this particular
 * document needs.
 *
 * THE LEAD TIME IS SHOWN AS A CONSEQUENCE, not as a number. Nobody has an
 * opinion about "240 days"; everybody has one about "October 2026". So the
 * sentence sits directly under the heading, above the control, and each tap
 * rewrites the line you are already reading.
 *
 * THERE IS NO SEPARATE REMINDER. It was there, copied from the subscription
 * form, and it was the same control twice — see the note on the Paper type.
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

  const [kind, setKind] = useState<PaperKind>(existing?.kind ?? FIRST_KIND);
  /*
    A new document opens on Passport with the name already filled in, because
    the tile is already selected and an empty required field under a chosen
    tile is a question the form has just answered for itself.
  */
  const [label, setLabel] = useState(existing?.label ?? KIND_LABEL[FIRST_KIND]);
  const [holder, setHolder] = useState(existing?.holder ?? '');
  const [expires, setExpires] = useState(existing?.expiresOn ?? '');
  const [issued, setIssued] = useState(existing?.issuedOn ?? '');
  const [lead, setLead] = useState<number | undefined>(existing?.leadDays);
  const [authority, setAuthority] = useState(existing?.authority ?? '');
  const [storedAt, setStoredAt] = useState(existing?.storedAt ?? '');
  const [notes, setNotes] = useState(existing?.notes ?? '');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const [confirming, setConfirming] = useState(false);

  const end = expiryOf({ expiresOn: expires });
  const canSave = !!label.trim() && !!end;

  /*
    Move on only when a card has nothing left in it. Every field the section
    contains is listed, optional ones included — setting the expiry used to
    fire this and scroll away from the three fields beside it. See
    useAutoAdvance.
  */
  const datesRef = useRef<HTMLElement>(null);
  const leadRef = useRef<HTMLElement>(null);
  useAutoAdvance(cardFilled(label, holder), datesRef);
  useAutoAdvance(cardFilled(expires, issued, authority, storedAt), leadRef);

  const effectiveLead = leadDaysFor({ kind, leadDays: lead });
  const start = end ? renewBy({ kind, leadDays: lead, expiresOn: expires }) : null;

  const pick = (k: PaperKind) => {
    // The name follows the tile — "Passport" for Passport — unless the user
    // has written their own, in which case it is theirs. "Other" clears it,
    // because it is the one tile that can't name the thing for you.
    setLabel(renameForKind(k, label, kind));
    setKind(k);
    feedback('tap');
    // Same rule for the lead time: it follows the kind until you touch it,
    // and once touched it is an opinion that a later tile must not overwrite.
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
        notes: notes.trim() || undefined,
      };
      if (existing) await updatePaper(existing.id, patch);
      else await createPaper(patch);
      feedback('save');

      /* A document with an expiry is the clearest case there is: the whole
         point of recording one is being told before it lapses. The shell
         decides whether to ask — see lib/notifyOffer.ts. */
      if (!existing && datedSave({ expiresOn: expires, hasCover: false })) armNotifyOffer();

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
              placeholder={kind === 'other' ? 'Library card, TV licence…' : KIND_LABEL[kind]}
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
          No scans or document numbers, just what's needed so Scout can remind you when the time
          comes. Because your privacy matters.
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

        {/*
          The answer sits above the control, not below it.

          It reads as the subtitle of the heading that way — you see what the
          current setting means before you touch anything, and each tap
          rewrites the line you are already looking at. Underneath the buttons
          it was a footnote about a decision you had already made.

          And it is the number turned into the thing it means: nobody has a
          view on "240 days", everybody has one on "October 2026". There is no
          placeholder for the dateless case, because a line explaining that it
          can't say anything yet is still a line to read.
        */}
        {start && (
          <p className="leadsays">
            Scout will start asking in{' '}
            <b>{start.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}</b>
            {effectiveLead > 0 && <>, {monthsBefore(effectiveLead)} before it runs out</>}.
          </p>
        )}

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
          THERE IS NO SEPARATE REMINDER, and that is a deletion rather than an
          omission. There was one — 0/1/3/7 days, copied across from the
          subscription form — and it was the same control twice.
          "How much warning" already decides the day this document starts
          asking; a reminder some days before that day is just a slightly
          longer lead time, expressed in a second unit, with its own switch to
          leave in the wrong position.

          The subscription version earns its place because a charge lands on
          one day and there is nothing else warning you. Here the lead time IS
          the warning, it never turns itself off, and it drives the sorting and
          the colour as well. Two overlapping thresholds on one record is how a
          settings screen starts.
        */}
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

/** What a new document starts as. The tile is pre-selected, so the name is too. */
const FIRST_KIND: PaperKind = 'passport';

/** "8 months" / "1 month" — the lead time, said back in the sentence. */
function monthsBefore(days: number): string {
  if (days < 45) return `${days} days`;
  const m = Math.round(days / 30.44);
  return `${m} ${m === 1 ? 'month' : 'months'}`;
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
