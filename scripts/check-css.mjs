/**
 * Every class the components use must exist in the stylesheet — and no class
 * may be defined twice.
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
 *
 * The second check is the opposite failure. `.grip` was written twice — once
 * for the room list's reorder handle, once, 1,300 lines later, for a sheet
 * drag pill that no component ever rendered. The later rule wins, so all
 * fifteen handles became 4px grey bars stacked in one corner. `.needscard` had
 * the same shape and was merely lucky. Nothing throws, nothing fails to
 * compile, and the sheet reads correctly in both places — you have to see the
 * two rules side by side to know, and they are never side by side.
 *
 * So: a top-level `.x { }` may appear once. Grouped selectors
 * (`.a, .b { shared }` followed by `.b { specific }`) are the normal way to
 * share a base and are allowed. Rules inside `@media` are overrides by
 * definition and don't count.
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

/**
 * Classes deliberately declared twice at the top level, each with a reason.
 * Adding to this list should feel like a decision.
 */
const DOUBLE_OK = new Set([]);

/**
 * Top-level rules whose selector is a single bare class, mapped to the lines
 * they appear on. Skips anything nested in an at-rule and anything grouped
 * with another selector.
 */
function soleClassRules(sheet, css) {
  const out = new Map();
  const code = css.replace(/\/\*[\s\S]*?\*\//g, (c) => c.replace(/[^\n]/g, ' '));
  let depth = 0;
  const lines = code.split('\n');

  /** True when this line is the tail of `.a,\n.b {` — a shared base, not a
      second rule. Whitespace and stripped comments in between are skipped. */
  const grouped = (i) => {
    for (let j = i - 1; j >= 0; j--) {
      const prev = lines[j].trim();
      if (prev === '') continue;
      return prev.endsWith(',');
    }
    return false;
  };

  lines.forEach((line, i) => {
    if (depth === 0) {
      const m = line.trim().match(/^\.(-?[_a-zA-Z][\w-]*)\s*\{\s*$/);
      if (m && !grouped(i)) {
        if (!out.has(m[1])) out.set(m[1], []);
        out.get(m[1]).push(`${sheet}:${i + 1}`);
      }
    }
    for (const ch of line) {
      if (ch === '{') depth++;
      else if (ch === '}') depth--;
    }
  });

  return out;
}

function duplicateRules() {
  const all = new Map();
  for (const sheet of SHEETS) {
    let css;
    try {
      css = readFileSync(sheet, 'utf8');
    } catch {
      continue;
    }
    for (const [cls, where] of soleClassRules(sheet, css)) {
      if (!all.has(cls)) all.set(cls, []);
      all.get(cls).push(...where);
    }
  }
  return [...all].filter(([cls, where]) => where.length > 1 && !DOUBLE_OK.has(cls));
}

/**
 * The scroller, `.app-body`, is `touch-action: pan-y`. Touch-action intersects
 * down the ancestor chain, so a descendant that says `pan-x` doesn't add
 * horizontal panning — it subtracts vertical, and pan-x ∩ pan-y is *none*. A
 * touch starting there scrolls in no direction whatsoever.
 *
 * That is what `.roomlist { touch-action: pan-x }` did. It was written to keep
 * the browser from stealing a vertical drag mid-reorder, which `.grip` already
 * handles with `touch-action: none` on the element the drag actually starts
 * on. The cost was the rest of the room list: fifteen rooms, nine on screen,
 * and no way down.
 *
 * `none` is fine — that's a deliberate "this gesture is ours".
 */
function badTouchAction() {
  const out = [];
  for (const sheet of SHEETS) {
    let css;
    try {
      css = readFileSync(sheet, 'utf8');
    } catch {
      continue;
    }
    const code = css.replace(/\/\*[\s\S]*?\*\//g, (c) => c.replace(/[^\n]/g, ' '));
    code.split('\n').forEach((line, i) => {
      const m = line.match(/touch-action\s*:\s*([^;}]+)/);
      if (!m) return;
      const value = m[1].trim();
      const horizontal = /\bpan-(x|left|right)\b/.test(value);
      const vertical = /\bpan-(y|up|down)\b/.test(value);
      if (horizontal && !vertical) out.push(`${sheet}:${i + 1}  touch-action: ${value}`);
    });
  }
  return out;
}

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

const doubled = duplicateRules();
const stuck = badTouchAction();

if (missing.size === 0) {
  console.log(`PASS  every class in src has a rule  — ${defined.size} defined`);
} else {
  for (const [cls, files] of [...missing].sort()) {
    console.log(`FAIL  .${cls} is used but never defined  — ${[...new Set(files)].join(', ')}`);
  }
}

if (doubled.length === 0) {
  console.log('PASS  no class is defined twice');
} else {
  for (const [cls, where] of doubled.sort()) {
    console.log(`FAIL  .${cls} has ${where.length} rules  — ${where.join(', ')}`);
    console.log('      The last one wins. Merge them, or rename one.');
  }
}

if (stuck.length === 0) {
  console.log('PASS  nothing forbids vertical scrolling');
} else {
  for (const where of stuck) {
    console.log(`FAIL  horizontal-only pan inside a pan-y scroller  — ${where}`);
    console.log('      Intersected with .app-body this is `none`: it will not scroll at all.');
  }
}

const failures = missing.size + doubled.length + stuck.length;
console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
