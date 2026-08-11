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

/**
 * Attaching paperwork, in one tap per document.
 *
 * The previous version made you set a kind on one control, then pick a source
 * on another, then find your file — three decisions and two of them ours. Now
 * the kind *is* the button: tapping Receipt opens the picker already knowing
 * what it's collecting.
 *
 * Each tile is a split control: the label picks a file, the camera corner
 * shoots one. An earlier version relied on the file picker offering Take Photo
 * itself — it does on some devices and goes straight to the photo library on
 * others, which loses the camera entirely. `capture` is the only guarantee.
 */
const PRIMARY: DocKind[] = ['receipt', 'warranty', 'manual'];
const SECONDARY: DocKind[] = ['photo', 'other'];

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
  const existing = useLiveQuery(async () => (itemId ? docsWithFiles(itemId) : []), [itemId]) ?? [];

  const [showMore, setShowMore] = useState(false);
  const [error, setError] = useState<string>();
  const picker = useRef<HTMLInputElement>(null);
  const camera = useRef<HTMLInputElement>(null);
  // Which tile was pressed, read back when the picker returns.
  const pending = useRef<DocKind>('receipt');

  const open = (kind: DocKind, source: 'files' | 'camera' = 'files') => {
    pending.current = kind;
    (source === 'camera' ? camera : picker).current?.click();
  };

  const take = (files: FileList | null) => {
    if (!files || files.length === 0) return;
    try {
      const kind = pending.current;
      const already = staged.filter((s) => s.kind === kind).length;
      for (const doc of stageDocs(kind, [...files], already)) onStage(doc);
      feedback('attach');
      setError(undefined);
    } catch (e) {
      feedback('error');
      setError(e instanceof DocError ? e.message : (e as Error).message);
    }
  };

  const count = existing.length + staged.length;

  return (
    <section className="card">
      <div className="cardhead">
        <h3>Documents</h3>
        {count > 0 && <span className="countpill">{count}</span>}
      </div>

      <div className="doctiles">
        {PRIMARY.map((k) => (
          <Tile key={k} kind={k} onOpen={open} />
        ))}
      </div>

      {showMore ? (
        <div className="doctiles two">
          {SECONDARY.map((k) => (
            <Tile key={k} kind={k} onOpen={open} />
          ))}
        </div>
      ) : (
        <button
          type="button"
          className="linkish morelink"
          aria-expanded={false}
          onClick={() => setShowMore(true)}
        >
          Something else
        </button>
      )}

      {/* Two inputs: one for files, one that forces the camera. Both accept
          multiple, because a warranty is routinely several pages. */}
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
                {[...PRIMARY, ...SECONDARY].map((k) => (
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
                {[...PRIMARY, ...SECONDARY].map((k) => (
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
    </section>
  );
}

/**
 * A tile is two targets in one shape: the body opens the file picker, the
 * corner opens the camera. Nested buttons are invalid, so the tile is a div
 * with two children rather than a button containing a button.
 */
function Tile({
  kind,
  onOpen,
}: {
  kind: DocKind;
  onOpen: (kind: DocKind, source?: 'files' | 'camera') => void;
}) {
  return (
    <div className="doctile">
      <button type="button" className="doctile-main" onClick={() => onOpen(kind)}>
        <DocGlyph kind={kind} />
        {DOC_KIND_LABEL[kind]}
      </button>
      <button
        type="button"
        className="doctile-cam"
        aria-label={`Photograph the ${DOC_KIND_LABEL[kind].toLowerCase()}`}
        onClick={() => onOpen(kind, 'camera')}
      >
        <svg
          width="15"
          height="15"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M3 8.5A1.5 1.5 0 014.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0121 8.5v9A1.5 1.5 0 0119.5 19h-15A1.5 1.5 0 013 17.5z" />
          <circle cx="12" cy="13" r="3.4" />
        </svg>
      </button>
    </div>
  );
}

const GLYPH: Record<DocKind, string> = {
  receipt: 'M6 3.5h12v17l-2-1.4-2 1.4-2-1.4-2 1.4-2-1.4-2 1.4z M9 8h6M9 11.5h6',
  warranty: 'M12 3l7 3v5.5c0 4.2-2.9 7.9-7 9-4.1-1.1-7-4.8-7-9V6z M9 12l2 2 4-4',
  manual: 'M4 4.5h6a2 2 0 012 2v13a2 2 0 00-2-2H4z M20 4.5h-6a2 2 0 00-2 2v13a2 2 0 012-2h6z',
  photo: 'M3 5.5h18v13H3z M8 11a2 2 0 100-4 2 2 0 000 4z M4 17l5-4.5 4 3.5 3-2.5 4 3.5',
  other: 'M14 3v5h5M14 3H6.5A1.5 1.5 0 005 4.5v15A1.5 1.5 0 006.5 21h11a1.5 1.5 0 001.5-1.5V8z',
};

function DocGlyph({ kind, small }: { kind: DocKind; small?: boolean }) {
  const size = small ? 16 : 22;
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {GLYPH[kind].split(' M').map((d, i) => (
        <path key={i} d={i === 0 ? d : `M${d}`} />
      ))}
    </svg>
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
