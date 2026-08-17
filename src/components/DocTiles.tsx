import { useRef } from 'react';
import type { DocKind } from '@/db/types';
import { DOC_ACCEPT, DOC_KIND_LABEL } from '@/lib/docs';

/**
 * Attaching paperwork, in one tap per document.
 *
 * The kind *is* the button: tapping Receipt opens the picker already knowing
 * what it's collecting, and the file's own name becomes the title. Nothing is
 * asked that the tap and the file don't already answer.
 *
 * This started life inside the add form. The item page had its own sheet that
 * asked for the kind, then the source, then a title, then Attach — four
 * decisions to file a photo of a receipt, two of which the user had already
 * made by pressing "Add receipt" to get there. Same job, so now the same
 * control, and the difference between the two screens is only what happens to
 * the file afterwards: staged before the item exists, written straight away
 * once it does.
 *
 * Each tile is a split control: the label picks a file, the camera corner
 * shoots one. An earlier version relied on the file picker offering Take Photo
 * itself — it does on some devices and goes straight to the photo library on
 * others, which loses the camera entirely. `capture` is the only guarantee.
 */

/*
 * All five, always. Two of them used to hide behind a "Something else" link,
 * on the theory that receipts, warranties and manuals are what people attach
 * and the rest is clutter. In a card narrow enough to matter that link was
 * being clipped, and the fix is not a shorter label: a row of five tiles is
 * one glance, and a row of three plus a disclosure is two.
 */
export const DOC_KIND_ORDER: DocKind[] = ['receipt', 'warranty', 'manual', 'photo', 'other'];

export function DocTiles({
  onFiles,
  onLink,
  raised,
}: {
  onFiles: (kind: DocKind, files: File[]) => void;
  /**
   * Linking to something on the web. A sixth tile rather than a text link
   * underneath, because it is the same decision as the other five — what kind
   * of thing is this — and the only difference is where the bytes come from.
   * As a link it read as an afterthought, which is roughly how often it was
   * used.
   */
  onLink?: () => void;
  /** For screens where the tiles sit on the page rather than inside a card —
      the default fill is the page's own colour and would vanish. */
  raised?: boolean;
}) {
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
    onFiles(pending.current, [...files]);
  };

  return (
    <>
      {/* Three across, so six fall into two even rows. Five in a row of five
          was legible but the labels were down to nine pixels. */}
      <div className={`doctiles${raised ? ' raised' : ''}`}>
        {DOC_KIND_ORDER.map((k) => (
          <Tile key={k} kind={k} onOpen={open} />
        ))}
        {onLink && (
          <div className="doctile">
            <button type="button" className="doctile-main" onClick={onLink}>
              <LinkGlyph />
              On the web
            </button>
          </div>
        )}
      </div>

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
    </>
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

/** The odd one out: not a file, so not a DocKind glyph. */
function LinkGlyph() {
  return (
    <svg
      width="22"
      height="22"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M10 13.5a3.5 3.5 0 005 0l3-3a3.5 3.5 0 00-5-5l-1 1" />
      <path d="M14 10.5a3.5 3.5 0 00-5 0l-3 3a3.5 3.5 0 005 5l1-1" />
    </svg>
  );
}

const GLYPH: Record<DocKind, string> = {
  receipt: 'M6 3.5h12v17l-2-1.4-2 1.4-2-1.4-2 1.4-2-1.4-2 1.4z M9 8h6M9 11.5h6',
  warranty: 'M12 3l7 3v5.5c0 4.2-2.9 7.9-7 9-4.1-1.1-7-4.8-7-9V6z M9 12l2 2 4-4',
  manual: 'M4 4.5h6a2 2 0 012 2v13a2 2 0 00-2-2H4z M20 4.5h-6a2 2 0 00-2 2v13a2 2 0 012-2h6z',
  photo: 'M3 5.5h18v13H3z M8 11a2 2 0 100-4 2 2 0 000 4z M4 17l5-4.5 4 3.5 3-2.5 4 3.5',
  other: 'M14 3v5h5M14 3H6.5A1.5 1.5 0 005 4.5v15A1.5 1.5 0 006.5 21h11a1.5 1.5 0 001.5-1.5V8z',
};

export function DocGlyph({ kind, small }: { kind: DocKind; small?: boolean }) {
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
