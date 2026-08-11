import { useRef, useState } from 'react';
import type { DocKind } from '@/db/types';
import {
  attachFile,
  attachLink,
  DOC_ACCEPT,
  DOC_KINDS,
  DocError,
  formatBytes,
  titleFromFilename,
} from '@/lib/docs';

type Source = 'file' | 'link';

/**
 * Attach sheet. Kind first, because it changes what the user goes looking for
 * — someone adding a warranty is reaching for a PDF, someone adding a photo is
 * reaching for the camera.
 */
export function AttachDoc({
  itemId,
  defaultKind = 'warranty',
  onDone,
  onCancel,
}: {
  itemId: string;
  defaultKind?: DocKind;
  onDone: () => void;
  onCancel: () => void;
}) {
  const [kind, setKind] = useState<DocKind>(defaultKind);
  const [source, setSource] = useState<Source>('file');
  const [file, setFile] = useState<File | null>(null);
  const [title, setTitle] = useState('');
  const [url, setUrl] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();

  const camera = useRef<HTMLInputElement>(null);
  const picker = useRef<HTMLInputElement>(null);

  const hint = DOC_KINDS.find((k) => k.kind === kind)?.hint;

  const take = (f: File | undefined) => {
    if (!f) return;
    setFile(f);
    setSource('file');
    if (!title) setTitle(titleFromFilename(f.name));
    setError(undefined);
  };

  const save = async () => {
    setBusy(true);
    setError(undefined);
    try {
      if (source === 'link') await attachLink(itemId, kind, url, title);
      else if (file) await attachFile(itemId, kind, file, title);
      else throw new DocError('Choose a file first.');
      onDone();
    } catch (e) {
      setError(e instanceof DocError ? e.message : `Could not attach: ${(e as Error).message}`);
      setBusy(false);
    }
  };

  return (
    <div className="sheet">
      <h4>Attach a document</h4>

      <div className="chiprow">
        {DOC_KINDS.map((k) => (
          <button
            key={k.kind}
            type="button"
            className={`pick${kind === k.kind ? ' on' : ''}`}
            onClick={() => setKind(k.kind)}
          >
            {k.label}
          </button>
        ))}
      </div>
      {hint && <p className="hint">{hint}</p>}

      <div className="seg">
        <button
          type="button"
          className={source === 'file' ? 'on' : ''}
          onClick={() => setSource('file')}
        >
          Upload a file
        </button>
        <button
          type="button"
          className={source === 'link' ? 'on' : ''}
          onClick={() => setSource('link')}
        >
          Link to it
        </button>
      </div>

      {source === 'file' ? (
        <>
          <div className="photoactions">
            <button
              type="button"
              className="minibtn"
              disabled={busy}
              onClick={() => picker.current?.click()}
            >
              Choose file
            </button>
            <button
              type="button"
              className="minibtn ghost"
              disabled={busy}
              onClick={() => camera.current?.click()}
            >
              Scan with camera
            </button>
          </div>

          {file && (
            <p className="hint">
              {file.name} · {formatBytes(file.size)}
            </p>
          )}

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
        </>
      ) : (
        <>
          <label className="field">
            <span className="fieldlabel">Web address</span>
            <input
              type="url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="bosch-home.com/manuals/SHXM4AY55N"
            />
          </label>
          <p className="hint">
            A link stays current but breaks when the site changes. For anything a claim depends on,
            upload the file.
          </p>
        </>
      )}

      <label className="field">
        <span className="fieldlabel">Title</span>
        <input
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Extended warranty policy"
        />
      </label>

      {error && <div className="notice bad">{error}</div>}

      <div className="photoactions">
        <button type="button" className="minibtn" disabled={busy} onClick={save}>
          {busy ? 'Attaching…' : 'Attach'}
        </button>
        <button type="button" className="minibtn ghost" disabled={busy} onClick={onCancel}>
          Cancel
        </button>
      </div>
    </div>
  );
}
