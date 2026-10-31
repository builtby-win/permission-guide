use permission_guide::{present, status, Kind};

fn main() {
    println!("status: {}", status(Kind::Accessibility));
    present(Kind::Accessibility, None, Some("Permission Guide"), |granted| {
        println!("completion: {granted}");
        std::process::exit(if granted { 0 } else { 1 });
    });
    // The callback and all AppKit work run on the main thread, so it needs a run loop.
    // Rust binaries have no NSApplication; spin the main run loop via CoreFoundation.
    extern "C" {
        fn CFRunLoopRun();
    }
    unsafe { CFRunLoopRun() };
}
