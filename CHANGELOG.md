# Changelog

## Unreleased
- Panel is pinned to System Settings: hidden while another app is frontmost, shown again when Settings is active.
- Panel docks below the System Settings window, falling back inside its bottom edge.
- Rust bindings crate (`bindings/rust`).
- Prebuilt `PermissionGuide.xcframework` (macOS arm64+x86_64) via `scripts/build-xcframework.sh` and tagged releases.
- Presentation-generation token prevents a stale delayed dismiss from closing a newer presentation.
