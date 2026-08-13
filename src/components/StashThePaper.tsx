import { Scout } from './Scout';

/**
 * The one part of the job the app cannot do for you.
 *
 * Everything else here is a copy: the photo, the dates, the export. The paper
 * original is the only artefact that exists once, and a phone in a puddle
 * doesn't take it with it. Retailers and manufacturers vary on whether a
 * photograph is enough — plenty accept one, some still want the physical
 * receipt, and you find out which on the day the thing breaks.
 *
 * So this shows after every save, not once. It was tempting to fire it three
 * times and stop, on the grounds that people learn — but the habit is per
 * receipt, not per person. Knowing you should file the paper is no use on the
 * eleventh purchase if the paper for it is in a carrier bag.
 *
 * Kept small and calm for exactly that reason: something you'll see hundreds of
 * times has to be furniture, not an interruption. No dismiss button, nothing to
 * tap, no block on getting on with it.
 */

/** One wording, used by the card, the tour and the site. */
export const STASH_THE_PAPER = {
  title: 'Now stash the paper',
  body: "Scout files every original. A photo settles most claims; some still want the real receipt. One folder, somewhere dry, and you've got both.",
} as const;

export function StashThePaper() {
  return (
    <aside className="papercard">
      <Scout pose="folder" height={92} motion={['breathe']} alt="Scout filing a receipt" />
      <div className="papertxt">
        <h4>{STASH_THE_PAPER.title}</h4>
        <p>{STASH_THE_PAPER.body}</p>
      </div>
    </aside>
  );
}
