use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("macos") {
        return;
    }
    let pkg = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap()).join("../..");
    println!("cargo:rerun-if-changed={}", pkg.join("Sources").display());
    println!("cargo:rerun-if-changed={}", pkg.join("Package.swift").display());

    let scratch = PathBuf::from(std::env::var("OUT_DIR").unwrap()).join("swift-build");
    // SwiftPM's incremental static-archive packing leaves libCPermissionGuide.a holding a stale
    // copy of PermissionGuide.o after source edits (and the linker prefers it). Always build clean;
    // this script only reruns when Sources/Package.swift change.
    let _ = std::fs::remove_dir_all(&scratch);
    let arch = match std::env::var("CARGO_CFG_TARGET_ARCH").as_deref() {
        Ok("x86_64") => "x86_64",
        _ => "arm64",
    };
    // One invocation per product: with several `--product` flags a clean SwiftPM build only
    // produces the last one, so libCPermissionGuide.a goes missing.
    for product in ["CPermissionGuide", "PermissionGuide"] {
        let status = Command::new("swift")
            .args(["build", "-c", "release", "--product", product, "--arch", arch])
            .arg("--package-path")
            .arg(&pkg)
            .arg("--scratch-path")
            .arg(&scratch)
            .status()
            .expect("failed to run `swift build`");
        assert!(status.success(), "swift build failed");
    }

    let bin = Command::new("swift")
        .args(["build", "-c", "release", "--arch", arch, "--show-bin-path"])
        .arg("--package-path")
        .arg(&pkg)
        .arg("--scratch-path")
        .arg(&scratch)
        .output()
        .expect("failed to run `swift build --show-bin-path`");
    let bin = String::from_utf8(bin.stdout).unwrap();
    println!("cargo:rustc-link-search=native={}", bin.trim());
    println!("cargo:rustc-link-lib=static=CPermissionGuide");
    println!("cargo:rustc-link-lib=static=PermissionGuide");

    // Swift runtime: system copy first, toolchain copy for back-deploy shims.
    println!("cargo:rustc-link-search=native=/usr/lib/swift");
    if let Ok(out) = Command::new("xcrun").args(["--toolchain", "default", "--find", "swiftc"]).output() {
        let swiftc = PathBuf::from(String::from_utf8_lossy(&out.stdout).trim());
        if let Some(root) = swiftc.parent().and_then(|p| p.parent()) {
            println!("cargo:rustc-link-search=native={}", root.join("lib/swift/macosx").display());
            println!("cargo:rustc-link-search=native={}", root.join("lib/swift-5.5/macosx").display());
        }
    }
    println!("cargo:rustc-link-arg=-Wl,-rpath,/usr/lib/swift");
    for f in ["AppKit", "CoreGraphics", "ApplicationServices", "Foundation", "QuartzCore"] {
        println!("cargo:rustc-link-lib=framework={f}");
    }
}
