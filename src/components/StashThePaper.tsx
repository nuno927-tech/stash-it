import { useEffect } from 'react';
import { feedback } from '@/lib/feedback';
import { ScoutDialog } from './ScoutDialog';

/**
 * The one part of the job the app cannot do for you.
 *
 * Everything else here is a copy: the photo, the dates, the export. The paper
 * original is the only artefact that exists once, and a phone in a puddle
 * doesn't take it with it. Retailers and manufacturers vary on whether a
 * photograph is enough — plenty accept one, some still want the physical
 * receipt, and you find out which on the day the thing breaks.
 *
 * Shown after every save, not once. It was tempting to fire it three times and
 * stop, on the grounds that people learn — but the habit is per receipt, not
 * per person. Knowing you should file the paper is no use on the eleventh
 * purchase if the paper for it is in a carrier bag.
 *
 * Which is also why it's this short. Something you'll read a few hundred times
 * gets one line, and the line is Scout's rather than the app's — a squirrel
 * admitting he'd lose it in the garden is easier to hear for the hundredth
 * time than a sentence about claim requirements.
 */

/** Scout's line. The tour and the site make the same point at more length. */
export const STASH_THE_PAPER = {
  title: 'Now stash the paper',
  body: "I've got the photo. You keep the original — one folder, somewhere dry. I'd bury it, but drawers are easier to find again.",
} as const;

export function StashThePaper({ onClose }: { onClose: () => void }) {
  useEffect(() => feedback('save'), []);

  return (
    <ScoutDialog
      pose="folder"
      height={210}
      title={STASH_THE_PAPER.title}
      alt="Scout filing a receipt"
      onClose={onClose}
    >
      <p>{STASH_THE_PAPER.body}</p>
      <button type="button" className="btn wide" onClick={onClose}>
        Will do
      </button>
    </ScoutDialog>
  );
}
