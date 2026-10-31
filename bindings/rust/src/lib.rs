//! Rust bindings for the native macOS permission-guide panel.
//! On non-macOS targets everything is a stub: `status` is false and `present` reports `false`.

use std::path::Path;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Accessibility,
    ScreenRecording,
    InputMonitoring,
}

#[cfg(target_os = "macos")]
mod sys {
    use std::ffi::{c_char, c_int, c_void};

    extern "C" {
        pub fn pg_status(kind: c_int) -> c_int;
        pub fn pg_present(
            kind: c_int,
            app_path: *const c_char,
            app_name: *const c_char,
            cb: Option<extern "C" fn(c_int, *mut c_void)>,
            ctx: *mut c_void,
        );
        pub fn pg_dismiss();
    }
}

#[cfg(target_os = "macos")]
impl Kind {
    fn raw(self) -> i32 {
        match self {
            Kind::Accessibility => 0,
            Kind::ScreenRecording => 1,
            Kind::InputMonitoring => 2,
        }
    }
}

/// Whether the permission is currently granted. Any thread.
pub fn status(kind: Kind) -> bool {
    #[cfg(target_os = "macos")]
    unsafe {
        sys::pg_status(kind.raw()) != 0
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = kind;
        false
    }
}

/// Opens the Privacy pane and docks the guide panel. `on_result(true)` on grant,
/// `on_result(false)` on dismiss. Any thread; the callback runs on the main thread.
pub fn present(
    kind: Kind,
    app_path: Option<&Path>,
    app_name: Option<&str>,
    on_result: impl FnOnce(bool) + Send + 'static,
) {
    #[cfg(target_os = "macos")]
    {
        use std::ffi::{c_int, c_void, CString};

        extern "C" fn trampoline(granted: c_int, ctx: *mut c_void) {
            let cb = unsafe { Box::from_raw(ctx as *mut Box<dyn FnOnce(bool) + Send>) };
            cb(granted != 0);
        }

        let path = app_path.and_then(|p| CString::new(p.to_string_lossy().into_owned()).ok());
        let name = app_name.and_then(|n| CString::new(n).ok());
        let ctx = Box::into_raw(Box::new(Box::new(on_result) as Box<dyn FnOnce(bool) + Send>));
        unsafe {
            sys::pg_present(
                kind.raw(),
                path.as_ref().map_or(std::ptr::null(), |c| c.as_ptr()),
                name.as_ref().map_or(std::ptr::null(), |c| c.as_ptr()),
                Some(trampoline),
                ctx as *mut c_void,
            );
        }
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = (kind, app_path, app_name);
        on_result(false);
    }
}

/// Closes the guide; a pending callback receives `false`. Any thread.
pub fn dismiss() {
    #[cfg(target_os = "macos")]
    unsafe {
        sys::pg_dismiss()
    }
}
