import { PURGE_AFTER_DAYS } from '@/db/repo';
import { ScoutDialog } from './ScoutDialog';

/**
 * Deleting an item.
 *
 * This used to be a block that appeared in the page underneath the delete
 * button — which sits at the very bottom of the item screen, so the question
 * opened below the fold. You tapped Delete, nothing visibly happened, and the
 * explanation of what you were agreeing to was off-screen. A confirmation you
 * have to go looking for is not a confirmation.
 *
 * The reassurance leads, because it is the true part: nothing goes anywhere
 * for thirty days. Both facts are worth stating plainly — people hesitate over
 * deleting when the free tier is full, which is exactly the moment the slot
 * coming back immediately is the thing they wanted to know.
 */
export function ConfirmDelete({
  name,
  onConfirm,
  onCancel,
}: {
  name: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <ScoutDialog
      pose="alert"
      height={190}
      title={`Delete ${name}?`}
      alt="Scout, ears up"
      onClose={onCancel}
    >
      {/* Naming the place, not just the policy. This said "it goes to the bin
          for 30 days" for months while there was no bin anywhere in the app —
          a promise nobody could check and nobody could use. */}
      <p>
        It waits {PURGE_AFTER_DAYS} days under <b>Recently deleted</b>, at the bottom of the Items
        list. The free-tier slot comes back straight away.
      </p>

      {/* The destructive option is the one that has to be chosen, never the
          one a thumb lands on by momentum — so it isn't the primary button,
          and every other way out of this dialog cancels. */}
      <div className="dlgactions">
        <button type="button" className="choice danger" onClick={onConfirm}>
          <b>Delete</b>
          <span>Recoverable for 30 days, then gone for good.</span>
        </button>
        <button type="button" className="btn ghost wide" onClick={onCancel}>
          Keep it
        </button>
      </div>
    </ScoutDialog>
  );
}
