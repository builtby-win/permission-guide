//! Tauri v2 plugin around the native macOS permission-guide panel.
//!
//! The app's own `build.rs` must add the Swift runtime rpath, see [`permission_guide_tauri`'s
//! `link_swift_runtime`](https://docs.rs/permission-guide-tauri) / the README.

use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use tauri::{
    plugin::{Builder, TauriPlugin},
    AppHandle, Emitter, Runtime,
};

/// Event emitted when a presented guide resolves: payload [`ResultPayload`].
pub const RESULT_EVENT: &str = "permission-guide://result";

#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Kind {
    Accessibility,
    ScreenRecording,
    InputMonitoring,
}

impl From<Kind> for permission_guide::Kind {
    fn from(k: Kind) -> Self {
        match k {
            Kind::Accessibility => Self::Accessibility,
            Kind::ScreenRecording => Self::ScreenRecording,
            Kind::InputMonitoring => Self::InputMonitoring,
        }
    }
}

#[derive(Clone, Copy, Debug, Serialize)]
pub struct ResultPayload {
    pub kind: Kind,
    pub granted: bool,
}

/// The enclosing `*.app` bundle of the running executable, else the executable itself.
fn default_app_path() -> Option<PathBuf> {
    let exe = std::env::current_exe().ok()?;
    let bundle = exe
        .ancestors()
        .find(|p| p.extension().is_some_and(|e| e == "app"))
        .map(Path::to_path_buf);
    Some(bundle.unwrap_or(exe))
}

#[tauri::command]
fn status(kind: Kind) -> bool {
    permission_guide::status(kind.into())
}

/// Returns once the panel has been requested on the main thread; the outcome arrives as
/// [`RESULT_EVENT`].
#[tauri::command]
fn present<R: Runtime>(
    app: AppHandle<R>,
    kind: Kind,
    app_path: Option<PathBuf>,
    app_name: Option<String>,
) -> Result<(), String> {
    let path = app_path.or_else(default_app_path);
    let emitter = app.clone();
    app.run_on_main_thread(move || {
        permission_guide::present(kind.into(), path.as_deref(), app_name.as_deref(), move |granted| {
            let _ = emitter.emit(RESULT_EVENT, ResultPayload { kind, granted });
        });
    })
    .map_err(|e| e.to_string())
}

#[tauri::command]
fn dismiss<R: Runtime>(app: AppHandle<R>) -> Result<(), String> {
    app.run_on_main_thread(permission_guide::dismiss)
        .map_err(|e| e.to_string())
}

pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("permission-guide")
        .invoke_handler(tauri::generate_handler![status, present, dismiss])
        .build()
}
