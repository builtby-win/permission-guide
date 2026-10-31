// Packs the package, installs the tarball into a temp project and checks that it loads the
// native addon from prebuilds/ (no source build, no silent fallback).
// Usage: node scripts/verify-pack.mjs   (macOS only; run `npm run build:ts` first so dist/ exists)
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.platform !== 'darwin') { console.log('verify-pack: skipped (not macOS)'); process.exit(0); }
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const NAME = '@builtby/permission-guide';
const tmp = mkdtempSync(join(tmpdir(), 'pg-verify-'));
const fail = (m) => { console.error('verify-pack FAILED: ' + m); process.exit(1); };
const run = (cmd, args, cwd, opts = {}) => {
  const r = spawnSync(cmd, args, { cwd, encoding: 'utf8', ...opts });
  if (r.error) fail(`${cmd}: ${r.error.message}`);
  return r;
};
const must = (cmd, args, cwd) => {
  const r = run(cmd, args, cwd);
  if (r.status !== 0) fail(`${cmd} ${args.join(' ')}\n${r.stdout}\n${r.stderr}`);
  return r.stdout;
};

try {
  // 1. pack
  const packDir = join(tmp, 'pack');
  mkdirSync(packDir);
  const packed = JSON.parse(must('npm', ['pack', '--json', '--pack-destination', packDir], root))[0];
  const tgz = join(packDir, packed.filename.replace(/^@/, '').replace('/', '-'));
  const files = packed.files.map((f) => f.path);
  for (const need of ['dist/index.js', 'dist/index.d.ts', 'prebuilds/darwin-arm64/permission_guide.node', 'prebuilds/darwin-x64/permission_guide.node']) {
    if (!files.includes(need)) fail(`tarball is missing ${need}`);
  }
  const stray = files.filter((f) => /^(src|native|build|node_modules)\//.test(f));
  if (stray.length) fail('tarball contains unexpected files: ' + stray.join(', '));
  console.log(`packed ${packed.filename} (${files.length} files)`);

  // 2. install into a fresh project; install scripts must not be needed
  const proj = join(tmp, 'proj');
  mkdirSync(proj);
  writeFileSync(join(proj, 'package.json'), '{"name":"pg-verify-consumer","version":"0.0.0","private":true}');
  must('npm', ['i', '--no-audit', '--no-fund', tgz], proj);
  const pkgDir = join(proj, 'node_modules', NAME);
  if (existsSync(join(pkgDir, 'build'))) fail('install produced a build/ dir (source build ran)');

  // 3. load + API check, in a child process so we can inspect loaded shared objects
  const check = join(proj, 'check.cjs');
  writeFileSync(check, `
const assert = require('node:assert');
const pg = require(${JSON.stringify(NAME)});
assert.strictEqual(typeof pg.status('accessibility'), 'boolean');
assert.strictEqual(typeof pg.present, 'function');
assert.strictEqual(typeof pg.dismiss, 'function');
const so = process.report.getReport().sharedObjects.filter((p) => p.endsWith('permission_guide.node'));
assert.strictEqual(so.length, 1, 'addon not loaded: ' + so);
assert.ok(so[0].includes('/prebuilds/darwin-' + process.arch + '/'), 'addon not from prebuilds/: ' + so[0]);
console.log('loaded ' + so[0]);
`);
  const ok = run('node', [check], proj);
  if (ok.status !== 0) fail('load check\n' + ok.stdout + ok.stderr);
  process.stdout.write(ok.stdout);

  // 4. broken installs must throw, never fall back silently
  const probe = join(proj, 'probe.cjs');
  writeFileSync(probe, `require(${JSON.stringify(NAME)}).status('accessibility');`);
  const pre = join(pkgDir, 'prebuilds');
  const hostDir = join(pre, 'darwin-' + process.arch);
  const addon = join(hostDir, 'permission_guide.node');
  const saved = join(tmp, 'saved');
  cpSync(pre, saved, { recursive: true });
  const expectThrow = (label) => {
    const r = run('node', [probe], proj);
    if (r.status === 0) fail(label + ': require/status did not throw');
    console.log(`${label}: throws as expected (${(r.stderr.match(/Error[^\n]*/) || ['?'])[0]})`);
  };
  writeFileSync(addon, 'not a mach-o file');
  expectThrow('corrupted prebuild');
  rmSync(hostDir, { recursive: true });
  expectThrow('missing prebuild');
  rmSync(pre, { recursive: true });
  cpSync(saved, pre, { recursive: true });
  if (run('node', [check], proj).status !== 0) fail('restore after negative tests failed');
  console.log('verify-pack OK');
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
