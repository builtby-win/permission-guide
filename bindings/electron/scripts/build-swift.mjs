// Builds the repo's Swift static libs (one product per invocation, clean scratch dir:
// a shared scratch with several --product flags leaves a stale libCPermissionGuide.a).
// Usage: node scripts/build-swift.mjs [arm64|x64 ...]  (default: host arch)
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.platform !== 'darwin') { console.log('permission-guide: skipping Swift build (not macOS)'); process.exit(0); }
const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const pkg = join(root, '..', '..');
if (!existsSync(join(pkg, 'Package.swift'))) { console.error('Package.swift not found at ' + pkg); process.exit(1); }

const archs = process.argv.slice(2);
if (!archs.length) archs.push(process.arch);
const run = (args) => {
  const r = spawnSync('swift', args, { stdio: ['ignore', 'pipe', 'inherit'], encoding: 'utf8' });
  if (r.status !== 0) { console.error('swift ' + args.join(' ') + ' failed'); process.exit(1); }
  return r.stdout;
};
for (const a of archs) {
  const swiftArch = a === 'x64' ? 'x86_64' : 'arm64';
  const scratch = join(root, 'build', 'swift-' + a);
  rmSync(scratch, { recursive: true, force: true });
  const common = ['-c', 'release', '--arch', swiftArch, '--package-path', pkg, '--scratch-path', scratch];
  for (const product of ['CPermissionGuide', 'PermissionGuide']) {
    process.stdout.write(run(['build', ...common, '--product', product]));
  }
  const bin = run(['build', ...common, '--show-bin-path']).trim();
  const out = join(root, 'native', 'lib', a);
  mkdirSync(out, { recursive: true });
  for (const lib of ['libCPermissionGuide.a', 'libPermissionGuide.a']) cpSync(join(bin, lib), join(out, lib));
  console.log('swift libs -> ' + out);
}
