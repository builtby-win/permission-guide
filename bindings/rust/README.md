# permission-guide

Rust bindings for the native macOS permission guide panel: a docked, non-activating panel beside System Settings that walks users through granting Accessibility, Screen Recording or Input Monitoring.

macOS only (other targets compile to stubs: `status` is `false`, `present` returns `false`). Building requires a Swift toolchain (Xcode or Command Line Tools); `build.rs` compiles the bundled Swift sources (`swift/`) and links them statically. On docs.rs the Swift build is skipped.

```toml
[dependencies]
permission-guide = "0.1"
```

See `examples/present.rs`. Binaries must carry `-Wl,-rpath,/usr/lib/swift`; for Tauri apps use the `permission-guide-tauri` build helper (`permission_guide_tauri::link_swift_runtime()` in your `build.rs`).

Source of truth: <https://github.com/builtby-win/permission-guide>. License: MIT.
