import type { ReactNode } from 'react';
import { iconKeyFor, type IconKey, type IconSubject } from '@/lib/itemIcon';

/**
 * The monochrome icon set. One 24×24 line glyph per IconKey, all drawn in
 * `currentColor` at 1.6 stroke so they sit at the same weight as the nav.
 */
const PATHS: Record<IconKey, ReactNode> = {
  fridge: (
    <>
      <rect x="5" y="2.5" width="14" height="19" rx="2.5" />
      <path d="M5 10h14M8.6 5.8v2.2M8.6 12.4v2.6" />
    </>
  ),
  dishwasher: (
    <>
      <rect x="4" y="2.5" width="16" height="19" rx="2.5" />
      <path d="M4 7h16" />
      <circle cx="12" cy="14" r="4" />
    </>
  ),
  washer: (
    <>
      <rect x="4" y="2.5" width="16" height="19" rx="2.5" />
      <circle cx="12" cy="14" r="4.4" />
      <path d="M9.4 13.4a3 3 0 015.2 1.2" />
      <path d="M7.5 5.6h.01M10.5 5.6h.01" />
    </>
  ),
  dryer: (
    <>
      <rect x="4" y="2.5" width="16" height="19" rx="2.5" />
      <circle cx="12" cy="14" r="4.4" />
      <path d="M12 11.5v5M9.6 14h4.8" />
      <path d="M7.5 5.6h.01" />
    </>
  ),
  oven: (
    <>
      <rect x="3.5" y="3" width="17" height="18" rx="2.5" />
      <path d="M3.5 9h17" />
      <circle cx="7" cy="6" r="1" />
      <circle cx="10.5" cy="6" r="1" />
      <rect x="7" y="12" width="10" height="6" rx="1.5" />
    </>
  ),
  microwave: (
    <>
      <rect x="2.5" y="5" width="19" height="14" rx="2.5" />
      <rect x="5" y="8" width="10" height="8" rx="1.5" />
      <path d="M18 9v0M18 12v0M18 15v0" />
    </>
  ),
  kettle: (
    <>
      <path d="M7 9h10l1.4 10.2a1.6 1.6 0 01-1.6 1.8H7.2a1.6 1.6 0 01-1.6-1.8z" />
      <path d="M17 11l3-2.5M9 9V6.5A1.5 1.5 0 0110.5 5h3A1.5 1.5 0 0115 6.5V9" />
    </>
  ),
  coffee: (
    <>
      <path d="M4 8h13v6a5 5 0 01-5 5H9a5 5 0 01-5-5z" />
      <path d="M17 10h1.8a2.2 2.2 0 010 4.4H17" />
      <path d="M8 5V3M12 5V3" />
    </>
  ),
  tv: (
    <>
      <rect x="2.5" y="4" width="19" height="13" rx="2" />
      <path d="M9 21h6M12 17v4" />
    </>
  ),
  laptop: (
    <>
      <rect x="4" y="4.5" width="16" height="11" rx="2" />
      <path d="M2 19h20" />
    </>
  ),
  phone: (
    <>
      <rect x="6.5" y="2.5" width="11" height="19" rx="2.5" />
      <path d="M10.5 5.5h3M11 18.5h2" />
    </>
  ),
  speaker: (
    <>
      <rect x="6" y="2.5" width="12" height="19" rx="2.5" />
      <circle cx="12" cy="15" r="3.4" />
      <circle cx="12" cy="7" r="1.4" />
    </>
  ),
  camera: (
    <>
      <path d="M3 8.5A1.5 1.5 0 014.5 7h2.2l1.2-2h8.2l1.2 2h2.2A1.5 1.5 0 0121 8.5v9A1.5 1.5 0 0119.5 19h-15A1.5 1.5 0 013 17.5z" />
      <circle cx="12" cy="13" r="3.6" />
    </>
  ),
  router: (
    <>
      <rect x="3" y="13" width="18" height="7" rx="2" />
      <path d="M7 16.5h.01M10.5 16.5h.01" />
      <path d="M8.5 8.5a5 5 0 017 0M5.8 5.6a9 9 0 0112.4 0" />
    </>
  ),
  console: (
    <>
      <path d="M7.5 8h9a5 5 0 014.9 6l-.7 3.6A2.4 2.4 0 0118 19c-1.4 0-2-1-3-2h-6c-1 1-1.6 2-3 2a2.4 2.4 0 01-2.7-1.4L2.6 14A5 5 0 017.5 8z" />
      <path d="M7 12.2v2.2M5.9 13.3h2.2M15.5 12.6h.01M17.6 14.2h.01" />
    </>
  ),
  printer: (
    <>
      <path d="M7 8V3.5h10V8" />
      <rect x="3" y="8" width="18" height="8" rx="2" />
      <path d="M7 13h10v7.5H7z" />
    </>
  ),
  saw: (
    <>
      <path d="M3 15l9-9 3.5 3.5-9 9H3z" />
      <path d="M14.5 5.5l4 4M16 18l5-5" />
      <path d="M5 13l1.6 1.6M7.4 10.6L9 12.2M9.8 8.2l1.6 1.6" />
    </>
  ),
  drill: (
    <>
      <path d="M4 7.5h9a2 2 0 012 2v3a2 2 0 01-2 2H4z" />
      <path d="M15 10.5h3.5L22 12l-3.5 1.5H15" />
      <path d="M7 14.5V19a1.5 1.5 0 003 0v-4.5" />
    </>
  ),
  hammer: (
    <>
      <path d="M12.5 7.5l-8 8a2.1 2.1 0 003 3l8-8" />
      <path d="M10.5 5.5l6 6 3-3-2-2 1-1-3-3-1 1-2-2z" />
    </>
  ),
  wrench: (
    <>
      <path d="M14.7 6.3a3.9 3.9 0 005.1 5.1l-8.2 8.2a2.4 2.4 0 01-3.4-3.4z" />
      <path d="M14.7 6.3l2.6-2.6a5.6 5.6 0 00-6.1 7.4" />
    </>
  ),
  mower: (
    <>
      <path d="M3 17h11l1-5h5" />
      <circle cx="6" cy="18.5" r="2.5" />
      <circle cx="17.5" cy="17" r="2" />
      <path d="M14 12l3.5-7.5H21" />
    </>
  ),
  grill: (
    <>
      <path d="M3.5 6h17l-2 7.5a5 5 0 01-4.8 3.5h-3.4a5 5 0 01-4.8-3.5z" />
      <path d="M8.5 17L6.5 21M15.5 17l2 4" />
      <path d="M8 9.5h8" />
    </>
  ),
  bike: (
    <>
      <circle cx="5.8" cy="16.5" r="3.6" />
      <circle cx="18.2" cy="16.5" r="3.6" />
      <path d="M5.8 16.5l4-8.5h5l3.4 8.5M9 8h5M12.5 8l2.5 8.5" />
    </>
  ),
  car: (
    <>
      <path d="M3 15.5v-2l1.8-4.6A2 2 0 016.7 7.5h10.6a2 2 0 011.9 1.4L21 13.5v2" />
      <path d="M3 15.5h18v3H3z" />
      <path d="M6.5 18.5v1.6M17.5 18.5v1.6" />
    </>
  ),
  sofa: (
    <>
      <path d="M4 11V7.5A2.5 2.5 0 016.5 5h11A2.5 2.5 0 0120 7.5V11" />
      <path d="M3 11.5a2 2 0 012 2V16h14v-2.5a2 2 0 112 0V19H3z" />
    </>
  ),
  bed: (
    <>
      <path d="M3 19v-9M3 13.5h18V19M21 19v-4" />
      <path d="M6.5 13.5v-3h11v3" />
      <circle cx="8" cy="9.5" r="1.6" />
    </>
  ),
  chair: (
    <>
      <path d="M6.5 3.5h11l-1 10h-9z" />
      <path d="M5.5 13.5h13M8 13.5V20M16 13.5V20" />
    </>
  ),
  table: (
    <>
      <rect x="3" y="4.5" width="18" height="12" rx="2" />
      <path d="M3 9h18M9 16.5V20M15 16.5V20" />
    </>
  ),
  lamp: (
    <>
      <path d="M8 3.5h8l3 7H5z" />
      <path d="M12 10.5V19M8.5 20.5h7" />
    </>
  ),
  boiler: (
    <>
      <rect x="5" y="2.5" width="14" height="14" rx="2.5" />
      <circle cx="12" cy="9.5" r="3" />
      <path d="M9 16.5V21M15 16.5V21" />
    </>
  ),
  aircon: (
    <>
      <rect x="2.5" y="5" width="19" height="7" rx="2.5" />
      <path d="M6 8.5h12" />
      <path d="M7 15.5c1.6 0 1.6 2 3.2 2M13.8 15.5c1.6 0 1.6 2 3.2 2M7 19c1.6 0 1.6 2 3.2 2M13.8 19c1.6 0 1.6 2 3.2 2" />
    </>
  ),
  vacuum: (
    <>
      <circle cx="13" cy="14.5" r="6.2" />
      <circle cx="13" cy="14.5" r="2.2" />
      <path d="M8 10L5.5 4.5H3" />
    </>
  ),
  watch: (
    <>
      <rect x="7" y="7" width="10" height="10" rx="3" />
      <path d="M9.5 7V3.5h5V7M9.5 17v3.5h5V17" />
      <path d="M12 10v2.2l1.6 1" />
    </>
  ),
  box: (
    <>
      <path d="M3.5 7.6L12 3.2l8.5 4.4v8.8L12 20.8l-8.5-4.4z" />
      <path d="M3.5 7.6L12 12l8.5-4.4M12 12v8.8" />
    </>
  ),
};

export function ItemIcon({ item, size = 22 }: { item: IconSubject; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {PATHS[iconKeyFor(item)]}
    </svg>
  );
}
