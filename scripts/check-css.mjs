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

/**
 * Nothing may set `height` on Scout.
 *
 * `<Scout height={104} />` becomes the `height` attribute on the img, which is
 * a *presentational hint* — the weakest thing in the cascade. Any stylesheet
 * rule touching height beats it, including `height: auto`.
 *
 * `.masthead .rig img { height: auto }` was written to let him shrink on a
 * narrow phone. What it actually did was discard the prop: he was sized from
 * the width cap instead, so 132 and 104 rendered identically and the change
 * looked like it hadn't been saved. Two commits went by.
 *
 * The failure is silent in the worst way — the number in the JSX is right
 * there, plainly wrong, and nothing anywhere disagrees with it.
 *
 * `max-height` and `min-height` are fine: those clamp a height rather than
 * replacing it, which is the honest way to say "not on a small screen".
 */
function scoutHeight() {
  const out = [];
  for (const sheet of SHEETS) {
    let css;
    try {
      css = readFileSync(sheet, 'utf8');
    } catch {
      continue;
    }
    const code = css.replace(/\/\*[\s\S]*?\*\//g, (c) => c.replace(/[^\n]/g, ' '));
    // Selector, then its block. Only rules that reach the img itself: `.rig`
    // alone is a wrapper and sizing that is a different, legitimate thing.
    for (const m of code.matchAll(/([^{}]*)\{([^{}]*)\}/g)) {
      if (!/\.rig\b[^,{]*\bimg\b/.test(m[1])) continue;
      const decl = m[2].match(/(^|[;\s])height\s*:\s*([^;}]+)/);
      if (!decl) continue;
      // The selector capture starts at the previous rule's `}`, so it carries
      // the blank lines and stripped comment between them. Skip that lead, or
      // the reported line points at whitespace.
      const at = m.index + (m[1].length - m[1].trimStart().length);
      const line = code.slice(0, at).split('\n').length;
      out.push(`${sheet}:${line}  ${m[1].trim()} { height: ${decl[2].trim()} }`);
    }
  }
  return out;
}

/**
 * A subgrid child in a fractional column must set `min-width: 0`.
 *
 * Reported three times as "these two fields aren't aligned", fixed twice, and
 * the second half of it was never the labels at all.
 *
 * A grid item's automatic minimum size is its min-content, and an <input> with
 * no `size` attribute claims about twenty characters — near 200px here. Two of
 * those in `1fr 1fr` cannot fit a phone-width card, so the columns hold their
 * minimums and the whole pair overflows: left field flush, right field off the
 * edge. `width: 100%` does nothing about it, because 100% of an over-wide
 * column is still over-wide.
 *
 * Any rule opting into `grid-template-rows: subgrid` is a field pair by
 * definition here, so it needs the escape hatch. Nothing throws without it and
 * it only shows up at narrow widths, which is why it survived two fixes.
 */
function subgridMinWidth() {
  const out = [];
  for (const sheet of SHEETS) {
    let css;
    try {
      css = readFileSync(sheet, 'utf8');
    } catch {
      continue;
    }
    const code = css.replace(/\/\*[\s\S]*?\*\//g, (c) => c.replace(/[^\n]/g, ' '));
    for (const m of code.matchAll(/([^{}]*)\{([^{}]*)\}/g)) {
      if (!/grid-template-rows\s*:\s*subgrid/.test(m[2])) continue;
      if (/(^|[;\s])min-width\s*:\s*0/.test(m[2])) continue;
      const at = m.index + (m[1].length - m[1].trimStart().length);
      out.push(`${sheet}:${code.slice(0, at).split('\n').length}  ${m[1].trim()}`);
    }
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
const resized = scoutHeight();
const squeezed = subgridMinWidth();

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

if (resized.length === 0) {
  console.log("PASS  nothing overrides Scout's height");
} else {
  for (const where of resized) {
    console.log(`FAIL  a stylesheet rule sets Scout's height  — ${where}`);
    console.log('      The height prop is an attribute; this beats it silently.');
    console.log('      Use max-height to clamp him instead.');
  }
}

if (squeezed.length === 0) {
  console.log('PASS  field pairs can shrink to their column');
} else {
  for (const where of squeezed) {
    console.log(`FAIL  a subgrid field pair is missing min-width: 0  — ${where}`);
    console.log("      An input's min-content is ~20 characters; two won't fit a phone.");
    console.log('      The pair overflows its card and the right-hand field runs off.');
  }
}

const failures =
  missing.size + doubled.length + stuck.length + resized.length + squeezed.length;
console.log(failures === 0 ? '\nall green' : `\n${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
