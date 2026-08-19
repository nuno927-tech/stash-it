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

import type { Doc, Item, Paper, Room, Subscription } from '@/db/types';
import { KIND_LABEL } from './papers';
import { coveragesOf } from './warranty';

export type MatchField =
  | 'name'
  | 'brand'
  | 'model'
  | 'serial'
  | 'retailer'
  | 'room'
  | 'notes'
  | 'warranty'
  | 'document'
  /* Documents. "Whose" is the one people actually search — a household with
     four passports is four rows with the same label. */
  | 'holder'
  | 'kind'
  | 'issuer'
  | 'stored';

/** Field weights. Name dominates; notes are a last resort. */
const WEIGHT: Record<MatchField, number> = {
  name: 40,
  serial: 35,
  holder: 32,
  model: 30,
  brand: 28,
  kind: 26,
  document: 22,
  retailer: 20,
  issuer: 19,
  room: 18,
  stored: 16,
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
  holder: 'who it belongs to',
  kind: 'what kind it is',
  issuer: 'who issued it',
  stored: 'where it is kept',
};

/**
 * One result, whatever kind of thing it is.
 *
 * ── Why one list rather than three ────────────────────────────────────────
 * The search field lives on the Items tab and only ever looked at items, which
 * was correct when items were all there was. It stopped being correct the day
 * the app grew documents and subscriptions: typing "passport" into the one
 * search box in the app returned nothing, which does not read as "wrong tab",
 * it reads as "the app has lost my passport".
 *
 * Ranked together rather than grouped by kind, for the same reason the
 * dashboard timeline is one list: someone searching "golf" wants the closest
 * match to the word, and does not know or care which table it came from.
 */
export type Found =
  | { kind: 'item'; item: Item }
  | { kind: 'paper'; paper: Paper }
  | { kind: 'subscription'; sub: Subscription };

export type SearchHit = Found & {
  score: number;
  /** Which fields earned the match, best first. Drives the "why" line. */
  fields: MatchField[];
  /** The display name, so ties break alphabetically without a switch. */
  title: string;
};

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

  // Every policy, not just the first two fields: "sinuous spring" is a
  // perfectly reasonable thing to search a couch for, and it only exists on
  // the coverage that says so.
  const w = coveragesOf(item)
    .flatMap((c) => [c.label, c.covers, c.provider, c.policyNumber])
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

/** A document's searchable text. No numbers, because there are none to hold. */
function paperHay(paper: Paper): Haystack[] {
  const out: Haystack[] = [{ field: 'name', text: paper.label }];
  if (paper.holder) out.push({ field: 'holder', text: paper.holder });
  // The kind, in the words the app shows: "Driving licence" should answer to
  // "licence" even when the row is called "Mine".
  out.push({ field: 'kind', text: KIND_LABEL[paper.kind] ?? paper.kind });
  if (paper.authority) out.push({ field: 'issuer', text: paper.authority });
  if (paper.storedAt) out.push({ field: 'stored', text: paper.storedAt });
  if (paper.notes) out.push({ field: 'notes', text: paper.notes });
  return out;
}

function subHay(sub: Subscription): Haystack[] {
  const out: Haystack[] = [{ field: 'name', text: sub.name }];
  if (sub.notes) out.push({ field: 'notes', text: sub.notes });
  return out;
}

/** Every term has to land somewhere, and the best landing counts. */
function rank(words: string[], hay: Haystack[]): { score: number; fields: MatchField[] } | null {
  let total = 0;
  const fields: { field: MatchField; score: number }[] = [];

  for (const word of words) {
    const best = scoreTerm(word, hay);
    if (!best) return null;
    total += best.score;
    fields.push(best);
  }

  return {
    score: total,
    fields: [...new Set(fields.sort((a, b) => b.score - a.score).map((f) => f.field))],
  };
}

export interface SearchInput {
  items: Item[];
  docs: Doc[];
  rooms: Room[];
  papers?: Paper[];
  subs?: Subscription[];
}

export function searchAll(
  query: string,
  { items, docs, rooms, papers = [], subs = [] }: SearchInput,
): SearchHit[] {
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
    const got = rank(
      words,
      haystacks(
        item,
        item.roomId ? roomById.get(item.roomId) : undefined,
        titlesByItem.get(item.id) ?? [],
      ),
    );
    if (got) hits.push({ kind: 'item', item, title: item.name, ...got });
  }

  for (const paper of papers) {
    if (paper.deletedAt) continue;
    const got = rank(words, paperHay(paper));
    if (got) hits.push({ kind: 'paper', paper, title: paper.label, ...got });
  }

  for (const sub of subs) {
    if (sub.deletedAt) continue;
    const got = rank(words, subHay(sub));
    if (got) hits.push({ kind: 'subscription', sub, title: sub.name, ...got });
  }

  // Ties break alphabetically so the order never jitters between keystrokes.
  return hits.sort((a, b) => b.score - a.score || a.title.localeCompare(b.title));
}

/**
 * "Matched on serial number and notes" — omitted entirely when the only match
 * was the name, since that's self-evident from the row itself.
 */
export function matchSummary(hit: Pick<SearchHit, 'fields'>): string | null {
  const other = hit.fields.filter((f) => f !== 'name');
  if (other.length === 0) return null;
  const labels = other.slice(0, 2).map((f) => FIELD_LABEL[f]);
  return `Matched on ${labels.join(' and ')}`;
}
