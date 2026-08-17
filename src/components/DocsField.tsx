import { useState } from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import type { DocKind } from '@/db/types';
import {
  changeDocKind,
  deleteDoc,
  DOC_KIND_LABEL,
  docsWithFiles,
  DocError,
  formatBytes,
  stageDocs,
  type StagedDoc,
} from '@/lib/docs';
import { feedback } from '@/lib/feedback';
import { DocGlyph, DocTiles, DOC_KIND_ORDER } from './DocTiles';

/**
 * Documents on the add and edit form. The tiles are shared with the item page
 * — see DocTiles — and the only difference here is that a file chosen before
 * the item exists has nowhere to be written yet, so it's held in memory until
 * the form saves.
 */
export function DocsField({
  itemId,
  staged,
  onStage,
  onUnstage,
  onRetype,
  bare = false,
}: {
  /** Present only when editing. */
  itemId?: string;
  staged: StagedDoc[];
  onStage: (doc: StagedDoc) => void;
  onUnstage: (key: string) => void;
  onRetype: (key: string, kind: DocKind) => void;
  /**
   * Drop the card, keep the heading. Behind the item form's details door
   * everything else is boxless, and one bordered section in a run of plain
   * ones reads as a mistake rather than as emphasis.
   */
  bare?: boolean;
}) {
  const existing = useLiveQuery(async () => (itemId ? docsWithFiles(itemId) : []), [itemId]) ?? [];
  const [error, setError] = useState<string>();

  const take = (kind: DocKind, files: File[]) => {
    try {
      const already = staged.filter((s) => s.kind === kind).length;
      for (const doc of stageDocs(kind, files, already)) onStage(doc);
      feedback('attach');
      setError(undefined);
    } catch (e) {
      feedback('error');
      setError(e instanceof DocError ? e.message : (e as Error).message);
    }
  };

  const count = existing.length + staged.length;

  const Wrap = bare ? 'div' : 'section';

  return (
    <Wrap className={bare ? 'askblock' : 'card'}>
      <div className={bare ? 'asklabel row' : 'cardhead'}>
        {bare ? <span>Documents</span> : <h3>Documents</h3>}
        {count > 0 && <span className="countpill">{count}</span>}
      </div>

      <DocTiles onFiles={take} />

      {error && <div className="notice bad">{error}</div>}

      {count > 0 && (
        <ul className="doclist">
          {existing.map((d) => (
            <li key={d.id} className="docchip">
              <DocGlyph kind={d.kind} small />
              <select
                className="chipkind"
                value={d.kind}
                aria-label="Document type"
                onChange={(e) =>
                  changeDocKind(d.id, e.target.value as DocKind).then(() => feedback('save'))
                }
              >
                {DOC_KIND_ORDER.map((k) => (
                  <option key={k} value={k}>
                    {DOC_KIND_LABEL[k]}
                  </option>
                ))}
              </select>
              <span className="chipmeta">
                {d.storageMode === 'linked' ? 'Linked' : d.bytes ? formatBytes(d.bytes) : 'Saved'}
              </span>
              <button
                type="button"
                className="iconbtn small"
                aria-label={`Remove the ${DOC_KIND_LABEL[d.kind].toLowerCase()}`}
                onClick={() => deleteDoc(d.id).then(() => feedback('delete'))}
              >
                <Cross />
              </button>
            </li>
          ))}

          {staged.map((s) => (
            <li key={s.key} className="docchip pending">
              <DocGlyph kind={s.kind} small />
              <select
                className="chipkind"
                value={s.kind}
                aria-label="Document type"
                onChange={(e) => onRetype(s.key, e.target.value as DocKind)}
              >
                {DOC_KIND_ORDER.map((k) => (
                  <option key={k} value={k}>
                    {DOC_KIND_LABEL[k]}
                  </option>
                ))}
              </select>
              <span className="chipmeta">
                {s.title ? `${s.title} · ` : ''}
                {formatBytes(s.file.size)}
              </span>
              <button
                type="button"
                className="iconbtn small"
                aria-label={`Remove the ${DOC_KIND_LABEL[s.kind].toLowerCase()}`}
                onClick={() => onUnstage(s.key)}
              >
                <Cross />
              </button>
            </li>
          ))}
        </ul>
      )}

      {count === 0 && (
        <p className="hint">
          The receipt and the warranty are the two a claim will ask for. Tap to choose a file, or
          the camera to photograph it.
        </p>
      )}
    </Wrap>
  );
}

function Cross() {
  return (
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
  );
}
