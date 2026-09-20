package kit;

import kit.model.ChromeState;
import kit.model.Preferences;
import kit.model.Theme;

/**
 * Ambient accessors for the shell's own state.
 *
 * `src/kit/import.hx` pulls these into every module of this package, and
 * `src/app/import.hx` pulls them into yours as well, so any component can
 * write `theme.accent` or `chrome.flash` with no import line.
 *
 * Note what is NOT here: your model. The shell cannot name it, which is the
 * whole point. Your application's `Shortcuts` provides that, and the two sets
 * sit side by side with no overlap.
 */
class Shortcuts {

    /** The active colour palette. */
    public static var theme(get, never):Theme;
    inline static function get_theme():Theme {
        return App.theme;
    }

    /** The shell's transient state: dialog, flash message, window state. */
    public static var chrome(get, never):ChromeState;
    inline static function get_chrome():ChromeState {
        return App.model.chrome;
    }

    /** Settings the user chose, persisted. */
    public static var preferences(get, never):Preferences;
    inline static function get_preferences():Preferences {
        return App.model.preferences;
    }

}
