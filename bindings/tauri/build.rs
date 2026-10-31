const COMMANDS: &[&str] = &["status", "present", "dismiss"];

fn main() {
    tauri_plugin::Builder::new(COMMANDS).build();
}
