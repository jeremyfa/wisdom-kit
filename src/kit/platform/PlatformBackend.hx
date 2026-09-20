package kit.platform;

/**
 * The host-specific half of the app. Exactly two implementations exist:
 * `TauriBackend` for the desktop window and `WebBackend` for a browser page.
 *
 * Two rules hold across the whole interface:
 *
 * 1. Every async operation is callback style `(error, value) -> Void`, error
 *    first. No Promise ever escapes a backend, so application code never has
 *    to know that Tauri's JS API is promise-based.
 *
 * 2. It is document oriented, never path oriented. Picking a file and reading
 *    it are ONE operation, because a browser can never hand back a path for
 *    you to read later.
 *
 * Adding an operation means adding it here and in both backends, which is the
 * point: the compiler will not let you ship a feature that silently does
 * nothing in one of the two hosts.
 */
interface PlatformBackend {

    function kind():PlatformKind;

    function can(capability:Capability):Bool;

    /** Called once at startup, after the DOM exists. */
    function init():Void;

/// Files

    /**
     * Pick one text file and read it, in a single step.
     * Calls `onDone(null, null)` when the user cancels.
     */
    function openTextFile(filters:Array<FileFilter>, onDone:(error:Dynamic, file:OpenedFile) -> Void):Void;

    /**
     * Ask where to put `content` and write it.
     * Desktop: a native save dialog. Web: a download.
     * Calls `onDone(null, null)` when the user cancels.
     */
    function saveTextFileAs(suggestedName:String, content:String, filters:Array<FileFilter>,
        onDone:(error:Dynamic, ref:FileRef) -> Void):Void;

    /**
     * Overwrite a reference obtained earlier.
     * Falls back to a fresh download where there is no filesystem.
     */
    function writeTextFile(ref:FileRef, content:String, onDone:(error:Dynamic, ref:FileRef) -> Void):Void;

    /** Show the file in Finder or Explorer. Requires `REVEAL_IN_FOLDER`. */
    function revealFile(ref:FileRef, onDone:(error:Dynamic) -> Void):Void;

/// Clipboard and shell

    function copyText(text:String, onDone:(error:Dynamic) -> Void):Void;

    /** Requires `CLIPBOARD_READ`. */
    function readText(onDone:(error:Dynamic, text:String) -> Void):Void;

    function openUrl(url:String, onDone:(error:Dynamic) -> Void):Void;

/// Window, all no-ops in a browser except the title and the zoom

    function showWindow():Void;

    function setWindowTitle(title:String):Void;

    function minimizeWindow():Void;

    function toggleMaximizeWindow():Void;

    function closeWindow():Void;

    /** Scales the whole interface. Implemented in both hosts. */
    function setZoom(factor:Float):Void;

    /**
     * Make [data-tauri-drag-region] elements move the window.
     *
     * This lives in the backend rather than in index.html so the one host page
     * works unchanged in both targets.
     */
    function installDragRegion():Void;

    /**
     * Report the OS window's state, once now and again on every change.
     *
     * The title bar needs it: on macOS it must leave room for the traffic
     * lights and reclaim that room in fullscreen, and elsewhere its maximise
     * button has to show which of the two things it will do.
     *
     * A browser has no such state and never calls back, which leaves the model
     * on its defaults of false. That is correct rather than a stub: a tab is
     * never maximised, and its fullscreen belongs to the user, not to us.
     */
    function onWindowStateChanged(callback:(fullscreen:Bool, maximized:Bool) -> Void):Void;

}
