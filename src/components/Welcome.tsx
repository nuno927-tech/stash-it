import { useState } from 'react';
import { db } from '@/db/db';
import { feedback } from '@/lib/feedback';
import { cleanName, greeting, MAX_NAME_LENGTH } from '@/lib/greeting';
import { nowISO } from '@/db/db';
import { Scout } from './Scout';

/**
 * First run, and one question.
 *
 * It asks for a name and nothing else. Everything else the app needs it can
 * find out later or guess, and a first-run flow that wants four answers before
 * showing you anything is the reason people abandon apps on the first screen.
 *
 * Skipping is a real answer, recorded as one — `onboardedAt` is set either
 * way, so declining isn't mistaken for never having been asked and the sheet
 * doesn't come back tomorrow.
 */
export function Welcome() {
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);

  // No onDone: the shell renders this off a live query of the same record, so
  // writing onboardedAt is what closes it. One source of truth for "have we
  // asked", rather than a flag here that could disagree with the database.
  const finish = async (value: string) => {
    setBusy(true);
    feedback(value ? 'save' : 'tap');
    await db.settings.update('singleton', {
      displayName: cleanName(value),
      onboardedAt: nowISO(),
    });
  };

  const preview = cleanName(name);

  return (
    <div className="fullscrim" role="dialog" aria-modal="true" aria-labelledby="welcome-title">
      <div className="fullsheet welcomesheet">
        <span className="grip" aria-hidden="true" />

        <Scout pose="waving" height={150} motion={['float', 'breathe']} shadow alt="Scout waving" />

        <h2 id="welcome-title">Hello, I'm Scout</h2>
        <p>I'll keep an eye on your warranties. What should I call you?</p>

        <form
          className="welcomeform"
          onSubmit={(e) => {
            e.preventDefault();
            if (!busy) void finish(name);
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
            {preview ? `Nice to meet you, ${preview}` : 'Continue'}
          </button>
        </form>

        <button type="button" className="linkish" disabled={busy} onClick={() => void finish('')}>
          Skip
        </button>
      </div>
    </div>
  );
}
