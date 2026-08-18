/**
 * Bundles one TypeScript test with esbuild and runs it in Node.
 *
 * These tests need the app's real modules — Dexie schema, repo, warranty maths
 * — so they have to resolve the `@/` alias and strip types. esbuild does both
 * in about 40ms, which is cheaper than adding a test framework for what are
 * ultimately assertion scripts.
 */

import { execFileSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { basename, join } from 'node:path';
import { build } from 'esbuild';

const entry = process.argv[2];
if (!entry) {
  console.error('usage: node scripts/run-test.mjs <test-file.ts>');
  process.exit(2);
}

const outDir = join('node_modules', '.cache', 'stash-tests');
mkdirSync(outDir, { recursive: true });
const outfile = join(outDir, `${basename(entry, '.ts')}.mjs`);

await build({
  entryPoints: [entry],
  outfile,
  bundle: true,
  platform: 'node',
  format: 'esm',
  alias: { '@': './src' },
  /*
    Every build constant, not just the version.

    A module that reads one of these is bundled whole even if the test only
    calls a pure function three exports along, and esbuild leaves an undefined
    constant as a bare identifier — so the failure is a ReferenceError thrown
    from a line the test never meant to reach. Empty is the correct value here
    anyway: a test run has no VAPID key and no sender, and code that behaves
    differently without them is code worth testing in that state.
  */
  define: {
    __APP_VERSION__: '"0.0.0-test"',
    __SITE_PATH__: '"/"',
    __VAPID_PUBLIC_KEY__: '""',
    __PUSH_ENDPOINT__: '""',
  },
  logLevel: 'error',
});

try {
  execFileSync(process.execPath, [outfile], { stdio: 'inherit' });
} catch {
  process.exit(1);
}
