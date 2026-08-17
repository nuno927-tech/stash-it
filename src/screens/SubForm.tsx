import { useRef, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { createSubscription, deleteSubscription, updateSubscription } from '@/db/repo';
import type { Cadence, Subscription } from '@/db/types';
import { parseMoneyToCents } from '@/lib/addItem';
import { completeMoneyInput, currencySymbol, formatMoneyInput } from '@/lib/format';
import { feedback } from '@/lib/feedback';
import {
  CADENCES,
  CADENCE_LABEL,
  REMIND_CHOICES,
  parseAnchor,
} from '@/lib/subscriptions';
import { CATALOGUE, searchServices, type ServiceDef } from '@/lib/services';
import { ConfirmDelete } from '@/components/ConfirmDelete';
import { ServiceMark } from '@/components/ServiceMark';
import { useAutoAdvance } from '@/components/useAutoAdvance';

/**
 * Adding or editing a recurring charge.
 *
 * Five questions, and only three of them are required: what it is, when it
 * next renews, and how much. Cadence defaults to monthly because most things
 * are, and the reminder defaults to none because an alert nobody asked for is
 * how people learn to ignore alerts.
 *
 * THE ANCHOR is asked as "when does it next renew", not "which day of the
 * month" — the day falls out of the date, and the date is the only phrasing
 * that also works for a yearly plan. See lib/subscriptions.ts.
 */
export function SubForm({
  propertyId,
  currency,
  existing,
  onSaved,
  onCancel,
}: {
  propertyId: string;
  currency: string;
  existing?: Subscription;
  onSaved: () => void;
  onCancel: () => void;
}) {
  const editing = !!existing;
  const settings = useLiveQuery(() => db.settings.get('singleton'), []);

  /*
    One field, not two. There was a search box and a Name box, which meant
    typing the name of something the catalogue didn't have, watching nothing
    match, and then typing it again underneath. What you type here *is* the
    name; picking a tile just replaces it with the official spelling and
    attaches the logo.
  */
  const [serviceId, setServiceId] = useState(existing?.serviceId ?? '');
  const [query, setQuery] = useState(existing?.name ?? '');
  const [cadence, setCadence] = useState<Cadence>(existing?.cadence ?? 'monthly');
  const [anchor, setAnchor] = useState(existing?.anchorDate ?? '');
  const [price, setPrice] = useState(
    existing ? formatMoneyInput((existing.amountCents / 100).toFixed(2), existing.currency) : '',
  );
  const [started, setStarted] = useState(existing?.startedDate ?? '');
  const [remind, setRemind] = useState(existing?.remindDays ?? 0);
  const [shared, setShared] = useState(existing?.shared ?? false);
  const [payTo, setPayTo] = useState(existing?.payTo ?? '');
  const [payHow, setPayHow] = useState(existing?.payHow ?? '');
  const [notes, setNotes] = useState(existing?.notes ?? '');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const [confirming, setConfirming] = useState(false);

  const cur = existing?.currency ?? settings?.currency ?? currency;
  const results = searchServices(query);

  /*
    A chosen service wins, because its spelling is the official one and the
    search box may still hold the half-typed thing that found it. Otherwise
    the typed text is the name — no match is not a failure, it's a gym.
  */
  const name = serviceId ? (CATALOGUE.find((s) => s.id === serviceId)?.name ?? query) : query;

  const canSave = !!name.trim() && !!parseAnchor(anchor) && (parseMoneyToCents(price) ?? 0) > 0;

  /*
    Move on when a card is done with. Each section watches the answer that
    finishes it and points at the next — picking a service is a discrete tap,
    so it advances; typing a name is not, so it doesn't. See useAutoAdvance
    for everything this deliberately refuses to do.
  */
  const billingRef = useRef<HTMLElement>(null);
  const remindRef = useRef<HTMLElement>(null);
  useAutoAdvance(!!serviceId, billingRef);
  useAutoAdvance(!!parseAnchor(anchor) && (parseMoneyToCents(price) ?? 0) > 0, remindRef);

  const choose = (s: ServiceDef) => {
    // Tapping the chosen one again lets go of it, so a mis-tap doesn't have to
    // be undone by deleting the text it wrote.
    const same = serviceId === s.id;
    setServiceId(same ? '' : s.id);
    if (!same) setQuery(s.name);
    feedback('tap');
  };

  const save = async () => {
    setBusy(true);
    setError(undefined);
    try {
      const cents = parseMoneyToCents(price) ?? 0;
      const patch = {
        propertyId,
        name: name.trim(),
        serviceId: serviceId || undefined,
        cadence,
        anchorDate: anchor,
        amountCents: cents,
        currency: cur,
        startedDate: started || undefined,
        remindDays: remind || undefined,
        // Turning the toggle off clears the two fields rather than leaving
        // them to reappear if it's ever switched back on.
        shared: shared || undefined,
        payTo: shared ? payTo.trim() || undefined : undefined,
        payHow: shared ? payHow.trim() || undefined : undefined,
        notes: notes.trim() || undefined,
      };
      if (existing) await updateSubscription(existing.id, patch);
      else await createSubscription(patch);
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
          {editing ? 'Edit subscription' : 'New subscription'}
        </div>
        <span style={{ width: 34 }} />
      </header>

      {error && <div className="notice bad">{error}</div>}

      {/* ------------------------------------------------------- which one */}
      <section className="card formcard">
        <div className="cardhead">
          <h3>Service</h3>
          {!!name.trim() && <ServiceMark serviceId={serviceId} name={name} size={30} />}
        </div>

        {/* The name and the search, in one box. */}
        <input
          type="text"
          value={query}
          placeholder="Netflix, Spotify, the gym…"
          aria-label="What are you paying for?"
          onChange={(e) => {
            setQuery(e.target.value);
            // Typing away from a chosen service unpicks it.
            if (serviceId) setServiceId('');
          }}
        />

        <div className="servicegrid">
          {results.slice(0, 30).map((s) => (
            <button
              key={s.id}
              type="button"
              className={`servicetile${serviceId === s.id ? ' on' : ''}`}
              onClick={() => choose(s)}
            >
              <ServiceMark serviceId={s.id} name={s.name} size={30} />
              <small>{s.name}</small>
            </button>
          ))}
        </div>

        {results.length === 0 && (
          <p className="hint">
            Nothing matches, which is fine — it'll be saved as <b>{query.trim()}</b> with its
            initials for a mark.
          </p>
        )}

      </section>

      {/* ----------------------------------------------------- what it costs */}
      <section className="card formcard" ref={billingRef}>
        <div className="cardhead">
          <h3>Billing</h3>
        </div>

        <label className="field">
          <span className="fieldlabel">How often</span>
          <div className="seg">
            {CADENCES.map((c) => (
              <button
                key={c}
                type="button"
                className={cadence === c ? 'on' : ''}
                onClick={() => setCadence(c)}
              >
                {CADENCE_LABEL[c]}
              </button>
            ))}
          </div>
        </label>

        <div className="fieldpair">
          <label className="field">
            <span className="fieldlabel">Next renewal</span>
            <input
              type="date"
              lang="en-US"
              value={anchor}
              onChange={(e) => setAnchor(e.target.value)}
            />
          </label>
          <label className="field">
            <span className="fieldlabel">Amount</span>
            <div className="moneyfield">
              <span aria-hidden="true">{currencySymbol(cur)}</span>
              <input
                type="text"
                inputMode="decimal"
                value={price}
                placeholder="12.99"
                onChange={(e) => setPrice(formatMoneyInput(e.target.value, cur))}
                onBlur={() => setPrice(completeMoneyInput(price, cur))}
              />
            </div>
          </label>
        </div>

        <label className="field">
          <span className="fieldlabel">Started</span>
          <input
            type="date"
            lang="en-US"
            value={started}
            onChange={(e) => setStarted(e.target.value)}
          />
        </label>

        {/*
          Splitting. The amount above stays what *you* pay either way — every
          total in the app is built from it, and a number that sometimes means
          the whole bill and sometimes half of it makes the monthly figure
          meaningless. These two only record the arrangement.
        */}
        <div className="setrow">
          <span className="setrow-txt">
            <strong>Split with someone</strong>
            <small>Records who the money goes to, not what it costs</small>
          </span>
          {/* The same control Settings uses. A second switch that looked
              almost the same would be a second thing to keep in step. */}
          <button
            type="button"
            className={`toggle${shared ? ' on' : ''}`}
            role="switch"
            aria-checked={shared}
            aria-label="Split with someone"
            data-cue="none"
            onClick={() => setShared((v) => !v)}
          >
            <span />
          </button>
        </div>

        {shared && (
          <div className="fieldpair">
            <Field label="Who you pay">
              <input
                type="text"
                value={payTo}
                placeholder="Dave, my sister…"
                onChange={(e) => setPayTo(e.target.value)}
              />
            </Field>
            <Field label="How">
              <input
                type="text"
                value={payHow}
                placeholder="Venmo, cash…"
                onChange={(e) => setPayHow(e.target.value)}
              />
            </Field>
          </div>
        )}
      </section>

      {/* -------------------------------------------------------- reminders */}
      <section className="card formcard" ref={remindRef}>
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
            ? 'No reminder. You can turn one on later.'
            : `A card appears on the home screen ${remind} day${remind === 1 ? '' : 's'} before it renews — the next time you open Stash it. Nothing reaches your phone while the app is closed; that needs a server, and there isn't one yet.`}
        </p>

        <Field label="Notes">
          <textarea
            rows={3}
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Optional"
          />
        </Field>
      </section>

      {editing && (
        <>
          <button
            type="button"
            className="btn ghost wide"
            aria-haspopup="dialog"
            onClick={() => setConfirming(true)}
          >
            Delete subscription
          </button>
          {confirming && (
            <ConfirmDelete
              name={existing.name}
              permanent
              onConfirm={() => {
                void deleteSubscription(existing.id).then(() => {
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
            {!name.trim()
              ? 'Pick a service or type a name.'
              : !parseAnchor(anchor)
                ? 'Add the next renewal date.'
                : 'Add what it costs.'}
          </p>
        )}
        <button type="button" className="btn wide" disabled={busy || !canSave} onClick={() => void save()}>
          {busy ? 'Saving…' : editing ? 'Save changes' : 'Save subscription'}
        </button>
      </div>
    </div>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: import('react').ReactNode;
}) {
  return (
    <label className="field">
      <span className="fieldlabel">{label}</span>
      {children}
    </label>
  );
}

export { CATALOGUE };
