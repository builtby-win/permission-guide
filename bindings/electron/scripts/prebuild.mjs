// Produces prebuilds/darwin-arm64 and prebuilds/darwin-x64 (N-API, ABI-stable: one .node per arch
// works for every Node/Electron). Usage: node scripts/prebuild.mjs [arm64 x64]
import { spawnSync } from 'node:child_process';
import { cpSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const archs = process.argv.slice(2).length ? process.argv.slice(2) : ['arm64', 'x64'];
const sh = (cmd, args) => {
  const r = spawnSync(cmd, args, { cwd: root, stdio: 'inherit' });
  if (r.status !== 0) process.exit(r.status ?? 1);
};
for (const a of archs) {
  sh('node', ['scripts/build-swift.mjs', a]);
  sh('npx', ['node-gyp', 'rebuild', '--arch=' + a]);
  const dir = join(root, 'prebuilds', 'darwin-' + a);
  mkdirSync(dir, { recursive: true });
  cpSync(join(root, 'build', 'Release', 'permission_guide.node'), join(dir, 'permission_guide.node'));
}
