package kit.platform;

/**
 * The single door to everything host-specific.
 *
 * Application code calls `Platform.openTextFile(...)` and never knows, or
 * needs to know, which host it is running in.
 *
 * Backend selection is done at RUNTIME, by looking for `window.__TAURI__`.
 * That choice is what allows one JavaScript bundle, and therefore one output
 * directory, to be both the deployable web build and Tauri's frontendDist: the
 * file you smoke-test in a browser is byte for byte the file shipped in the
 * installer. Compile-time selection would mean two bundles and two chances to
 * diverge.
 *
 * `-D app_force_platform=web` overrides the detection, which is useful for
 * exercising the browser code path inside the desktop window.
 */
class Platform {

    static var backend:PlatformBackend = null;

    /** Resolve the backend. Must be the first thing `App.init()` does. */
    public static function init():Void {

        backend = resolve();
        backend.init();

    }

    static function resolve():PlatformBackend {

        #if app_force_platform
        final forced = haxe.macro.Compiler.getDefine('app_force_platform');
        if (forced == 'web') return new WebBackend();
        if (forced == 'tauri') return new TauriBackend();
        #end

        final hasTauri:Bool = js.Syntax.code(
            "(typeof window !== 'undefined' && window.__TAURI__ != null && window.__TAURI__.window != null)"
        );
        return hasTauri ? new TauriBackend() : new WebBackend();

    }

    public static var kind(get, never):PlatformKind;
    static function get_kind():PlatformKind return backend.kind();

    public static inline function isDesktop():Bool return backend.kind() == TAURI;

    public static inline function isWeb():Bool return backend.kind() == WEB;

    /**
     * Whether this machine is a Mac.
     *
     * A fact about the operating system, not about the host: a browser on
     * macOS still wants the Command key, and a desktop window on macOS still
     * puts its window buttons on the left. Cached, because it never changes
     * and it is read on every render of the title bar.
     */
    public static var isMac(get, never):Bool;
    static var _isMac:Null<Bool> = null;
    static function get_isMac():Bool {

        if (_isMac == null) {
            final platform:String = js.Syntax.code(
                "((navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || navigator.userAgent || '')"
            );
            _isMac = platform.toLowerCase().indexOf('mac') != -1;
        }
        return _isMac;

    }

    /**
     * Whether this host can do something.
     *
     * Use it to disable an affordance and explain why, not to remove it: the
     * same markup in both hosts keeps the virtual DOM tree stable, and a
     * missing button is indistinguishable from a bug.
     */
    public static inline function can(capability:Capability):Bool return backend.can(capability);

/// Files

    public static inline function openTextFile(filters:Array<FileFilter>,
        onDone:(error:Dynamic, file:OpenedFile) -> Void):Void
        backend.openTextFile(filters, onDone);

    public static inline function saveTextFileAs(suggestedName:String, content:String,
        filters:Array<FileFilter>, onDone:(error:Dynamic, ref:FileRef) -> Void):Void
        backend.saveTextFileAs(suggestedName, content, filters, onDone);

    public static inline function writeTextFile(ref:FileRef, content:String,
        onDone:(error:Dynamic, ref:FileRef) -> Void):Void
        backend.writeTextFile(ref, content, onDone);

    public static inline function revealFile(ref:FileRef, onDone:(error:Dynamic) -> Void):Void
        backend.revealFile(ref, onDone);

/// Clipboard and shell

    public static inline function copyText(text:String, onDone:(error:Dynamic) -> Void):Void
        backend.copyText(text, onDone);

    public static inline function readText(onDone:(error:Dynamic, text:String) -> Void):Void
        backend.readText(onDone);

    public static inline function openUrl(url:String, onDone:(error:Dynamic) -> Void):Void
        backend.openUrl(url, onDone);

/// Window

    public static inline function showWindow():Void backend.showWindow();

    public static inline function setWindowTitle(title:String):Void backend.setWindowTitle(title);

    public static inline function minimizeWindow():Void backend.minimizeWindow();

    public static inline function toggleMaximizeWindow():Void backend.toggleMaximizeWindow();

    public static inline function closeWindow():Void backend.closeWindow();

    public static inline function setZoom(factor:Float):Void backend.setZoom(factor);

    public static inline function onWindowStateChanged(
        callback:(fullscreen:Bool, maximized:Bool) -> Void):Void
        backend.onWindowStateChanged(callback);

}
