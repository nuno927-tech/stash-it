import type { PaperKind } from '@/db/types';
import type { PaperState } from '@/lib/papers';

/**
 * A mark for each kind of document, tinted by whether it needs anything.
 *
 * Line drawings rather than the emoji-adjacent glyphs a document list usually
 * gets. At 20px inside a 36px tile these have to survive the same test the nav
 * icons did — the stroke has to be thin enough relative to the picture that
 * the shape reads, which is why it's 1.7 and not 2.
 *
 * The colour is the state and only the state: nothing here is decorative, so a
 * green row means green news. Same three states as the rest of the app maps
 * onto moss, honey and ember.
 */
const GLYPH: Record<PaperKind, React.ReactNode> = {
  // A booklet, seen from the front, with the chip-and-crest band across it.
  passport: (
    <>
      <path d="M5 4.5h11a2 2 0 012 2v13a2 2 0 01-2 2H5z" />
      <path d="M8 4.5v17" />
      <circle cx="13" cy="11" r="2.4" />
      <path d="M10.6 15.6h4.8" />
    </>
  ),
  // A card with a portrait square and two lines of detail.
  id: (
    <>
      <rect x="2.8" y="5.5" width="18.4" height="13" rx="2" />
      <circle cx="8.4" cy="10.6" r="1.9" />
      <path d="M5.6 15.3c.5-1.3 1.6-2 2.8-2s2.3.7 2.8 2" />
      <path d="M14.4 10h4.2M14.4 13.4h4.2" />
    </>
  ),
  // The same card, landscape, with a steering wheel rather than a face.
  licence: (
    <>
      <rect x="2.8" y="5.5" width="18.4" height="13" rx="2" />
      <circle cx="8.4" cy="12" r="3" />
      <path d="M8.4 9v6M5.4 12h6" />
      <path d="M14.4 10h4.2M14.4 14h4.2" />
    </>
  ),
  // A page with a stamp on it — what a visa physically is.
  visa: (
    <>
      <path d="M5.5 3.5h9L19 8v12.5H5.5z" />
      <path d="M14.5 3.5V8H19" />
      <rect x="8" y="11" width="8" height="6" rx="1" transform="rotate(-7 12 14)" />
    </>
  ),
  // A car, from the side.
  vehicle: (
    <>
      <path d="M3.5 14.5h17M4.6 14.5l1.7-4.4A2 2 0 018.2 8.8h7.6a2 2 0 011.9 1.3l1.7 4.4" />
      <path d="M3.5 14.5v3.2h17v-3.2" />
      <circle cx="7.6" cy="17.7" r="1.6" />
      <circle cx="16.4" cy="17.7" r="1.6" />
    </>
  ),
  // A shield. The one glyph everybody already reads as "insurance".
  insurance: (
    <>
      <path d="M12 3.2l7 2.6v6c0 4.2-2.9 7.6-7 9-4.1-1.4-7-4.8-7-9v-6z" />
      <path d="M8.9 11.9l2.2 2.2 4-4.3" />
    </>
  ),
  // A certificate: a page with a rosette.
  certification: (
    <>
      <path d="M5 3.8h14v11.4H5z" />
      <path d="M7.8 7.4h8.4M7.8 10.6h5.6" />
      <circle cx="12" cy="17" r="2.6" />
      <path d="M10.2 19l-.7 2.6 2.5-1.2 2.5 1.2-.7-2.6" />
    </>
  ),
  // A card with a bar code — the gym, the library, the club.
  membership: (
    <>
      <rect x="2.8" y="6" width="18.4" height="12" rx="2" />
      <path d="M6.4 9.6v4.8M9 9.6v4.8M11.6 9.6v4.8M15 9.6v4.8M17.6 9.6v4.8" />
    </>
  ),
  // A door with a key beside it. A house says "property"; a key says the
  // property is not yours, which is what a lease is.
  lease: (
    <>
      <path d="M4.5 20.5V6.2l7.5-2.7v17" />
      <circle cx="9.6" cy="12.6" r="0.9" />
      <circle cx="17" cy="9.6" r="2.4" />
      <path d="M17 12v8.5M17 16.6h2.6M17 19h2.2" />
    </>
  ),
  // A paw. The one shape that says "pet" before any label is read.
  petlicence: (
    <>
      <ellipse cx="12" cy="16.2" rx="4.2" ry="3.2" />
      <circle cx="7.2" cy="10.6" r="1.7" />
      <circle cx="10.5" cy="8.6" r="1.8" />
      <circle cx="13.5" cy="8.6" r="1.8" />
      <circle cx="16.8" cy="10.6" r="1.7" />
    </>
  ),
  // A syringe. Read alone it could be anyone's jab; the label says whose.
  petvaccine: (
    <>
      <rect x="8.6" y="5.6" width="6.8" height="10.8" rx="1.2" />
      <path d="M12 5.6V2.9M9.8 2.9h4.4" />
      <path d="M12 16.4V21" />
      <path d="M9.4 8.6h2M9.4 11.4h2M9.4 14.2h2" />
    </>
  ),
  // A card with a ribbon and a bow — a gift card, at a glance.
  voucher: (
    <>
      <rect x="2.8" y="7" width="18.4" height="12" rx="2" />
      <path d="M12 7v12" />
      <circle cx="10.4" cy="5.4" r="1.5" />
      <circle cx="13.6" cy="5.4" r="1.5" />
    </>
  ),
  // A plain sheet with a folded corner.
  other: (
    <>
      <path d="M6 3.5h8L19 8.5v12H6z" />
      <path d="M14 3.5v5h5" />
      <path d="M9 12.5h7M9 16h5" />
    </>
  ),
};

const TONE: Record<PaperState, string> = {
  valid: 'ok',
  renew: 'warn',
  expired: 'dead',
};

export function PaperIcon({
  kind,
  state,
  size = 36,
}: {
  kind: PaperKind;
  state: PaperState;
  size?: number;
}) {
  return (
    <span className={`papermark ${TONE[state]}`} style={{ width: size, height: size }}>
      <svg
        width={Math.round(size * 0.58)}
        height={Math.round(size * 0.58)}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        {GLYPH[kind]}
      </svg>
    </span>
  );
}
