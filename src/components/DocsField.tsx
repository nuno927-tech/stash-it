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
import { LinkDoc } from './LinkDoc';

/**
 * Attachments on the add and edit form — receipts, manuals, photos of the
 * warranty card.
 *
 * NAMED "ATTACHMENTS", NOT "DOCUMENTS". These hang off an item and only exist
 * because it does. The Documents tab is a different thing entirely: passports
 * and licences, which belong to a person and expire on their own. Two features
 * called Documents on one phone is one too many, and this is the one that was
 * always really "the paperwork for this kettle".
 *
 * The internal names are the other way round and cannot be swapped without a
 * database migration for no gain: these are `Doc`/`docs`, and the tab's records
 * are `Paper`/`papers`. Read the type, not the word.
 *
 * The tiles are shared with the item page. The tiles are shared with the item page
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
  sectionRef,
}: {
  /** Present only when editing. */
  itemId?: string;
  staged: StagedDoc[];
  onStage: (doc: StagedDoc) => void;
  onUnstage: (key: string) => void;
  onRetype: (key: string, kind: DocKind) => void;
  /** So the form above can scroll this section into view. */
  sectionRef?: import('react').RefObject<HTMLElement | null>;
}) {
  const existing = useLiveQuery(async () => (itemId ? docsWithFiles(itemId) : []), [itemId]) ?? [];
  const [error, setError] = useState<string>();
  const [linking, setLinking] = useState(false);

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

  return (
    <section className="card formcard" ref={sectionRef}>
      <div className="cardhead">
        <h3>Attachments</h3>
        {count > 0 && <span className="countpill">{count}</span>}
      </div>

      {/* Said once, at the top, where it explains the six buttons underneath
          rather than turning up after them as a footnote. Only while there's
          nothing attached: once you've added a receipt, being told what a
          claim asks for is a sentence you've already acted on. */}
      {count === 0 && (
        <p className="hint dochint">
          The receipt and the warranty are the two a claim will ask for. Tap to choose a file, the
          camera to photograph it, or the last one to link to something on the web.
        </p>
      )}

      {/* The web link is the sixth tile now — it's the same decision as the
          other five, and the only difference is where the bytes come from. */}
      <DocTiles onFiles={take} onLink={() => setLinking(true)} />

      {linking && (
        <LinkDoc
          itemId={itemId}
          onStage={onStage}
          onDone={() => setLinking(false)}
          onCancel={() => setLinking(false)}
        />
      )}

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
                {s.title ? `${s.title}${s.file ? ' · ' : ''}` : ''}
                {s.file ? formatBytes(s.file.size) : 'Link'}
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

    </section>
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
