# PermissionGuide

A small native panel that helps users grant macOS Privacy permissions (Accessibility, Screen Recording, Input Monitoring). It opens the right System Settings pane and docks a non-activating panel **below the Settings window** (inside its bottom edge if the screen has no room) showing your app's icon. The user drags the tile into the list and turns the toggle on. The panel follows the Settings window, hides when it is minimized or on another Space, and closes itself with a checkmark once the permission is granted.

macOS only. **Not for iOS.** Requires macOS 13+, an AppKit run loop (a regular `NSApplication`), and a Swift toolchain to build (the runtime ships with macOS).

| Path | Use it from |
| --- | --- |
| Swift package | Swift / AppKit apps |
| C ABI | anything with FFI (Go, Zig, C++, …) |
| [Rust crate](bindings/rust) | Rust apps (Tauri, native) |
| [Electron addon](bindings/electron/README.md) | Electron apps |
| [Tauri plugin](bindings/tauri/README.md) | Tauri apps |

## Swift

```swift
.package(url: "https://github.com/winstonzhao/permission-guide", branch: "main")
// target dependency: .product(name: "PermissionGuide", package: "permission-guide")
```

```swift
import PermissionGuide

if !PermissionGuide.status(.accessibility) {
    PermissionGuide.present(.accessibility) { granted in
        // true: granted. false: dismissed via PermissionGuide.dismiss() or replaced by a newer present()
    }
}
PermissionGuide.dismiss()
```

`present(_:appURL:appName:completion:)` defaults to `Bundle.main.bundleURL` and the bundle's display name (then bundle name, then file name). Kinds: `.accessibility`, `.screenRecording`, `.inputMonitoring`. Calls are safe from any thread; the completion fires once, on the main thread.

## C ABI

```c
int  pg_status(int kind);   // 0 accessibility, 1 screen recording, 2 input monitoring; 1 = granted
void pg_present(int kind, const char *app_path, const char *app_name,
                void (*cb)(int granted, void *ctx), void *ctx);   // path/name may be NULL
void pg_dismiss(void);
```

Either link the `CPermissionGuide` SwiftPM product (header: `Sources/CPermissionGuide/include/permission_guide.h`) or use the prebuilt, universal (arm64 + x86_64) `PermissionGuide.xcframework.zip` attached to each [release](https://github.com/winstonzhao/permission-guide/releases) (SHA-256 alongside). Build it yourself with `scripts/build-xcframework.sh`.

Linking requirements (the static library depends on the Swift runtime):

- frameworks: `AppKit CoreGraphics ApplicationServices Foundation QuartzCore`
- linker flag: **`-Wl,-rpath,/usr/lib/swift`** — without it the app dies at launch (e.g. missing `libswift_Concurrency`)

## Rust

```toml
permission-guide = { git = "https://github.com/winstonzhao/permission-guide", branch = "main" }
```

```rust
use permission_guide::{present, status, Kind};
if !status(Kind::Accessibility) {
    present(Kind::Accessibility, None, Some("My App"), |granted| { /* main thread */ });
}
```

`build.rs` runs `swift build` for each product from a clean scratch dir and links the static libraries and the rpath for you. See `bindings/rust/examples/present.rs`.

## Signing and TCC notes

- `AXIsProcessTrusted` is cached **per process**: after the user grants Accessibility, the status flips while the guide is polling, but other code paths in a process that already checked may need a relaunch.
- Success is detected by the API reporting trusted, so the toggle must be **ON**, not just the app listed.
- Ad-hoc-signed dev builds have a code identity that changes per build. The `.app` the user dragged may not match the running binary in TCC, so the check never fires. Sign with a stable identity (Developer ID or a fixed development cert) for testing, or reset stale entries: `tccutil reset Accessibility <bundle-id>` (also `ScreenCapture`, `ListenEvent`).
- Drag the real `.app` bundle: the tile uses the icon and path of `appURL`, so run from a bundle, not a bare binary, in production.

## Try it

```sh
swift run PermissionGuideExample accessibility   # or screen-recording | input-monitoring
swift run PermissionGuideExample accessibility /Applications/Foo.app
```

If the permission is already granted to your terminal the example reports it immediately; launch it from a fresh `.app` to see the panel.

## How it works

- Opens `x-apple.systempreferences:com.apple.preference.security?Privacy_*`.
- Finds the System Settings window with `CGWindowListCopyWindowInfo` and follows it with a ~60 Hz timer while visible.
- Polls status at ~4 Hz and on app activation. A newer `present()` replaces the current one (the old completion gets `false`); each presentation has a generation token so a stale delayed close never affects a newer one.

## Development

```sh
swift build -c release && swift test
cargo check --manifest-path bindings/rust/Cargo.toml
scripts/build-xcframework.sh
```

## License

MIT
