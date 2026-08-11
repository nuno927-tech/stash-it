import { useRef, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import type { DocKind } from '@/db/types';
import {
  changeDocKind,
  deleteDoc,
  DOC_ACCEPT,
  DOC_KIND_LABEL,
  docsWithFiles,
  DocError,
  formatBytes,
  stageDocs,
  type StagedDoc,
} from '@/lib/docs';
import { feedback } from '@/lib/feedback';

/** The three people actually reach for, then everything else. */
const QUICK: DocKind[] = ['receipt', 'warranty', 'manual'];
const REST: DocKind[] = ['photo', 'other'];

/**
 * Documents inside the item form, so a receipt can be attached while adding
 * rather than only after the fact.
 *
 * New files are staged, not written — there's no item id yet on the add path,
 * and staging means an abandoned form leaves nothing behind. Documents already
 * on an existing item are listed alongside and deleted immediately, because
 * those are real records the user can already see elsewhere.
 */
export function DocsField({
  itemId,
  staged,
  onStage,
  onUnstage,
  onRetype,
}: {
  /** Present only when editing. */
  itemId?: string;
  staged: StagedDoc[];
  onStage: (doc: StagedDoc) => void;
  onUnstage: (key: string) => void;
  onRetype: (key: string, kind: DocKind) => void;
}) {
  const existing = useLiveQuery(
    async () => (itemId ? docsWithFiles(itemId) : []),
    [itemId],
  ) ?? [];

  const [kind, setKind] = useState<DocKind>('receipt');
  const [showRest, setShowRest] = useState(false);
  const [error, setError] = useState<string>();
  const picker = useRef<HTMLInputElement>(null);
  const camera = useRef<HTMLInputElement>(null);

  const take = (files: FileList | null) => {
    if (!files || files.length === 0) return;
    try {
      // Count what's already staged for this kind so a second batch keeps
      // numbering from where the first left off.
      const sameKind = staged.filter((s) => s.kind === kind).length;
      for (const doc of stageDocs(kind, [...files], sameKind)) onStage(doc);
      feedback('attach');
      setError(undefined);
    } catch (e) {
      feedback('error');
      setError(e instanceof DocError ? e.message : (e as Error).message);
    }
  };

  const kinds = showRest ? [...QUICK, ...REST] : QUICK;

  return (
    <>
      <div className="fieldlabel">Documents</div>

      <div className="chiprow">
        {kinds.map((k) => (
          <button
            key={k}
            type="button"
            className={`pick${kind === k ? ' on' : ''}`}
            onClick={() => setKind(k)}
          >
            {DOC_KIND_LABEL[k]}
          </button>
        ))}
        {!showRest && (
          <button
            type="button"
            className="pick"
            aria-expanded={false}
            onClick={() => setShowRest(true)}
          >
            More
          </button>
        )}
      </div>

      <div className="photoactions">
        <button type="button" className="minibtn" onClick={() => picker.current?.click()}>
          Attach {DOC_KIND_LABEL[kind].toLowerCase()}
        </button>
        <button type="button" className="minibtn ghost" onClick={() => camera.current?.click()}>
          Photograph it
        </button>
      </div>

      {/* `multiple` on both: a warranty is often several pages, and the photo
          library lets you select them all in one go. */}
      <input
        ref={picker}
        type="file"
        accept={DOC_ACCEPT}
        multiple
        hidden
        onChange={(e) => {
          take(e.target.files);
          e.target.value = '';
        }}
      />
      <input
        ref={camera}
        type="file"
        accept="image/*"
        capture="environment"
        multiple
        hidden
        onChange={(e) => {
          take(e.target.files);
          e.target.value = '';
        }}
      />

      {error && <div className="notice bad">{error}</div>}

      {existing.map((d) => (
        <div key={d.id} className="stagerow">
          {/* A select rather than chips: the row is narrow, and reclassifying
              is rare enough that it doesn't need to be one tap. */}
          <select
            className="kindpick"
            value={d.kind}
            aria-label="Document type"
            onChange={(e) => changeDocKind(d.id, e.target.value as DocKind).then(() => feedback('save'))}
          >
            {[...QUICK, ...REST].map((k) => (
              <option key={k} value={k}>
                {DOC_KIND_LABEL[k]}
              </option>
            ))}
          </select>
          <span className="stagemeta">
            {d.storageMode === 'linked' ? 'Linked' : d.bytes ? formatBytes(d.bytes) : 'On device'}
          </span>
          <button
            type="button"
            className="iconbtn small"
            aria-label={`Remove the ${DOC_KIND_LABEL[d.kind].toLowerCase()}`}
            onClick={() => deleteDoc(d.id).then(() => feedback('delete'))}
          >
            <Cross />
          </button>
        </div>
      ))}

      {staged.map((s) => (
        <div key={s.key} className="stagerow pending">
          <select
            className="kindpick"
            value={s.kind}
            aria-label="Document type"
            onChange={(e) => onRetype(s.key, e.target.value as DocKind)}
          >
            {[...QUICK, ...REST].map((k) => (
              <option key={k} value={k}>
                {DOC_KIND_LABEL[k]}
              </option>
            ))}
          </select>
          <span className="stagemeta">
            {s.title ? `${s.title} · ` : ''}
            {formatBytes(s.file.size)} · saves with the item
          </span>
          <button
            type="button"
            className="iconbtn small"
            aria-label={`Remove the ${DOC_KIND_LABEL[s.kind].toLowerCase()}`}
            onClick={() => onUnstage(s.key)}
          >
            <Cross />
          </button>
        </div>
      ))}

      {existing.length === 0 && staged.length === 0 && (
        <p className="hint">
          The receipt and the warranty are the two a claim will ask for. Attach them now and you
          won't have to find them later. Multi-page documents can be picked all at once.
        </p>
      )}
    </>
  );
}

function Cross() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2.2"
      strokeLinecap="round"
    >
      <path d="M6 6l12 12M18 6L6 18" />
    </svg>
  );
}
