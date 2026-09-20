//! The desktop host, shared by every project built on this kit.
//!
//! Deliberately thin. Every plugin registered here backs one `Capability` that
//! `kit.platform.TauriBackend` reports as available, and nothing else is
//! exposed. The application logic lives in Haxe, so that the browser build is
//! the same program.
//!
//! A project does NOT call `run()` here, because `tauri::generate_context!`
//! has to be expanded inside the project's own crate, because it reads that
//! crate's
//! tauri.conf.json and embeds that project's frontend. So the kit hands back a
//! configured builder and the project finishes the sentence:
//!
//! ```ignore
//! pub fn run() {
//!     wisdom_kit_tauri::builder()
//!         .run(tauri::generate_context!())
//!         .expect("error while running tauri application");
//! }
//! ```
//!
//! That is the whole of a project's Rust, and it means a new plugin or a
//! change to the window chrome reaches every project by bumping the submodule.

use tauri::{Builder, Wry};

/// Take the operating system's title bar away, each platform its own way.
///
/// macOS is not touched here. Its window keeps `decorations: true` together
/// with `titleBarStyle: "Overlay"` and `hiddenTitle: true` from
/// tauri.conf.json, which hides the bar but KEEPS the traffic lights, floating
/// them over the app's own title bar at `trafficLightPosition`. Setting
/// `decorations: false` there would take the traffic lights with it and leave
/// the window with no way to be closed.
///
/// Windows and Linux have no such half-measure, so the window is made
/// genuinely undecorated and the frontend draws minimise, maximise and close
/// on the right. Done in Rust rather than in the config because it is the one
/// key that differs per platform, and a platform-specific config file would
/// have to repeat the entire window object to change it.
///
/// Applied while the window is still hidden, so nothing flickers.
#[cfg(not(target_os = "macos"))]
fn apply_window_chrome(app: &tauri::AppHandle) {
    // Imported here rather than at the top of the file, so the macOS build
    // does not carry an unused import it would warn about.
    use tauri::Manager;

    if let Some(window) = app.get_webview_window("main") {
        // An undecorated window on Windows keeps its resize handles through
        // tao's own hit-testing, but loses the system drop shadow. That is the
        // usual trade for a custom title bar.
        let _ = window.set_decorations(false);
    }
}

#[cfg(target_os = "macos")]
fn apply_window_chrome(_app: &tauri::AppHandle) {}

/// A Tauri builder with the kit's plugins and window handling already on it.
///
/// Add anything of your own before calling `.run(...)`; nothing here is final.
pub fn builder() -> Builder<Wry> {
    Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_clipboard_manager::init())
        .setup(|app| {
            apply_window_chrome(app.handle());
            Ok(())
        })
}
