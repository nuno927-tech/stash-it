import { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { activePapers, deletePaper } from '@/db/repo';
import type { Paper } from '@/db/types';
import {
  KIND_LABEL,
  expiryLabel,
  needsRenewing,
  nextUp,
  paperLabel,
  paperState,
  sortPapers,
} from '@/lib/papers';
import { feedback } from '@/lib/feedback';
import { ConfirmDelete } from '@/components/ConfirmDelete';
import { PaperIcon } from '@/components/PaperIcon';
import { Scout } from '@/components/Scout';
import { SwipeRow } from '@/components/SwipeRow';

/**
 * Documents that expire — passports, licences, permits, the MOT.
 *
 * A tab rather than a corner of Items, for the same reason subscriptions got
 * one: a passport has no room, no photo, no price and no warranty, and every
 * query on the items list would have to learn to skip it.
 *
 * ── The one thing this screen does differently from every other list ──────
 * It sorts by when each document needs STARTING, not by when it expires. A
 * passport expiring in nine months goes above a licence expiring in four,
 * because one needs eight months of runway and the other needs two. Sorted by
 * the printed date they come out backwards, and coming out backwards is the
 * mistake a calendar reminder makes. See lib/papers.ts.
 *
 * ── What is deliberately absent ───────────────────────────────────────────
 * There is nowhere to put a scan and nowhere to put a document number. The
 * database is not encrypted and backups are plaintext, so the app stores the
 * dates and leaves the document itself where it is. The note on the Paper type
 * has the full argument.
 */
export function Papers({
  propertyId,
  onOpen,
}: {
  propertyId: string;
  onOpen: (id: string) => void;
}) {
  const papers = useLiveQuery(() => activePapers(propertyId), [propertyId]);
  const [swiped, setSwiped] = useState<string | null>(null);
  const [confirming, setConfirming] = useState<Paper | null>(null);
  const now = new Date();

  if (!papers) return null;

  const jobs = needsRenewing(papers, now);
  const next = nextUp(papers, now);
  const expired = papers.filter((p) => paperState(p, now) === 'expired').length;

  return (
    <>
      <header className="apphead">
        <div className="apptitle">Documents</div>
      </header>

      {papers.length === 0 ? (
        <div className="empty">
          <Scout pose="clipboard" height={170} motion={['float']} shadow alt="" />
          <h3>Nothing tracked yet</h3>
          <p>
            Passports, IDs, licences. Scout will tell you when to start renewing, not when it's
            already too late.
          </p>
          <p>General info and dates only, because your privacy matters.</p>
        </div>
      ) : (
        <>
          {/* Same masthead as Items, Subs and Settings. */}
          <div className="subshead">
            <div className="subtotals">
              <div className="subtotal">
                <strong>{papers.length}</strong>
                <small>{papers.length === 1 ? 'document' : 'documents'}</small>
              </div>
              {/*
                Gold, but only when there is something to be gold about.

                On the subscriptions tab the accent marks the headline figure;
                here it marks the one that wants doing, which is the same rule
                stated for a screen whose subject is a job rather than a sum. A
                gold zero would be the app shouting about nothing — when
                everything is in date, nothing on this row is highlighted, and
                that reads correctly as "no action needed".
              */}
              <div className={`subtotal${jobs.length > 0 ? ' lead' : ''}`}>
                <strong>{jobs.length}</strong>
                <small>{jobs.length === 1 ? 'needs action' : 'need action'}</small>
              </div>
              <div className="subtotal">
                <strong>{expired}</strong>
                <small>{expired === 1 ? 'expired' : 'out of date'}</small>
              </div>
              <div className="subtotal">
                <strong>{next ? KIND_LABEL[next.kind] : '—'}</strong>
                <small>{next ? 'up next' : 'nothing queued'}</small>
              </div>
            </div>

            <Scout pose="clipboard" height={104} motion={['breathe']} alt="" />
          </div>

          {jobs.length > 0 && (
            <p className="hint calnote">
              {jobs.length === 1 ? 'One document needs' : `${jobs.length} documents need`} action
              now. The rest are listed by when to begin, not when they run out.
            </p>
          )}

          <ul className="sublist">
            {sortPapers(papers, now).map((p) => (
              <li key={p.id}>
                <SwipeRow
                  open={swiped === p.id}
                  onOpenChange={(o) => setSwiped(o ? p.id : null)}
                  deleteLabel={`Delete ${p.label}`}
                  onDelete={() => setConfirming(p)}
                >
                  <button
                    type="button"
                    className="subrow"
                    onClick={() => (swiped === p.id ? setSwiped(null) : onOpen(p.id))}
                  >
                    <PaperIcon kind={p.kind} state={paperState(p, now)} />
                    <span className="subtxt">
                      <strong>{p.label}</strong>
                      <small>
                        {p.holder ? `${p.holder} · ` : ''}
                        {paperLabel(p, now)}
                      </small>
                    </span>
                    {/* The printed date, quietly, on the right. It's the fact
                        people came to look up; the line on the left is the
                        one telling them what to do about it. */}
                    <span className="papervalid">{expiryLabel(p).replace('Valid to ', '')}</span>
                  </button>
                </SwipeRow>
              </li>
            ))}
          </ul>
        </>
      )}

      {confirming && (
        <ConfirmDelete
          name={confirming.label}
          permanent
          onConfirm={() => {
            void deletePaper(confirming.id).then(() => feedback('delete'));
            setConfirming(null);
            setSwiped(null);
          }}
          onCancel={() => setConfirming(null)}
        />
      )}
    </>
  );
}
