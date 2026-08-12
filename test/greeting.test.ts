/**
 * The line at the top of the dashboard.
 *
 *   npm run test:greeting
 *
 * Small, but it's the first thing anyone reads every time they open the app,
 * and getting someone's name wrong — or telling them good morning at nine at
 * night — is the kind of small wrongness people notice daily.
 */

import { cleanName, dayPart, greeting } from '@/lib/greeting';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

/** Local time, deliberately: the greeting is about the user's clock. */
function at(hour: number, minute = 0): Date {
  return new Date(2026, 7, 11, hour, minute);
}

function main() {
  /* --------------------------------------------------------- boundaries */

  check('midnight is evening', dayPart(at(0)) === 'evening');
  check('04:59 is still evening', dayPart(at(4, 59)) === 'evening');
  check('05:00 turns morning', dayPart(at(5)) === 'morning');
  check('11:59 is the last of the morning', dayPart(at(11, 59)) === 'morning');
  check('noon is afternoon', dayPart(at(12)) === 'afternoon');
  check('17:59 is the last of the afternoon', dayPart(at(17, 59)) === 'afternoon');
  check('18:00 turns evening', dayPart(at(18)) === 'evening');
  check('23:00 is evening', dayPart(at(23)) === 'evening');

  /* ------------------------------------------------------------- naming */

  check('a name is used', greeting('Nuno', at(9)) === 'Good morning, Nuno');
  check('afternoon', greeting('Nuno', at(14)) === 'Good afternoon, Nuno');
  check('evening', greeting('Nuno', at(21)) === 'Good evening, Nuno');

  // Skipping the question is a real answer, and the greeting still works.
  check('no name, no comma', greeting(undefined, at(9)) === 'Good morning');
  check('an empty name is the same as none', greeting('', at(9)) === 'Good morning');
  check('so is whitespace', greeting('   ', at(9)) === 'Good morning');

  /* ------------------------------------------------------------ cleanup */

  check('a full name greets the first', cleanName('Nuno Silva') === 'Nuno');
  check('spacing is collapsed', cleanName('  Nuno   Silva ') === 'Nuno');
  // Nothing downstream truncates, and the header is one line on a phone.
  check('an absurd name is cut', cleanName('a'.repeat(80)).length === 24);
  check('nothing in, nothing out', cleanName(undefined) === '');

  // Names are not sanitised beyond whitespace: they're rendered as text, never
  // as markup, and mangling someone's actual name to satisfy a regex is worse
  // than the imaginary problem it solves.
  check("apostrophes survive", cleanName("O'Brien") === "O'Brien");
  check('accents survive', cleanName('Zoë') === 'Zoë');
  check('non-latin survives', cleanName('未来') === '未来');

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
