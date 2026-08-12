import { useState, type ReactNode } from 'react';
import { feedback } from '@/lib/feedback';
import type { DocKind } from '@/db/types';
import {
  changeDocKind,
  deleteDoc,
  DOC_KINDS,
  docHeadline,
  docSubtitle,
  downloadDoc,
  formatBytes,
  openDoc,
  renameDoc,
  type DocWithFile,
} from '@/lib/docs';

const KIND_ICON: Record<DocKind, ReactNode> = {
  receipt: (
    <>
      <path d="M6 3.5h12v17l-2-1.4-2 1.4-2-1.4-2 1.4-2-1.4-2 1.4z" />
      <path d="M9 8h6M9 11.5h6" />
    </>
  ),
  manual: (
    <>
      <path d="M4 4.5h6a2 2 0 012 2v13a2 2 0 00-2-2H4z" />
      <path d="M20 4.5h-6a2 2 0 00-2 2v13a2 2 0 012-2h6z" />
    </>
  ),
  warranty: (
    <>
      <path d="M12 3l7 3v5.5c0 4.2-2.9 7.9-7 9-4.1-1.1-7-4.8-7-9V6z" />
      <path d="M9 12l2 2 4-4" />
    </>
  ),
  photo: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <circle cx="9" cy="10" r="1.8" />
      <path d="M4 17l5-4.5 4 3.5 3-2.5 4 3.5" />
    </>
  ),
  other: (
    <>
      <path d="M14 3v5h5M14 3H6.5A1.5 1.5 0 005 4.5v15A1.5 1.5 0 006.5 21h11a1.5 1.5 0 001.5-1.5V8z" />
    </>
  ),
};

export function DocRow({ doc }: { doc: DocWithFile }) {
  const [confirming, setConfirming] = useState(false);
  const [retyping, setRetyping] = useState(false);
  const [error, setError] = useState<string>();

  const linked = doc.storageMode === 'linked';
  const subtitle = docSubtitle(doc);
  const meta = linked
    ? hostOf(doc.url)
    : [doc.mime === 'application/pdf' ? 'PDF document' : 'Photo', doc.bytes && formatBytes(doc.bytes)]
        .filter(Boolean)
        .join(' · ');

  return (
    <>
      {/*
        The whole row is the button. What the user wants to know is "which of
        these is my receipt", so the kind is the headline at full size and the
        file details are demoted underneath.
      */}
      <div className="docwrap">
        <button
          type="button"
          className="doccard"
          onClick={() => openDoc(doc).catch((e) => setError((e as Error).message))}
        >
          <span className="docicon big">
            <svg
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.7"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              {KIND_ICON[doc.kind]}
            </svg>
          </span>

          <span className="doc-txt">
            <strong>{docHeadline(doc)}</strong>
            {subtitle && <em>{subtitle}</em>}
            <small>{linked ? `Linked · ${meta}` : meta}</small>
          </span>

          <svg
            className="docgo"
            width="18"
            height="18"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            {linked ? (
              <path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 01-1 1H5a1 1 0 01-1-1V7a1 1 0 011-1h5" />
            ) : (
              <path d="M9 5l7 7-7 7" />
            )}
          </svg>
        </button>

        <div className="docactions">
          {!linked && (
            <button
              type="button"
              className="iconbtn small"
              aria-label={`Save a copy of the ${docHeadline(doc).toLowerCase()}`}
              onClick={() => downloadDoc(doc).catch((e) => setError((e as Error).message))}
            >
              <svg
                width="17"
                height="17"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M12 4v11M7.5 11L12 15.5 16.5 11M5 19h14" />
              </svg>
            </button>
          )}
          <button
            type="button"
            className="iconbtn small"
            aria-label={`Change what kind of document this is — currently ${docHeadline(doc).toLowerCase()}`}
            aria-expanded={retyping}
            onClick={() => setRetyping((v) => !v)}
          >
            <svg
              width="17"
              height="17"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M20.5 13.3l-7.2 7.2a2 2 0 01-2.9 0l-7.1-7.1a2 2 0 01-.6-1.4V4.5a1 1 0 011-1h7.5a2 2 0 011.4.6l7.9 7.9a1.6 1.6 0 010 2.3z" />
              <circle cx="7.8" cy="7.8" r="1.3" />
            </svg>
          </button>
          <button
            type="button"
            className="iconbtn small"
            aria-label={`Remove the ${docHeadline(doc).toLowerCase()}`}
            aria-expanded={confirming}
            onClick={() => setConfirming(true)}
          >
            <svg
              width="17"
              height="17"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
            >
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          </button>
        </div>
      </div>

      {error && <div className="notice bad">{error}</div>}

      {retyping && (
        <div className="sheet">
          <h4>What is this document?</h4>
          <div className="chiprow">
            {DOC_KINDS.map((k) => (
              <button
                key={k.kind}
                type="button"
                className={`pick${doc.kind === k.kind ? ' on' : ''}`}
                onClick={() =>
                  changeDocKind(doc.id, k.kind).then(() => {
                    feedback('save');
                    setRetyping(false);
                  })
                }
              >
                {k.label}
              </button>
            ))}
          </div>

          {/* Naming belongs here rather than on the way in. Attaching asks for
              nothing but the file, so the one time a title is worth typing is
              when you're looking at a row that doesn't say enough. */}
          <label className="field">
            <span className="fieldlabel">Call it something else</span>
            <input
              type="text"
              defaultValue={docSubtitle(doc) ?? ''}
              placeholder={docHeadline(doc)}
              enterKeyHint="done"
              onBlur={(e) => void renameDoc(doc.id, e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()}
            />
          </label>
        </div>
      )}

      {confirming && (
        <div className="sheet">
          <h4>
            Remove this {docHeadline(doc).toLowerCase()}?
            {!linked && ' The file is deleted from this device.'}
          </h4>
          <div className="photoactions">
            <button
              type="button"
              className="minibtn"
              onClick={() =>
                deleteDoc(doc.id).then(() => {
                  feedback('delete');
                  setConfirming(false);
                })
              }
            >
              Remove
            </button>
            <button type="button" className="minibtn ghost" onClick={() => setConfirming(false)}>
              Keep
            </button>
          </div>
        </div>
      )}
    </>
  );
}

function hostOf(url?: string): string {
  if (!url) return 'Link';
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return url;
  }
}
