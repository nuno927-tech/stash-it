import { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db/db';
import { createSubscription, deleteSubscription, putBlob, updateSubscription } from '@/db/repo';
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
import {
  CATALOGUE,
  findService,
  LOGO_FETCH_NOTE,
  logoUrlFor,
  searchServices,
  type ServiceDef,
} from '@/lib/services';
import { ConfirmDelete } from '@/components/ConfirmDelete';
import { ServiceMark } from '@/components/ServiceMark';

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

  const [serviceId, setServiceId] = useState(existing?.serviceId ?? '');
  const [name, setName] = useState(existing?.name ?? '');
  const [query, setQuery] = useState('');
  const [cadence, setCadence] = useState<Cadence>(existing?.cadence ?? 'monthly');
  const [anchor, setAnchor] = useState(existing?.anchorDate ?? '');
  const [price, setPrice] = useState(
    existing ? formatMoneyInput((existing.amountCents / 100).toFixed(2), existing.currency) : '',
  );
  const [started, setStarted] = useState(existing?.startedDate ?? '');
  const [remind, setRemind] = useState(existing?.remindDays ?? 0);
  const [domain, setDomain] = useState('');
  const [logoBlobId, setLogoBlobId] = useState(existing?.logoBlobId);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const [confirming, setConfirming] = useState(false);

  const cur = existing?.currency ?? settings?.currency ?? currency;
  const custom = !serviceId;
  const results = searchServices(query);

  const canSave = !!name.trim() && !!parseAnchor(anchor) && (parseMoneyToCents(price) ?? 0) > 0;

  const choose = (s: ServiceDef) => {
    setServiceId(s.id);
    setName(s.name);
    setLogoBlobId(undefined);
    feedback('tap');
  };

  /**
   * The one outbound request in the app.
   *
   * Asks the company's own site for its favicon — no logo service in the
   * middle, so the request reveals one subscription to the company you already
   * subscribe to. Stored as a blob straight away, so it happens once rather
   * than on every render, and never again for this service.
   */
  const fetchLogo = async () => {
    const url = logoUrlFor(domain);
    if (!url) {
      setError('That doesn’t look like a web address — try netflix.com.');
      return;
    }
    setBusy(true);
    setError(undefined);
    try {
      const res = await fetch(url, { mode: 'cors' });
      if (!res.ok) throw new Error(String(res.status));
      const blob = await res.blob();
      if (!blob.type.startsWith('image/') || blob.size === 0) throw new Error('not an image');
      if (blob.size > 200_000) throw new Error('too big');
      setLogoBlobId(await putBlob(blob));
      feedback('attach');
    } catch {
      feedback('error');
      // Not an error worth stopping for: initials are a fine outcome.
      setError('Couldn’t get a logo from there. Initials will be used instead.');
    } finally {
      setBusy(false);
    }
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
        logoBlobId,
        cadence,
        anchorDate: anchor,
        amountCents: cents,
        currency: cur,
        startedDate: started || undefined,
        remindDays: remind || undefined,
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
          {name && (
            <ServiceMark serviceId={serviceId} logoBlobId={logoBlobId} name={name} size={30} />
          )}
        </div>

        <input
          type="text"
          value={query}
          placeholder="Search Netflix, Spotify, the gym…"
          aria-label="Search services"
          onChange={(e) => setQuery(e.target.value)}
        />

        <div className="servicegrid">
          {results.slice(0, 24).map((s) => (
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
          <p className="hint">Nothing matches. Type the name below and it'll be saved as it is.</p>
        )}

        <label className="field">
          <span className="fieldlabel">Name</span>
          <input
            type="text"
            value={name}
            placeholder="What are you paying for?"
            onChange={(e) => {
              setName(e.target.value);
              // Typing over a chosen service makes it a custom one again.
              if (serviceId && e.target.value !== findService(serviceId)?.name) setServiceId('');
            }}
          />
        </label>

        {/* Only offered for services with no bundled mark, and never
            automatic — see LOGO_FETCH_NOTE. */}
        {custom && !!name.trim() && (
          <>
            <div className="fieldpair">
              <label className="field">
                <span className="fieldlabel">Website</span>
                <input
                  type="text"
                  value={domain}
                  placeholder="Optional"
                  inputMode="url"
                  onChange={(e) => setDomain(e.target.value)}
                />
              </label>
              <label className="field">
                <span className="fieldlabel">Logo</span>
                <button
                  type="button"
                  className="minibtn"
                  disabled={busy || !domain.trim()}
                  onClick={() => void fetchLogo()}
                >
                  {logoBlobId ? 'Got it' : 'Fetch logo'}
                </button>
              </label>
            </div>
            <p className="hint">{LOGO_FETCH_NOTE}</p>
          </>
        )}
      </section>

      {/* ----------------------------------------------------- what it costs */}
      <section className="card formcard">
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
            ? 'No reminder. You can turn one on later.'
            : `A card appears on the home screen ${remind} day${remind === 1 ? '' : 's'} before it renews — the next time you open Stash it. Nothing reaches your phone while the app is closed; that needs a server, and there isn't one yet.`}
        </p>
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

export { CATALOGUE };
