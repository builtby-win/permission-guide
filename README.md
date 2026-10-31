# PermissionGuide

macOS (13+) Swift package that docks a small non-activating panel at the bottom of the System Settings window so users can **drag your app into the Privacy list** (Accessibility, Screen Recording, Input Monitoring). It auto-dismisses once the permission is granted.

The panel reads "Drop *App* in the list of apps above" with a draggable app tile. No shadows, no dimmer; dark/light adaptive and reduced-motion aware.

## Swift

```swift
.package(url: "https://github.com/winstonzhao/permission-guide", branch: "main")
```

```swift
import PermissionGuide

if !PermissionGuide.status(.accessibility) {
    PermissionGuide.present(.accessibility) { granted in
        // true: granted. false: dismissed via PermissionGuide.dismiss()
    }
}
PermissionGuide.dismiss()
```

`present(_:appURL:appName:completion:)` defaults to `Bundle.main.bundleURL` and the bundle's display name. Kinds: `.accessibility`, `.screenRecording`, `.inputMonitoring`. All calls are safe from any thread; completion fires once on the main thread. Your app must run an AppKit event loop.

## C ABI

Link the `CPermissionGuide` product and include `Sources/CPermissionGuide/include/permission_guide.h`:

```c
int  pg_status(int kind);   // 0 accessibility, 1 screen recording, 2 input monitoring
void pg_present(int kind, const char *app_path, const char *app_name,
                void (*cb)(int granted, void *ctx), void *ctx);
void pg_dismiss(void);
```

## Try it

```sh
swift run PermissionGuideExample accessibility   # or screen-recording | input-monitoring
swift run PermissionGuideExample accessibility /Applications/Foo.app
```

## How it works

- Opens `x-apple.systempreferences:com.apple.preference.security?Privacy_*`.
- Finds the System Settings window via `CGWindowListCopyWindowInfo` and follows it with a ~60 Hz timer (only while visible); hides when the window is absent, minimized or on another Space.
- Polls the permission status at ~4 Hz and on app activation; on grant shows a checkmark, closes, and calls `completion(true)`.

## License

MIT
