import { useState } from 'react';
import { createPortal } from 'react-dom';
import { db, nowISO } from '@/db/db';
import { feedback } from '@/lib/feedback';
import { cleanName, greeting, MAX_NAME_LENGTH } from '@/lib/greeting';
import { remindLater } from '@/lib/tour';
import { Scout } from './Scout';

/**
 * First run: one question, and one offer.
 *
 * It asks for a name and whether you want the tour. Everything else the app
 * can find out later or guess, and a first-run flow wanting four answers
 * before showing you anything is why people abandon apps on screen one.
 *
 * Centred, and sized by its content. It used to be a bottom sheet at a fixed
 * 72vh, inherited from the lock screen — on a short phone the content was
 * taller than the sheet, and a centred flex column that overflows clips from
 * the *top*, which put Scout off the screen entirely. Nothing here has a fixed
 * height any more; it grows to fit and scrolls if it must.
 */
export function Welcome({ onTour }: { onTour: () => void }) {
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);

  // No onDone: the shell renders this off a live query of the same record, so
  // writing onboardedAt is what closes it. One source of truth for "have we
  // asked", rather than a flag here that could disagree with the database.
  const finish = async (tour: boolean) => {
    setBusy(true);
    feedback(name ? 'save' : 'tap');
    await db.settings.update('singleton', {
      displayName: cleanName(name),
      onboardedAt: nowISO(),
      // Declining now is "later", not "never" — a specific date, three days
      // out, rather than a promise the app has no intention of keeping.
      tourRemindAt: tour ? undefined : remindLater(),
    });
    if (tour) onTour();
  };

  const preview = cleanName(name);

  return createPortal(
    <div className="fullscrim centred" role="dialog" aria-modal="true" aria-labelledby="welcome-title">
      <div className="welcomecard">
        <Scout pose="waving" height={132} motion={['float', 'breathe']} shadow alt="Scout waving" />

        <h2 id="welcome-title">Hello, I'm Scout</h2>
        {/* Not "your warranties" any more — the app watches documents and
            subscriptions too, and the first sentence anyone reads should not
            describe a third of it. */}
        <p>I'll keep an eye on the dates you'd rather not miss. What should I call you?</p>

        <form
          className="welcomeform"
          onSubmit={(e) => {
            e.preventDefault();
            if (!busy) void finish(true);
          }}
        >
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value.slice(0, MAX_NAME_LENGTH))}
            placeholder="Your name"
            aria-label="Your name"
            autoComplete="given-name"
            enterKeyHint="done"
          />

          {/* The greeting itself, as you type. It's the only place the name is
              ever used, so showing it is a more honest explanation than a
              sentence about what the field is for. */}
          <p className="welcomepreview">{greeting(preview)}</p>

          <button type="submit" className="btn wide tallbtn" disabled={busy}>
            Take the tour
          </button>
        </form>

        <button
          type="button"
          className="linkish"
          disabled={busy}
          onClick={() => void finish(false)}
        >
          Remind me later
        </button>
      </div>
    </div>,
    document.body,
  );
}
