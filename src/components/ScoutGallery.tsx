import { useEffect, useMemo } from 'react';
import { createPortal } from 'react-dom';
import { pushBack } from '@/lib/backstack';
import { feedback } from '@/lib/feedback';
import { Scout, SCOUT_POSES } from './Scout';

/**
 * Every pose Scout has, in one scroll.
 *
 * Reached by tapping the Settings title twenty-five times, which is the point:
 * it costs nothing, helps nobody, and is only ever found by someone messing
 * about. An easter egg that shows up in a menu is just a feature with a silly
 * name.
 *
 * Each pose is captioned with where it actually appears, so the joke doubles
 * as the only place the cast is written down for a person rather than for the
 * compiler.
 */
export function ScoutGallery({ onClose }: { onClose: () => void }) {
  useEffect(() => pushBack(onClose), [onClose]);

  useEffect(() => {
    feedback('save');
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  // Fixed positions rather than random ones: recomputing on every render would
  // make the confetti twitch, and useMemo without a dependency is the cheapest
  // way to say "decide once".
  const confetti = useMemo(
    () =>
      Array.from({ length: 26 }, (_, i) => ({
        left: `${(i * 37) % 100}%`,
        delay: `${(i % 9) * 0.14}s`,
        drift: `${((i % 5) - 2) * 24}px`,
        tone: ['var(--gold)', 'var(--moss)', 'var(--honey)', 'var(--ember)'][i % 4],
      })),
    [],
  );

  return createPortal(
    <div className="galleryscrim" role="dialog" aria-modal="true" aria-label="Scout, every pose">
      <div className="confetti" aria-hidden="true">
        {confetti.map((c, i) => (
          <i
            key={i}
            style={{
              left: c.left,
              background: c.tone,
              animationDelay: c.delay,
              ['--drift' as string]: c.drift,
            }}
          />
        ))}
      </div>

      <header className="galleryhead">
        <div>
          <h2>You found Scout's album</h2>
          <p>Every pose he has, and where he turns up.</p>
        </div>
        <button type="button" className="iconbtn" onClick={onClose} aria-label="Close">
          <svg
            width="22"
            height="22"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.2"
            strokeLinecap="round"
          >
            <path d="M6 6l12 12M18 6L6 18" />
          </svg>
        </button>
      </header>

      <div className="gallerygrid">
        {SCOUT_POSES.map(({ pose, name, where }) => (
          <figure key={pose} className="galleryitem">
            <Scout pose={pose} height={150} motion={['breathe']} alt={name} />
            <figcaption>
              <strong>{name}</strong>
              <span>{where}</span>
            </figcaption>
          </figure>
        ))}
      </div>

      {/* The reward for twenty-five taps. Nobody needs it, which is the only
          reason it's allowed to be this long. */}
      <section className="scoutlore">
        <h3>How Scout got the job</h3>

        <p>
          A grey squirrel caches around ten thousand nuts a year and loses most of them. This is
          usually explained as bad memory. It isn't. It's that no one has ever asked a squirrel for
          proof of purchase, so no squirrel has ever kept any.
        </p>

        <p>
          Scout kept his. The acorn, obviously — but also the twig it came off, a note of which
          tree, and a photograph of the hollow he put it in, dated. The others in the oak thought
          this was excessive. It stayed excessive right up until the February the walnut store went
          missing and exactly one resident could produce a filing system.
        </p>

        <p>
          By March he was doing everyone's paperwork. By the following winter he had opinions about
          extended cover. When this app needed someone to keep track of things people own, he was
          the only candidate who turned up holding a receipt, and he has been holding it ever since
          — through eight outfits, one house move and a brief unexplained period of lounging.
        </p>

        <p className="lorekick">
          In all that time nobody has asked him to prove a single thing. He keeps it ready anyway.
          That's the whole job.
        </p>
      </section>
    </div>,
    document.body,
  );
}
