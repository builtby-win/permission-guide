# tauri-plugin-permission-guide

Tauri v2 plugin for [permission-guide](../..): a docked, non-activating panel beside System Settings that walks users through dragging your app into the Accessibility, Screen Recording or Input Monitoring lists. macOS only (other platforms: `status` is `false`, `present` resolves `granted: false`).

## Install

1. Cargo dependencies (`src-tauri/Cargo.toml`):

   ```toml
   [dependencies]
   tauri-plugin-permission-guide = { path = "…/permission-guide/bindings/tauri" }

   [build-dependencies]
   permission-guide-tauri = { path = "…/permission-guide/bindings/tauri/link-helper" }
   ```

2. Swift runtime rpath. The plugin links Swift, but link args from dependency build scripts never reach your final binary, so without `-rpath /usr/lib/swift` the app dies at launch (`libswift_Concurrency` not found). In `src-tauri/build.rs`:

   ```rust
   fn main() {
       permission_guide_tauri::link_swift_runtime(); // cargo:rustc-link-arg-bins=-Wl,-rpath,/usr/lib/swift
       tauri_build::build();
   }
   ```

3. Register the plugin:

   ```rust
   tauri::Builder::default()
       .plugin(tauri_plugin_permission_guide::init())
   ```

4. Capability (`src-tauri/capabilities/default.json`): add `"permission-guide:default"` (allows `status`, `present`, `dismiss`).

5. JS (`tauri-plugin-permission-guide-api`, in this directory; `npm run build` produces `dist-js`):

   ```ts
   import { status, present, dismiss, onResult } from 'tauri-plugin-permission-guide-api'

   if (!(await status('accessibility'))) {
     const unlisten = await onResult(({ kind, granted }) => { console.log(kind, granted); unlisten() })
     await present('accessibility', { appName: 'My App' }) // resolves once the panel is requested
   }
   ```

   Kinds: `'accessibility' | 'screenRecording' | 'inputMonitoring'`. `appPath`/`appName` default to the enclosing `*.app` of the running executable (falling back to the executable itself).

## Behaviour

- `present` returns after the panel is requested (hopped onto the main thread); the outcome arrives as event `permission-guide://result` with `{ kind, granted }` — `granted: true` on success, `false` when dismissed (`dismiss()` or the panel's close).
- `AXIsProcessTrusted` is cached per process; ad-hoc-signed dev builds can have a TCC identity mismatch with the dragged `.app`, so the success check may never fire even after dragging (the toggle must also be ON).

## Example

`examples/basic`: `cd examples/basic/src-tauri && cargo build`. For a real TCC identity, wrap the binary in a `.app` (`cargo tauri build`) — a binary run from a terminal inherits the terminal's grants. `PG_SMOKE=1 PG_KIND=inputMonitoring` auto-presents, dismisses after 8s and prints the events.
