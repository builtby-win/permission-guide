//! Use from your app's `build.rs` (as a `[build-dependencies]` entry):
//!
//! ```no_run
//! fn main() {
//!     permission_guide_tauri::link_swift_runtime();
//!     // tauri_build::build();
//! }
//! ```
//!
//! Link args emitted by dependency build scripts do not reach the final binary, so the app
//! itself must add `-rpath /usr/lib/swift` or it dies at launch (libswift_Concurrency not found).

/// Emits `cargo:rustc-link-arg-bins=-Wl,-rpath,/usr/lib/swift` on macOS targets.
pub fn link_swift_runtime() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        println!("cargo:rustc-link-arg-bins=-Wl,-rpath,/usr/lib/swift");
    }
}
