/**
 * Search across the stash. Pure functions over arrays the caller has already
 * loaded — no queries in here, so it's fully testable and cheap to re-run on
 * every keystroke.
 *
 * Design notes:
 *
 *  - Substring matching, not prefix. Someone hunting a serial types the four
 *    characters they can read off the plate, and those are rarely the first
 *    four.
 *  - Serials are compared with punctuation stripped, so "shxm-4ay55n" finds
 *    SHXM4AY55N.
 *  - Accents are folded, so "Bosch Séries" answers to "series".
 *  - Multiple words are AND, each free to match a different field: "bosch
 *    kitchen" finds the Bosch in the kitchen.
 */

import type { Doc, Item, Room } from '@/db/types';

export type MatchField =
  | 'name'
  | 'brand'
  | 'model'
  | 'serial'
  | 'retailer'
  | 'room'
  | 'notes'
  | 'warranty'
  | 'document';

/** Field weights. Name dominates; notes are a last resort. */
const WEIGHT: Record<MatchField, number> = {
  name: 40,
  serial: 35,
  model: 30,
  brand: 28,
  document: 22,
  retailer: 20,
  room: 18,
  warranty: 15,
  notes: 10,
};

const FIELD_LABEL: Record<MatchField, string> = {
  name: 'name',
  brand: 'brand',
  model: 'model',
  serial: 'serial number',
  retailer: 'retailer',
  room: 'room',
  notes: 'notes',
  warranty: 'warranty details',
  document: 'a document',
};

export interface SearchHit {
  item: Item;
  score: number;
  /** Which fields earned the match, best first. Drives the "why" line. */
  fields: MatchField[];
}

export function normalize(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '') // strip combining marks: "Séries" → "series"
    .toLowerCase()
    .trim();
}

/** For serials and models, where punctuation is noise. */
function alnum(s: string): string {
  return normalize(s).replace(/[^a-z0-9]/g, '');
}

export function terms(query: string): string[] {
  return normalize(query).split(/\s+/).filter(Boolean);
}

interface Haystack {
  field: MatchField;
  text: string;
  /** Also compared with punctuation removed. */
  loose?: boolean;
}

function haystacks(
  item: Item,
  roomName: string | undefined,
  docTitles: string[],
): Haystack[] {
  const out: Haystack[] = [{ field: 'name', text: item.name }];
  if (item.brand) out.push({ field: 'brand', text: item.brand });
  if (item.model) out.push({ field: 'model', text: item.model, loose: true });
  if (item.serial) out.push({ field: 'serial', text: item.serial, loose: true });
  if (item.retailer) out.push({ field: 'retailer', text: item.retailer });
  if (roomName) out.push({ field: 'room', text: roomName });
  if (item.notes) out.push({ field: 'notes', text: item.notes });

  const w = [item.warranty, item.extendedWarranty]
    .flatMap((x) => [x?.provider, x?.policyNumber])
    .filter(Boolean)
    .join(' ');
  if (w) out.push({ field: 'warranty', text: w, loose: true });

  for (const t of docTitles) out.push({ field: 'document', text: t });

  return out;
}

/** Best score a single term can earn against one item, plus the field. */
function scoreTerm(term: string, hay: Haystack[]): { score: number; field: MatchField } | null {
  let best: { score: number; field: MatchField } | null = null;
  const loose = alnum(term);

  for (const h of hay) {
    const text = normalize(h.text);
    let hit = 0;

    if (text === term) hit = WEIGHT[h.field] * 2.5;
    else if (text.startsWith(term)) hit = WEIGHT[h.field] * 1.6;
    else if (new RegExp(`\\b${escapeRegex(term)}`).test(text)) hit = WEIGHT[h.field] * 1.3;
    else if (text.includes(term)) hit = WEIGHT[h.field];
    // Punctuation-stripped comparison, but only for terms long enough to mean
    // something: stripping "a.*" down to "a" would otherwise match half the
    // model numbers in the database.
    else if (h.loose && loose.length >= 3 && alnum(h.text).includes(loose)) {
      hit = WEIGHT[h.field] * 0.9;
    }

    if (hit > 0 && (!best || hit > best.score)) best = { score: hit, field: h.field };
  }

  return best;
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export interface SearchInput {
  items: Item[];
  docs: Doc[];
  rooms: Room[];
}

export function searchItems(query: string, { items, docs, rooms }: SearchInput): SearchHit[] {
  const words = terms(query);
  if (words.length === 0) return [];

  const roomById = new Map(rooms.map((r) => [r.id, r.name]));
  const titlesByItem = new Map<string, string[]>();
  for (const d of docs) {
    if (d.deletedAt || !d.title) continue;
    const list = titlesByItem.get(d.itemId) ?? [];
    list.push(d.title);
    titlesByItem.set(d.itemId, list);
  }

  const hits: SearchHit[] = [];

  for (const item of items) {
    if (item.deletedAt) continue;
    const hay = haystacks(
      item,
      item.roomId ? roomById.get(item.roomId) : undefined,
      titlesByItem.get(item.id) ?? [],
    );

    let total = 0;
    const fields: { field: MatchField; score: number }[] = [];
    let matchedEvery = true;

    for (const word of words) {
      const best = scoreTerm(word, hay);
      if (!best) {
        matchedEvery = false;
        break;
      }
      total += best.score;
      fields.push(best);
    }

    if (!matchedEvery) continue;

    const ordered = [...new Set(fields.sort((a, b) => b.score - a.score).map((f) => f.field))];
    hits.push({ item, score: total, fields: ordered });
  }

  // Ties break alphabetically so the order never jitters between keystrokes.
  return hits.sort((a, b) => b.score - a.score || a.item.name.localeCompare(b.item.name));
}

/**
 * "Matched on serial number and notes" — omitted entirely when the only match
 * was the name, since that's self-evident from the row itself.
 */
export function matchSummary(hit: SearchHit): string | null {
  const other = hit.fields.filter((f) => f !== 'name');
  if (other.length === 0) return null;
  const labels = other.slice(0, 2).map((f) => FIELD_LABEL[f]);
  return `Matched on ${labels.join(' and ')}`;
}
