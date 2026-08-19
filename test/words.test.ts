/**
 * One dialect, and it is American.
 *
 *   npm run test:words
 *
 * The app was written in British English and the person writing the copy is
 * not, so the two drifted apart inside single screens: "Driving licence" two
 * rows above a form that said "license", "Parts and labour" under a price in
 * dollars. Nobody notices one of these. Everybody notices the pair.
 *
 * ── Why this is a test and not a grep ─────────────────────────────────────
 * A regular expression over the source cannot tell a sentence from an
 * identifier, and this codebase has several British identifiers that must not
 * change — `monogramColour`, `CATALOGUE`, the `.centred` class, and above all
 * the `licence` member of `PaperKind`, which is written into every saved
 * document and every backup ever exported. Renaming that means a schema
 * migration for a spelling.
 *
 * Importing the copy instead asks the exact question worth asking: is anything
 * a person READS spelled the wrong way? The keys can stay as they are.
 */

import { COVERAGE_LABELS, COVERS_PLACEHOLDER, UNIT_LABEL } from '@/lib/addItem';
import { KIND_LABEL } from '@/lib/papers';
import { VERDICT_COPY } from '@/lib/push';
import { PING_COPY } from '@/lib/pushDev';
import { TIP_DUE_COPY } from '@/lib/donate';
import { BACKUP_REMINDER_CHOICES, ITEM_LEAD_CHOICES, REMINDER_CHOICES } from '@/lib/prefs';
import { TOUR_STEPS } from '@/lib/tour';

let failures = 0;

function check(label: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

/**
 * Spellings, not words. `-ise` is deliberately absent: it is a suffix, and
 * "advertise", "surprise" and "exercise" are spelled that way in both.
 */
const BRITISH = [
  'licence',
  'labour',
  'colour',
  'centre',
  'favourite',
  'neighbour',
  'apologise',
  'organise',
  'organised',
  'organisation',
  'personalise',
  'catalogue',
  'programme',
  'cancelled',
  'travelled',
  'jewellery',
  'grey',
];

/** Everything the app puts in front of a person, gathered from where it lives. */
const COPY: [string, string][] = [
  ...Object.entries(KIND_LABEL).map(([k, v]): [string, string] => [`KIND_LABEL.${k}`, v]),
  ...Object.entries(UNIT_LABEL).map(([k, v]): [string, string] => [`UNIT_LABEL.${k}`, v]),
  ...Object.entries(VERDICT_COPY).map(([k, v]): [string, string] => [`VERDICT_COPY.${k}`, v]),
  ...Object.entries(PING_COPY).map(([k, v]): [string, string] => [`PING_COPY.${k}`, v]),
  ...Object.entries(TIP_DUE_COPY).map(([k, v]): [string, string] => [`TIP_DUE_COPY.${k}`, v]),
  ...COVERAGE_LABELS.map((v, i): [string, string] => [`COVERAGE_LABELS[${i}]`, v]),
  ['COVERS_PLACEHOLDER', COVERS_PLACEHOLDER],
  ...REMINDER_CHOICES.map((c): [string, string] => [`REMINDER_CHOICES`, c.label]),
  ...BACKUP_REMINDER_CHOICES.map((c): [string, string] => [`BACKUP_REMINDER_CHOICES`, c.label]),
  ...ITEM_LEAD_CHOICES.map((c): [string, string] => [`ITEM_LEAD_CHOICES`, c.label]),
  ...TOUR_STEPS.flatMap((s): [string, string][] => [
    [`tour:${s.key}.title`, s.title],
    [`tour:${s.key}.body`, s.body],
  ]),
];

function main() {
  check('there is copy to check', COPY.length > 40, `${COPY.length} strings`);

  const slips = COPY.filter(([, text]) =>
    BRITISH.some((w) => new RegExp(`\\b${w}\\b`, 'i').test(text)),
  );

  check(
    'nothing anyone reads is spelled the British way',
    slips.length === 0,
    slips.map(([where, text]) => `${where}: "${text}"`).join(' · '),
  );

  /*
    The two that started this, asserted by name. A general rule that happens to
    pass is easy to weaken by accident; these are the exact strings that were
    wrong, and they should stay named until somebody has a reason to change
    them on purpose.
  */
  check('the driving licence is a license', KIND_LABEL.licence === 'Driving license', KIND_LABEL.licence);
  check('and so is the pet one', KIND_LABEL.petlicence === 'Pet license', KIND_LABEL.petlicence);
  check('labour is labor', COVERS_PLACEHOLDER.startsWith('Parts and labor'), COVERS_PLACEHOLDER);

  /*
    And the key is NOT renamed, which is the other half of the decision. It is
    written into every saved document and every backup ever exported; changing
    it is a schema migration for a spelling, and a test that only checked the
    labels would let someone "finish the job" and break every existing record.
  */
  check('but the stored key is left alone', 'licence' in KIND_LABEL);
  check('and so is the pet key', 'petlicence' in KIND_LABEL);

  console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
  process.exit(failures === 0 ? 0 : 1);
}

main();
