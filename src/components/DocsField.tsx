import { useRef, useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import type { DocKind } from '@/db/types';
import {
  deleteDoc,
  DOC_ACCEPT,
  DOC_KIND_LABEL,
  docsWithFiles,
  DocError,
  formatBytes,
  stageDoc,
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
}: {
  /** Present only when editing. */
  itemId?: string;
  staged: StagedDoc[];
  onStage: (doc: StagedDoc) => void;
  onUnstage: (key: string) => void;
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

  const take = (file: File | undefined) => {
    if (!file) return;
    try {
      onStage(stageDoc(kind, file));
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
          <button type="button" className="pick" onClick={() => setShowRest(true)}>
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

      <input
        ref={picker}
        type="file"
        accept={DOC_ACCEPT}
        hidden
        onChange={(e) => {
          take(e.target.files?.[0]);
          e.target.value = '';
        }}
      />
      <input
        ref={camera}
        type="file"
        accept="image/*"
        capture="environment"
        hidden
        onChange={(e) => {
          take(e.target.files?.[0]);
          e.target.value = '';
        }}
      />

      {error && <div className="notice bad">{error}</div>}

      {existing.map((d) => (
        <div key={d.id} className="stagerow">
          <span className="stagekind">{DOC_KIND_LABEL[d.kind]}</span>
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
          <span className="stagekind">{DOC_KIND_LABEL[s.kind]}</span>
          <span className="stagemeta">{formatBytes(s.file.size)} · saves with the item</span>
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
          won't have to find them later.
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
