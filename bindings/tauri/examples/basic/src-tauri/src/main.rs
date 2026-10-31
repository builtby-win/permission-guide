use tauri::{Listener, Manager};

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_permission_guide::init())
        .setup(|app| {
            // Smoke-test driver: PG_SMOKE=1 presents after launch, dismisses a few seconds later.
            if std::env::var("PG_SMOKE").is_ok() {
                app.listen("permission-guide://result", |e| println!("SMOKE event: {}", e.payload()));
                app.listen("smoke-status", |e| println!("SMOKE status: {}", e.payload()));
                let w = app.get_webview_window("main").unwrap();
                let kind = std::env::var("PG_KIND").unwrap_or_else(|_| "accessibility".into());
                std::thread::spawn(move || {
                    std::thread::sleep(std::time::Duration::from_secs(2));
                    let _ = w.eval(format!("(async()=>{{const i=window.__TAURI__.core.invoke,P='plugin:permission-guide|';window.__TAURI__.event.emit('smoke-status',await i(P+'status',{{kind:'{kind}'}}));await i(P+'present',{{kind:'{kind}'}})}})()"));
                    std::thread::sleep(std::time::Duration::from_secs(6));
                                        let _ = w.eval("window.__TAURI__.core.invoke('plugin:permission-guide|dismiss')");
                    std::thread::sleep(std::time::Duration::from_secs(2));
                    std::process::exit(0);
                });
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("run");
}
