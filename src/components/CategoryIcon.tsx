import type { ReactNode } from 'react';
import type { ItemCategory } from '@/db/types';

/**
 * Monochrome line icons, one per category. Used as the thumbnail fallback when
 * an item has no photo. All draw in `currentColor` at a 1.6 stroke so they sit
 * at the same visual weight as the nav icons.
 */

const PATHS: Record<ItemCategory, ReactNode> = {
  appliance: (
    <>
      <rect x="5" y="2.5" width="14" height="19" rx="2.5" />
      <path d="M5 10h14" />
      <path d="M8.6 5.8v2.2M8.6 12.4v2.6" />
    </>
  ),
  electronics: (
    <>
      <rect x="2.5" y="4" width="19" height="13" rx="2" />
      <path d="M9 21h6M12 17v4" />
    </>
  ),
  tools: (
    <>
      <path d="M14.7 6.3a3.9 3.9 0 005.1 5.1l-8.2 8.2a2.4 2.4 0 01-3.4-3.4z" />
      <path d="M14.7 6.3l2.6-2.6a5.6 5.6 0 00-6.1 7.4" />
    </>
  ),
  furniture: (
    <>
      <path d="M4 11V7.5A2.5 2.5 0 016.5 5h11A2.5 2.5 0 0120 7.5V11" />
      <path d="M3 11.5a2 2 0 012 2V16h14v-2.5a2 2 0 112 0V19H3z" />
    </>
  ),
  hvac: (
    <>
      <rect x="2.5" y="4" width="19" height="16" rx="2.5" />
      <path d="M6 9h5M6 12.5h9M6 16h4" />
      <path d="M17.5 9.5v0M18.5 13.5v0" />
    </>
  ),
  outdoor: (
    <>
      <path d="M12 2.5l4.8 7h-2.6l3.4 5.2H6.4l3.4-5.2H7.2z" />
      <path d="M12 14.7V21.5" />
    </>
  ),
  vehicle: (
    <>
      <path d="M3 15.5v-2l1.8-4.6A2 2 0 016.7 7.5h10.6a2 2 0 011.9 1.4L21 13.5v2" />
      <path d="M3 15.5h18v3H3z" />
      <path d="M6.5 18.5v1.6M17.5 18.5v1.6" />
    </>
  ),
  other: (
    <>
      <path d="M3.5 7.6L12 3.2l8.5 4.4v8.8L12 20.8l-8.5-4.4z" />
      <path d="M3.5 7.6L12 12l8.5-4.4M12 12v8.8" />
    </>
  ),
};

export function CategoryIcon({
  category,
  size = 22,
}: {
  category?: ItemCategory;
  size?: number;
}) {
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
      {PATHS[category ?? 'other']}
    </svg>
  );
}
