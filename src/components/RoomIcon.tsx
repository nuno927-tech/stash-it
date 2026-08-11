import type { ReactNode } from 'react';

/**
 * A glyph for a room, matched on its name.
 *
 * Keyword-matched rather than stored, for the same reason item icons are:
 * rooms are user-editable and user-invented, so anything that depends on a
 * fixed list breaks the moment someone adds "Nursery" or renames Garage to
 * "The Shed". Longest phrase wins, so "Living Room" beats "Room".
 */

export type RoomIconKey =
  | 'kitchen'
  | 'living'
  | 'family'
  | 'dining'
  | 'bedroom'
  | 'nursery'
  | 'bathroom'
  | 'laundry'
  | 'garage'
  | 'basement'
  | 'attic'
  | 'office'
  | 'workshop'
  | 'outdoor'
  | 'storage'
  | 'gym'
  | 'pantry'
  | 'hall'
  | 'room';

const KEYWORDS: Record<RoomIconKey, string[]> = {
  kitchen: ['kitchen', 'kitchenette', 'scullery'],
  living: ['living room', 'living', 'lounge', 'sitting room', 'front room', 'parlour', 'parlor'],
  family: ['family room', 'family', 'den', 'rec room', 'games room', 'playroom', 'media room', 'tv room'],
  dining: ['dining room', 'dining', 'breakfast room'],
  bedroom: ['bedroom', 'primary bedroom', 'master', 'guest room', 'bed room'],
  nursery: ['nursery', 'baby', "kid's room", 'kids room'],
  bathroom: ['bathroom', 'bath', 'ensuite', 'en suite', 'shower room', 'washroom', 'toilet', 'powder room', 'wc'],
  laundry: ['laundry', 'utility', 'utility room', 'mud room', 'mudroom'],
  garage: ['garage', 'carport', 'car port'],
  basement: ['basement', 'cellar', 'crawl space'],
  attic: ['attic', 'loft', 'roof space'],
  office: ['office', 'study', 'library', 'workspace'],
  workshop: ['workshop', 'shed', 'shop', 'tool room'],
  outdoor: ['outdoor', 'garden', 'yard', 'patio', 'deck', 'porch', 'balcony', 'terrace', 'greenhouse'],
  storage: ['storage', 'closet', 'cupboard', 'wardrobe room', 'store room'],
  gym: ['gym', 'home gym', 'fitness'],
  pantry: ['pantry', 'larder'],
  hall: ['hall', 'hallway', 'entry', 'entryway', 'foyer', 'landing', 'stairs', 'corridor'],
  room: [],
};

const INDEX = Object.entries(KEYWORDS)
  .flatMap(([key, words]) => words.map((word) => ({ key: key as RoomIconKey, word })))
  .sort((a, b) => b.word.length - a.word.length);

export function roomIconKey(name: string): RoomIconKey {
  const text = name.toLowerCase().trim();
  for (const { key, word } of INDEX) {
    if (new RegExp(`(^|[^a-z0-9])${word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}($|[^a-z0-9])`, 'i').test(text)) {
      return key;
    }
  }
  return 'room';
}

