package kit.model;

/**
 * State the application shell owns, as opposed to state the application owns.
 *
 * Everything here belongs to the frame around your app: the window, the
 * status line, the dialog layer. None of it is yours to manage. Your own
 * transient interface state goes in your own model, next to this one.
 *
 * Nothing is `@serialize`: a half-open dialog or a pending message should not
 * come back after a reload. Contrast with `Preferences`, where everything
 * persists.
 */
class ChromeState extends BaseModel {

    /**
     * The question being asked right now, or null.
     *
     * Build one through `kit.Dialog` rather than assigning here.
     */
    @observe public var dialog:DialogRequest = null;

    /**
     * Short-lived confirmation shown in the status bar, or null.
     * Set it through `flash()` rather than directly, so it clears itself.
     */
    @observe public var message:String = null;

    /**
     * Whether the settings popup is open.
     *
     * The popup itself is `kit.ui.SettingsPopup`, and the shortcut that opens
     * it and the Escape that closes it live in `kit.Keys`, so an application
     * only has to mount it. See the template's `Main.hx`.
     */
    @observe public var settingsOpen:Bool = false;

    /** Set once the first paint is ready, so the desktop window can be shown. */
    @observe public var appReady:Bool = false;

    /**
     * Whether the OS window is fullscreen. Always false in a browser.
     *
     * The title bar reads it: on macOS the traffic lights disappear in
     * fullscreen, so the space reserved for them has to go with them.
     */
    @observe public var windowFullscreen:Bool = false;

    /** Whether the OS window is maximized. Always false in a browser. */
    @observe public var windowMaximized:Bool = false;

    public function new() {
        super();
    }

    /**
     * Say something in the status bar, briefly.
     *
     * The clear is guarded by comparing against the message we set: if
     * something else spoke in the meantime, its message is the current one and
     * ours has already been replaced, so this timer must not wipe it.
     */
    public function flash(text:String, seconds:Float = 2.5):Void {

        message = text;
        haxe.Timer.delay(() -> {
            if (message == text) message = null;
        }, Std.int(seconds * 1000));

    }

}
