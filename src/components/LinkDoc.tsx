import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import type { DocKind } from '@/db/types';
import { pushBack } from '@/lib/backstack';
import { attachLink, DOC_KIND_LABEL, DocError } from '@/lib/docs';
import { feedback } from '@/lib/feedback';
import { DOC_KIND_ORDER } from './DocTiles';

/**
 * Linking to a document that lives on the web — a manual on the manufacturer's
 * site, almost always.
 *
 * The only attachment that still needs a form, because a URL is the one thing
 * a file picker can't hand over. Defaults to a manual and asks for nothing
 * else: the hostname becomes the title if the user doesn't want to write one.
 *
 * Portalled for the same reason every other dialog here is — `position: fixed`
 * is only fixed to the viewport when no ancestor has a transform, and this one
 * opens from a screen that animates in.
 */
export function LinkDoc({
  itemId,
  onDone,
  onCancel,
}: {
  itemId: string;
  onDone: () => void;
  onCancel: () => void;
}) {
  const [kind, setKind] = useState<DocKind>('manual');
  const [url, setUrl] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();

  useEffect(() => pushBack(onCancel), [onCancel]);

  const save = async () => {
    setBusy(true);
    setError(undefined);
    try {
      await attachLink(itemId, kind, url);
      feedback('attach');
      onDone();
    } catch (e) {
      feedback('error');
      setError(e instanceof DocError ? e.message : (e as Error).message);
      setBusy(false);
    }
  };

  return createPortal(
    <div className="sheetscrim" role="dialog" aria-modal="true" aria-label="Link to a document">
      <div className="sheetcard" onClick={(e) => e.stopPropagation()}>
        <h4>Link to a document</h4>

        <label className="field">
          <span className="fieldlabel">Web address</span>
          <input
            type="url"
            value={url}
            autoFocus
            enterKeyHint="done"
            placeholder="bosch-home.com/manuals/SHXM4AY55N"
            onChange={(e) => setUrl(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && !busy && void save()}
          />
        </label>

        <label className="field">
          <span className="fieldlabel">What is it</span>
          <select value={kind} onChange={(e) => setKind(e.target.value as DocKind)}>
            {DOC_KIND_ORDER.map((k) => (
              <option key={k} value={k}>
                {DOC_KIND_LABEL[k]}
              </option>
            ))}
          </select>
        </label>

        <p className="hint">
          A link stays current but breaks when the site changes. For anything a claim depends on,
          attach the file instead.
        </p>

        {error && <div className="notice bad">{error}</div>}

        <button type="button" className="btn wide" disabled={busy} onClick={() => void save()}>
          {busy ? 'Saving…' : 'Save the link'}
        </button>
        <button type="button" className="btn ghost" disabled={busy} onClick={onCancel}>
          Cancel
        </button>
      </div>
    </div>,
    document.body,
  );
}
