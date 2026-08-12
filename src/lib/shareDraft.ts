/**
 * Turning a shared email into a half-filled item form.
 *
 * The seam between "Android handed us a blob and some text" and "the add form
 * opens with the shop, the date and the price already in it". Kept apart from
 * both so the mapping can be tested without a service worker or a DOM.
 *
 * Nothing here is authoritative. Every field it fills is one the user is
 * looking at, on a form they have to press Save on — which is the licence to
 * guess at all. It stops short of guessing a warranty length, because that
 * one isn't visible in the result: a wrong 12 months looks exactly like a
 * right 12 months until the day someone needs to claim.
 */

import type { AddItemForm } from './addItem';
import { stageDoc, type StagedDoc } from './docs';
import { formatMoneyInput } from './format';
import { guessDocKind, readReceipt, type SharedText } from './receipt';

export interface SharedInput extends SharedText {
  files: File[];
}

export interface ShareDraft {
  prefill: Partial<AddItemForm>;
  staged: StagedDoc[];
  /** What we did, in one line, so the guesses are visibly guesses. */
  banner: string;
  /** Rejected files, and why. */
  skipped: string[];
}

export function shareToDraft(shared: SharedInput, currency: string): ShareDraft {
  const guess = readReceipt(shared);
  const staged: StagedDoc[] = [];
  const skipped: string[] = [];

  const multi = shared.files.length > 1;
  shared.files.forEach((file, i) => {
    try {
      staged.push(
        stageDoc(guessDocKind(file.name, shared), file, multi ? `Page ${i + 1}` : undefined),
      );
    } catch (e) {
      skipped.push(`${file.name}: ${(e as Error).message}`);
    }
  });

  const prefill: Partial<AddItemForm> = {};

  // The merchant is the shop, not the thing. It goes in Retailer, and the name
  // field is left for the user — "Amazon" is not what anyone calls their
  // dishwasher, and an item named after the shop is worse than an unnamed one
  // because it looks finished.
  if (guess.merchant) prefill.retailer = guess.merchant;
  if (guess.purchaseDate) prefill.purchaseDate = guess.purchaseDate;

  if (guess.totalCents != null) {
    const cur = guess.currency ?? currency;
    prefill.currency = cur;
    prefill.price = formatMoneyInput((guess.totalCents / 100).toFixed(2), cur);
  }

  // The order number is the one thing a shop will ask for on the phone, and
  // there's no field for it — notes is where it can still be searched.
  const notes = [
    guess.orderNumber && `Order ${guess.orderNumber}`,
    shared.title?.trim(),
    shared.url?.trim(),
  ].filter(Boolean);
  if (notes.length) prefill.notes = notes.join('\n');

  return { prefill, staged, banner: describe(staged.length, guess.merchant), skipped };
}

function describe(docs: number, merchant: string | undefined): string {
  const what = docs === 0 ? 'Shared text' : docs === 1 ? '1 document' : `${docs} documents`;
  const from = merchant ? ` from ${merchant}` : '';
  return `${what}${from}. Check what's filled in — some of it is guessed.`;
}
