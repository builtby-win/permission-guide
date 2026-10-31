# @builtby/permission-guide (Electron / Node, macOS)

Docked, non-activating guide panel beside System Settings so users can drag your app into
**Accessibility**, **Screen Recording** or **Input Monitoring**. N-API addon over the
Swift `PermissionGuide` package in this repo. macOS only (`os`/`cpu` fields restrict install;
on other platforms every call throws `@builtby/permission-guide is only supported on macOS`).

Install: the npm tarball ships prebuilt `prebuilds/darwin-arm64` and `darwin-x64` binaries that
`node-gyp-build` loads at runtime. There is no install script and no compile step; if the prebuild for
your arch is missing or corrupt, the first call throws instead of silently falling back.

```ts
import { status, present, dismiss } from '@builtby/permission-guide';

if (!status('screen-recording')) {
  const granted = await present('screen-recording', { appName: 'My App' }); // appPath defaults to the main bundle
  // true = granted; false = guide dismissed (dismiss() or the user closed it)
}
dismiss(); // closes the panel; a pending present() resolves false
```

`kind`: `'accessibility' | 'screen-recording' | 'input-monitoring'`.

## Runtime requirements

- **Electron main process**: works as is (it already runs the AppKit loop). Call from the main process only.
- **Plain Node**: the panel and its callback need a running `NSApplication` main run loop, which plain
  Node does not have; `present()` would never show/resolve. Use Electron (or host the addon in an app that runs AppKit).
- N-API (v8), ABI-stable: one binary per CPU arch works for every Node/Electron version, no electron-rebuild.
- Loading uses `node-gyp-build`: prefers `prebuilds/darwin-<arch>/`, falls back to `build/Release`.
- `status('accessibility')` is cached per process by macOS (`AXIsProcessTrusted`); a fresh grant may need a restart.
- Ad-hoc-signed dev builds can have a TCC identity mismatch with the dragged `.app`: the toggle can be ON
  while `status()` stays false, so the guide never resolves true. Sign with a stable identity.
- When running Electron from a terminal, macOS attributes permissions to the terminal app, so `status()` may
  report true. Launch `Electron.app` via `open` to test as Electron itself.
- Packaged apps: unpack the `.node` from asar (`asarUnpack: ["**/*.node"]`).

## Build

Needs Xcode/Swift toolchain (macOS 13+).

```sh
npm install
npm run build       # swift libs (clean scratch, per product, release) -> node-gyp -> tsc
npm run prebuilds   # prebuilds/darwin-arm64 and darwin-x64 (cross-arch via node-gyp --arch)
npm run verify-pack # npm pack, install the tarball in a temp project, check it loads from prebuilds/
```

`scripts/build-swift.mjs` builds `CPermissionGuide` and `PermissionGuide` separately from a clean scratch
dir (a shared scratch with two `--product` flags leaves a stale `libCPermissionGuide.a`), and the addon is
linked with `-rpath /usr/lib/swift` plus AppKit, CoreGraphics and ApplicationServices. Your final
app binary must keep that rpath if it links these libs itself (otherwise e.g. `libswift_Concurrency` fails at launch);
the `.node` carries it already.

## Example

```sh
npm run example                       # presents accessibility, auto-dismisses after 5 s
PG_KIND=screen-recording PG_DISMISS_MS=7000 \
  open -n -W --stdout /tmp/pg.log --env PG_KIND=screen-recording --env PG_DISMISS_MS=7000 \
  node_modules/electron/dist/Electron.app --args "$PWD/examples/electron/main.js"
```