const PATHS: Record<RoomIconKey, ReactNode> = {
  kitchen: (
    <>
      <rect x="3" y="3" width="8" height="18" rx="1.8" />
      <path d="M3 9h8M6.5 5.5v1.5" />
      <path d="M15 3v7a2 2 0 002 2h.5V21M18.5 3v6" />
    </>
  ),
  living: (
    <>
      <path d="M4 11V7.8A2.3 2.3 0 016.3 5.5h11.4A2.3 2.3 0 0120 7.8V11" />
      <path d="M3 11.5a2 2 0 012 2V16h14v-2.5a2 2 0 112 0V19H3z" />
    </>
  ),
  family: (
    <>
      <circle cx="8" cy="7" r="2.4" />
      <circle cx="16.2" cy="8.2" r="1.9" />
      <path d="M3.5 20v-2.4A3.6 3.6 0 017 14h2a3.6 3.6 0 013.5 3.6V20" />
      <path d="M14.5 20v-1.8a3 3 0 013-3h1a3 3 0 013 3V20" />
    </>
  ),
  dining: (
    <>
      <path d="M3 10.5h18M5 10.5V20M19 10.5V20" />
      <path d="M8 3v5M10.5 3v5M9.2 8v2.5" />
      <path d="M15.5 3c-1 0-1.6 1.2-1.6 2.6S14.5 8 15.5 8V3zM15.5 8v2.5" />
    </>
  ),
  bedroom: (
    <>
      <path d="M3 19v-9M3 13.5h18V19M21 19v-4.5" />
      <path d="M6.5 13.5v-2.8h11v2.8" />
      <circle cx="8.2" cy="9.6" r="1.5" />
    </>
  ),
  nursery: (
    <>
      <path d="M4 20v-7a8 8 0 0116 0v7" />
      <path d="M4 15.5h16M12 5V2.5" />
      <path d="M7.5 13v7M12 13v7M16.5 13v7" />
    </>
  ),
  bathroom: (
    <>
      <path d="M3 12.5h18v2a5 5 0 01-5 5H8a5 5 0 01-5-5z" />
      <path d="M6.5 12.5V5.2A1.7 1.7 0 018.2 3.5h.6a1.7 1.7 0 011.7 1.7" />
      <path d="M6 21l-1 1.5M18 21l1 1.5" />
    </>
  ),
  laundry: (
    <>
      <rect x="4" y="2.5" width="16" height="19" rx="2.5" />
      <circle cx="12" cy="14" r="4.4" />
      <path d="M9.4 13.4a3 3 0 015.2 1.2" />
      <path d="M7.5 5.6h.01M10.5 5.6h.01" />
    </>
  ),
  garage: (
    <>
      <path d="M3 21V9.5L12 4l9 5.5V21" />
      <path d="M6.5 21v-8h11v8M6.5 16.5h11" />
    </>
  ),
  basement: (
    <>
      <path d="M3 4h18M4.5 4v16h5v-4h5v4h5" />
      <path d="M9.5 20v-8h5v4" />
    </>
  ),
  attic: (
    <>
      <path d="M12 3L3 12h3v9h12v-9h3z" />
      <path d="M10 21v-5h4v5" />
    </>
  ),
  office: (
    <>
      <path d="M3 13.5h18M4.5 13.5V20M19.5 13.5V20" />
      <rect x="7" y="4" width="10" height="7" rx="1.5" />
      <path d="M10 13.5V16h4v-2.5" />
    </>
  ),
  workshop: (
    <>
      <path d="M14.7 6.3a3.9 3.9 0 005.1 5.1l-8.2 8.2a2.4 2.4 0 01-3.4-3.4z" />
      <path d="M14.7 6.3l2.6-2.6a5.6 5.6 0 00-6.1 7.4" />
    </>
  ),
  outdoor: (
    <>
      <path d="M12 2.5l4.8 7h-2.6l3.4 5.2H6.4l3.4-5.2H7.2z" />
      <path d="M12 14.7V21.5" />
    </>
  ),
  storage: (
    <>
      <path d="M3.5 7.6L12 3.2l8.5 4.4v8.8L12 20.8l-8.5-4.4z" />
      <path d="M3.5 7.6L12 12l8.5-4.4M12 12v8.8" />
    </>
  ),
  gym: (
    <>
      <path d="M4 9v6M7 6.5v11M17 6.5v11M20 9v6" />
      <path d="M7 12h10" />
    </>
  ),
  pantry: (
    <>
      <rect x="4.5" y="2.5" width="15" height="19" rx="2" />
      <path d="M4.5 9h15M4.5 15h15M12 2.5v19" />
    </>
  ),
  hall: (
    <>
      <path d="M4 3v18h9V3z" />
      <path d="M13 12h7M17 8.5l3.5 3.5L17 15.5" />
      <circle cx="10" cy="12.5" r="0.9" />
    </>
  ),
  room: (
    <>
      <path d="M3 21V9.5L12 3l9 6.5V21z" />
      <path d="M9.5 21v-6h5v6" />
    </>
  ),
};

export function RoomIcon({ name, size = 20 }: { name: string; size?: number }) {
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
      {PATHS[roomIconKey(name)]}
    </svg>
  );
}
