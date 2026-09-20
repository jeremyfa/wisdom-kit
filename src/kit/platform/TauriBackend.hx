package kit.platform;

import js.Browser.document;
import js.html.Element;
import js.html.MouseEvent;

/**
 * The Tauri desktop implementation.
 *
 * Calls go through `window.__TAURI__`, which exists because tauri.conf.json
 * sets `withGlobalTauri: true`. Raw `js.Syntax.code` is confined to this file:
 * application code never touches the Tauri API directly, which is exactly what
 * makes the web backend possible.
 *
 * Callbacks capture their arguments in local variables before entering the
 * injected JavaScript, because Haxe's `js.Syntax.code` cannot always place an
 * anonymous function where a statement is expected.
 */
class TauriBackend implements PlatformBackend {

    public function new() {}

    public function kind():PlatformKind {
        return TAURI;
    }

    public function can(capability:Capability):Bool {
        return switch capability {
            case FILE_SYSTEM: true;
            case WINDOW_CONTROLS: true;
            case NATIVE_MENU: true;
            case REVEAL_IN_FOLDER: true;
            case CLIPBOARD_READ: true;
        }
    }

    public function init():Void {
        installDragRegion();
    }

/// Files

    public function openTextFile(filters:Array<FileFilter>, onDone:(error:Dynamic, file:OpenedFile) -> Void):Void {

        final dialogFilters = toDialogFilters(filters);

        // Bound to a local FIRST. A `{N}` placeholder pastes the expression
        // itself into the JavaScript, so a lambda written inline at the call
        // site becomes `function (a, b) { … }(a, b)`, a function STATEMENT
        // with no name, which is a syntax error that only shows up at runtime.
        // Every callback handed to js.Syntax.code goes through a local.
        final onOpened = (path:String, content:String) -> {
            onDone(null, new OpenedFile(new FileRef(baseName(path), path), content));
        };

        js.Syntax.code("
            window.__TAURI__.dialog.open({ multiple: false, filters: {0} })
                .then(function (path) {
                    if (path == null) { {1}(null, null); return; }
                    window.__TAURI__.fs.readTextFile(path)
                        .then(function (content) { {2}(path, content); })
                        .catch(function (err) { {1}(err, null); });
                })
                .catch(function (err) { {1}(err, null); });
        ", dialogFilters, onDone, onOpened);

    }

    public function saveTextFileAs(suggestedName:String, content:String, filters:Array<FileFilter>,
        onDone:(error:Dynamic, ref:FileRef) -> Void):Void {

        final dialogFilters = toDialogFilters(filters);

        final onSaved = (path:String) -> {
            onDone(null, new FileRef(baseName(path), path));
        };

        js.Syntax.code("
            window.__TAURI__.dialog.save({ defaultPath: {0}, filters: {1} })
                .then(function (path) {
                    if (path == null) { {2}(null, null); return; }
                    window.__TAURI__.fs.writeTextFile(path, {3})
                        .then(function () { {4}(path); })
                        .catch(function (err) { {2}(err, null); });
                })
                .catch(function (err) { {2}(err, null); });
        ", suggestedName, dialogFilters, onDone, content, onSaved);

    }

    public function writeTextFile(ref:FileRef, content:String, onDone:(error:Dynamic, ref:FileRef) -> Void):Void {

        if (ref == null || ref.path == null) {
            saveTextFileAs(ref != null ? ref.name : 'untitled.txt', content, null, onDone);
            return;
        }

        final path = ref.path;
        final result = ref;

        js.Syntax.code("
            window.__TAURI__.fs.writeTextFile({0}, {1})
                .then(function () { {2}(null, {3}); })
                .catch(function (err) { {2}(err, null); });
        ", path, content, onDone, result);

    }

    public function revealFile(ref:FileRef, onDone:(error:Dynamic) -> Void):Void {

        if (ref == null || ref.path == null) {
            onDone('This file has not been saved yet');
            return;
        }

        js.Syntax.code("
            window.__TAURI__.opener.revealItemInDir({0})
                .then(function () { {1}(null); })
                .catch(function (err) { {1}(err); });
        ", ref.path, onDone);

    }

/// Clipboard and shell

    public function copyText(text:String, onDone:(error:Dynamic) -> Void):Void {

        js.Syntax.code("
            window.__TAURI__.clipboardManager.writeText({0})
                .then(function () { {1}(null); })
                .catch(function (err) { {1}(err); });
        ", text, onDone);

    }

    public function readText(onDone:(error:Dynamic, text:String) -> Void):Void {

        js.Syntax.code("
            window.__TAURI__.clipboardManager.readText()
                .then(function (text) { {0}(null, text); })
                .catch(function (err) { {0}(err, null); });
        ", onDone);

    }

    public function openUrl(url:String, onDone:(error:Dynamic) -> Void):Void {

        js.Syntax.code("
            window.__TAURI__.opener.openUrl({0})
                .then(function () { {1}(null); })
                .catch(function (err) { {1}(err); });
        ", url, onDone);

    }

/// Window

    public function showWindow():Void {
        js.Syntax.code("window.__TAURI__.window.getCurrentWindow().show()");
    }

    public function setWindowTitle(title:String):Void {
        document.title = title;
        js.Syntax.code("window.__TAURI__.window.getCurrentWindow().setTitle({0})", title);
    }

    public function minimizeWindow():Void {
        js.Syntax.code("window.__TAURI__.window.getCurrentWindow().minimize()");
    }

    public function toggleMaximizeWindow():Void {
        js.Syntax.code("window.__TAURI__.window.getCurrentWindow().toggleMaximize()");
    }

    public function closeWindow():Void {
        js.Syntax.code("window.__TAURI__.window.getCurrentWindow().close()");
    }

    public function setZoom(factor:Float):Void {
        js.Syntax.code("window.__TAURI__.webview.getCurrentWebview().setZoom({0})", factor);
    }

    /**
     * Window dragging is set up declaratively, not here.
     */
    public function installDragRegion():Void {

        // Nothing to do. Window dragging is handled natively by Tauri through
        // the `data-tauri-drag-region="deep"` attribute on the title bar (see
        // kit.ui.TitleBar). The native handler runs synchronously in the
        // webview, which is what actually starts the macOS window drag; a
        // manual mousedown listener calling startDragging() over IPC was tried
        // and does not reliably begin the drag when the click lands on a child
        // of the region.
    }


    /**
     * Report fullscreen and maximised state, now and on every change.
     *
     * Driven by the DOM `resize` event rather than by polling: entering
     * fullscreen, maximising, restoring and dragging an edge all resize the
     * webview, so that one event covers every transition. Polling would mean
     * two IPC round trips per frame forever, to learn nothing almost every
     * time.
     *
     * Debounced, because dragging an edge fires resize continuously and the
     * answer cannot change until the drag ends.
     */
    public function onWindowStateChanged(callback:(fullscreen:Bool, maximized:Bool) -> Void):Void {

        final report = callback;

        // Poll the window state and report only when it changes.
        //
        // A DOM resize listener was tried first and is not enough. Leaving
        // macOS fullscreen animates the window back, and during that the state
        // can still read as fullscreen while the resize fires. Once the
        // animation settles nothing fires again, so the title bar stays stuck
        // thinking it is fullscreen and never restores the traffic-light
        // inset. Polling is what Loreline Writer does, and it is reliable.
        //
        // Each frame waits for the previous query to resolve before scheduling
        // the next, so the IPC calls never pile up. The callback only runs on
        // a real change, so a steady window costs two reads per frame and
        // nothing else. requestAnimationFrame also pauses while the window is
        // hidden, which is exactly when no update is needed.
        //
        // The injected source starts on the SAME line as the quote: a `return`
        // before a line break is where JavaScript inserts a semicolon for you,
        // which would strand the rest as dead code.
        js.Syntax.code("(function () {
                    var w = window.__TAURI__.window.getCurrentWindow();
                    var lastFs = null, lastMax = null;
                    function tick() {
                        Promise.all([w.isFullscreen(), w.isMaximized()])
                            .then(function (state) {
                                if (state[0] !== lastFs || state[1] !== lastMax) {
                                    lastFs = state[0];
                                    lastMax = state[1];
                                    {0}(state[0], state[1]);
                                }
                                requestAnimationFrame(tick);
                            })
                            .catch(function () { requestAnimationFrame(tick); });
                    }
                    tick();
                })()", report);

    }

/// Internals

    /** Haxe file filters in the shape Tauri's dialog plugin expects. */
    function toDialogFilters(filters:Array<FileFilter>):Dynamic {

        if (filters == null || filters.length == 0) return null;
        return [for (f in filters) { name: f.name, extensions: f.extensions }];

    }

    function baseName(path:String):String {

        if (path == null) return '';
        final slash = path.lastIndexOf('/');
        final backslash = path.lastIndexOf('\\');
        final at = slash > backslash ? slash : backslash;
        return at >= 0 ? path.substr(at + 1) : path;

    }

}
