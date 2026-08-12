/**
 * Every class the components use must exist in the stylesheet.
 *
 *   npm run test:css
 *
 * Five separate times in this codebase a className was written, looked
 * plausible, and had nothing behind it — `.countpill`, `.linkish`, `.notice`,
 * `.sheet`/`.choice`, and four more. Each one shipped and was found later by
 * eye, usually as "this doesn't match anything else". They render as raw
 * browser defaults, which is the one failure mode that never throws, never
 * fails a type check, and looks deliberate enough to survive review.
 *
 * So it's a test. It reads what the JSX actually asks for and checks the
 * stylesheet answers.
 *
 * Only string literals count. `className={active ? 'on' : ''}` contributes
 * `on`; `className={cls}` contributes nothing, because there's no way to know
 * what `cls` holds and guessing would make this noisy enough to ignore.
 */

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const SRC = 'src';
const SHEETS = ['src/styles/app.css', 'src/styles/base.css', 'src/styles/tokens.css'];

/**
 * Classes that are real but can't be seen from the stylesheet — element
 * selectors, or state classes applied to a parent and styled through a
 * descendant selector. Each needs a reason.
 */
const ALLOWED = new Set([
  // Styled as `.rig .shadow`, `.roomrow.held` etc. — present in the sheet,
  // just not as a bare `.x {` that the scan recognises.
]);

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) out.push(...walk(path));
    else if (entry.endsWith('.tsx')) out.push(path);
  }
  return out;
}

/** Class selectors the stylesheet defines, anywhere in any rule. */
function definedClasses() {
  const found = new Set();
  for (const sheet of SHEETS) {
    let css;
    try {
      css = readFileSync(sheet, 'utf8');
    } catch {
      continue;
    }
    // Strip comments so a class named in prose doesn't count as defined.
    const code = css.replace(/\/\*[\s\S]*?\*\//g, '');
    for (const m of code.matchAll(/\.(-?[_a-zA-Z][\w-]*)/g)) found.add(m[1]);
  }
  return found;
}

/**
 * Every string literal inside a className attribute. Handles the plain
 * attribute, a braced expression, and template literals with holes in them.
 */
function usedClasses(file) {
  const src = readFileSync(file, 'utf8');
  const out = new Map();

  for (const m of src.matchAll(/className\s*=\s*/g)) {
    const start = m.index + m[0].length;
    let region;

    if (src[start] === '"' || src[start] === "'") {
      const quote = src[start];
      const end = src.indexOf(quote, start + 1);
      region = src.slice(start, end + 1);
    } else if (src[start] === '{') {
      // Balance the braces so a nested object or ternary doesn't cut it short.
      let depth = 0;
      let i = start;
      for (; i < src.length; i++) {
        if (src[i] === '{') depth++;
        else if (src[i] === '}' && --depth === 0) break;
      }
      region = src.slice(start, i + 1);
    } else {
      continue;
    }

    for (const lit of region.matchAll(/(["'`])((?:\\.|(?!\1)[^\\])*)\1/g)) {
      // A literal being compared against is not a class name. This is how
      // `className={source === 'file' ? 'on' : ''}` reads: 'on' is the class,
      // 'file' is a value from somewhere else entirely.
      if (isComparand(region, lit.index, lit.index + lit[0].length)) continue;

      // Template holes split a literal into fragments; each fragment can
      // still carry whole class names on either side of the hole.
      for (const chunk of lit[2].split(/\$\{[^}]*\}/)) {
        for (const cls of chunk.split(/\s+/)) {
          if (/^-?[_a-zA-Z][\w-]*$/.test(cls)) {
            if (!out.has(cls)) out.set(cls, file);
          }
        }
      }
    }
  }

  return out;
}

/** True when the literal sits on either side of an equality operator. */
function isComparand(region, from, to) {
  const before = region.slice(0, from).trimEnd();
  const after = region.slice(to).trimStart();
  return /[=!]==?$/.test(before) || /^[=!]==?/.test(after);
}

const defined = definedClasses();
const missing = new Map();

for (const file of walk(SRC)) {
  for (const [cls, where] of usedClasses(file)) {
    if (!defined.has(cls) && !ALLOWED.has(cls)) {
      if (!missing.has(cls)) missing.set(cls, []);
      missing.get(cls).push(where);
    }
  }
}

if (missing.size === 0) {
  console.log(`PASS  every class in src has a rule  — ${defined.size} defined`);
  console.log('\nall green');
  process.exit(0);
}

for (const [cls, files] of [...missing].sort()) {
  console.log(`FAIL  .${cls} is used but never defined  — ${[...new Set(files)].join(', ')}`);
}
console.log(`\n${missing.size} failure(s)`);
process.exit(1);
