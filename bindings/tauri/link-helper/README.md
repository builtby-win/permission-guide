# permission-guide-tauri

`build.rs` helper for apps using [`tauri-plugin-permission-guide`](https://crates.io/crates/tauri-plugin-permission-guide). Link args from dependency build scripts never reach your final binary, so the app must add the Swift runtime rpath itself or it dies at launch (`libswift_Concurrency` not found).

Add it to your app's `src-tauri/Cargo.toml`:

```toml
[build-dependencies]
permission-guide-tauri = "0.1"
```

and call `permission_guide_tauri::link_swift_runtime()` in the app's `build.rs`:

```rust
fn main() {
    permission_guide_tauri::link_swift_runtime(); // cargo:rustc-link-arg-bins=-Wl,-rpath,/usr/lib/swift
    tauri_build::build();
}
```

No-op on non-macOS targets. License: MIT.
