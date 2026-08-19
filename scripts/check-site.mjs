/**
 * The marketing site, checked against the app it is advertising.
 *
 *   npm run test:site
 *
 * ── Why this exists ───────────────────────────────────────────────────────
 * The site is one hand-written HTML file with no build step, which is the
 * right trade — a marketing page that needs a toolchain to change a sentence
 * is a page nobody updates. The cost is that nothing connects it to the code,
 * so it drifts, and it drifts in the one direction that matters: it keeps
 * promising things.
 *
 * It advertised a fifteen-record free tier for the several weeks after the cap
 * became twenty-five, and told people to connect a Google Drive backup for two
 * days after that feature was deleted. Both are the same failure — a claim
 * outliving the thing it described — and both are cheap to catch here.
 *
 * This is deliberately not a linter. It asserts a handful of specific promises
 * against their source of truth, and nothing else.
 */

import { readFileSync } from 'node:fs';

const SITE = 'site/index.html';
const POLICY = 'site/privacy.html';
const TYPES = 'src/db/types.ts';

let failures = 0;

function check(label, ok, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  — ${detail}` : ''}`);
}

const site = readFileSync(SITE, 'utf8');
const policy = readFileSync(POLICY, 'utf8');
const cap = Number(readFileSync(TYPES, 'utf8').match(/FREE_ITEM_LIMIT\s*=\s*(\d+)/)?.[1]);

/* ------------------------------------------------------------- the cap */

/*
  Written out in prose, because that is how the site says it — "twenty-five
  records" reads better on a pricing card than "25 records" and is exactly the
  form that goes stale silently. Only the numbers a free tier might plausibly
  be is enough; this is a drift check, not a numeral parser.
*/
const WORDS = {
  ten: 10,
  fifteen: 15,
  twenty: 20,
  'twenty-five': 25,
  thirty: 30,
  fifty: 50,
  'one hundred': 100,
};

check('the app has a cap to compare against', Number.isFinite(cap), String(cap));

const claims = [...site.matchAll(/([a-z-]+|\d+)\s+(?:records|items)\b/gi)]
  .map((m) => m[1].toLowerCase())
  .filter((w) => w in WORDS || /^\d+$/.test(w))
  .map((w) => (w in WORDS ? WORDS[w] : Number(w)));

check('the site names a free-tier size', claims.length > 0, `${claims.length} found`);

const wrong = claims.filter((n) => n !== cap);
check('and every one of them matches the app', wrong.length === 0, wrong.join(', '));

/* ------------------------------------------------- things that were removed */

/*
  Google Drive backup is gone: the app makes one file and hands it to the share
  sheet. "Send it to your Drive" is still true and still fine — "connect your
  Google Drive" describes a setting that no longer exists and sends people
  looking for it.
*/
check(
  'nothing tells people to connect Google Drive',
  !/connect\s+(?:your\s+own\s+|your\s+)?google\s+drive/i.test(site),
);

/*
  Notifications upload a delivery address and a list of dates. They have never
  uploaded an email address, and the site said they did for as long as the
  feature was hypothetical.
*/
check('and nothing claims an email address is sent', !/sends?\s+your\s+email/i.test(site));

/* --------------------------------------------------------- the new tabs */

// Not a feature list — the two things the app grew into, which the site spent
// a month not mentioning at all.
for (const subject of ['document', 'subscription', 'passport']) {
  check(`the site mentions ${subject}s`, site.toLowerCase().includes(subject));
}

/* ------------------------------------------------------------- the words */

/*
  One dialect, and it is American.

  The app was written in British English and the person writing the copy is
  not — so "Driving licence" sat two rows above a form that said "license",
  and "Parts and labour" appeared under a price in dollars. Nobody notices one
  of these; everybody notices the pair.

  ── The one exception, and why it is not a bug ────────────────────────────
  `PaperKind` still has a member spelled `licence`. That string is written into
  every saved document and into every backup ever exported, so renaming it
  means a schema migration for a spelling. The KEY is frozen; only what people
  read changed. The rule below is written to allow the key and catch the prose:
  a bare `'licence'` is the identifier, and the labels people read are checked
  in test/words.test.ts, which can import them rather than guess at them with a
  regular expression.
*/
const BRITISH = ['licence', 'labour', 'organis', 'centre', 'colour', 'favourite', 'apologis'];

for (const [name, text] of [
  ['the site', site],
  ['the policy', policy],
]) {
  const found = BRITISH.filter((w) => new RegExp(w, 'i').test(text));
  check(`${name} is written in American English`, found.length === 0, found.join(', '));
}

/* ------------------------------------------------------------ the policy */

check('the privacy policy is linked from the site', site.includes('privacy.html'));
check('and it is a real page', policy.includes('<h1>') && policy.length > 2000);
check(
  'and says what leaves the device',
  /delivery address/i.test(policy) && /never leaves/i.test(policy),
);

console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
