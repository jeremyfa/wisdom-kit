package kit.platform;

/** Which host the app is running in. */
enum abstract PlatformKind(String) from String to String {

    /** A plain browser page. */
    var WEB = 'web';

    /** A Tauri desktop window. */
    var TAURI = 'tauri';

}
