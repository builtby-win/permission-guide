// Prints the Swift toolchain lib dirs as linker flags (for static Swift back-deploy shims).
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const r = spawnSync('xcrun', ['--toolchain', 'default', '--find', 'swiftc'], { encoding: 'utf8' });
const root = path.dirname(path.dirname((r.stdout || '').trim()));
console.log(['lib/swift/macosx', 'lib/swift-5.5/macosx'].map((d) => '-L' + path.join(root, d)).join(' '));
