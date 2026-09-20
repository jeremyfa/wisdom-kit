package kit.platform;

import js.Browser.document;
import js.Browser.window;
import js.html.AnchorElement;
import js.html.Blob;
import js.html.FileReader;
import js.html.InputElement;
import js.html.URL;

/**
 * The browser implementation.
 *
 * Everything a page genuinely can do is done properly. Everything it cannot is
 * a documented no-op guarded by a `Capability`, never a silent failure.
 *
 * The one asymmetry worth understanding: a browser cannot write to a file the
 * user picked earlier, so `writeTextFile` degrades to a fresh download. The
 * app should ask `Platform.can(FILE_SYSTEM)` before offering a "Save" that
 * implies overwriting, and offer "Download" instead.
 */
class WebBackend implements PlatformBackend {

    public function new() {}

    public function kind():PlatformKind {
        return WEB;
    }

    public function can(capability:Capability):Bool {
        return switch capability {
            case FILE_SYSTEM: false;
            case WINDOW_CONTROLS: false;
            case NATIVE_MENU: false;
            case REVEAL_IN_FOLDER: false;
            // Reading the clipboard needs both a secure context and the user's
            // permission, so it is never assumed.
            case CLIPBOARD_READ: false;
        }
    }

    public function init():Void {}

/// Files

    public function openTextFile(filters:Array<FileFilter>, onDone:(error:Dynamic, file:OpenedFile) -> Void):Void {

        final input:InputElement = cast document.createElement('input');
        input.type = 'file';
        if (filters != null && filters.length > 0) {
            input.accept = [for (f in filters) f.toAccept()].join(',');
        }

        input.onchange = function(_) {
            if (input.files == null || input.files.length == 0) {
                onDone(null, null);
                return;
            }
            final file = input.files.item(0);
            final reader = new FileReader();
            reader.onload = function(_) {
                final text:String = cast reader.result;
                onDone(null, new OpenedFile(new FileRef(file.name), text));
            };
            reader.onerror = function(_) onDone(reader.error, null);
            reader.readAsText(file);
        };

        // A cancelled picker fires no event in most browsers, so the callback
        // simply never runs. Callers must treat "no answer" as "cancelled",
        // which is also how the desktop dialog behaves when dismissed.
        input.click();

    }

    public function saveTextFileAs(suggestedName:String, content:String, filters:Array<FileFilter>,
        onDone:(error:Dynamic, ref:FileRef) -> Void):Void {

        try {
            download(suggestedName, content);
            onDone(null, new FileRef(suggestedName));
        }
        catch (e:Dynamic) {
            onDone(e, null);
        }

    }

    public function writeTextFile(ref:FileRef, content:String, onDone:(error:Dynamic, ref:FileRef) -> Void):Void {

        // No filesystem, so "save" can only mean "download again".
        saveTextFileAs(ref != null ? ref.name : 'untitled.txt', content, null, onDone);

    }

    public function revealFile(ref:FileRef, onDone:(error:Dynamic) -> Void):Void {

        onDone('Showing a file in the file manager needs the desktop app');

    }

    function download(filename:String, content:String):Void {

        final blob = new Blob([content], cast { type: 'text/plain;charset=utf-8' });
        final url = URL.createObjectURL(blob);

        final a:AnchorElement = cast document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);

        window.setTimeout(() -> URL.revokeObjectURL(url), 0);

    }

/// Clipboard and shell

    public function copyText(text:String, onDone:(error:Dynamic) -> Void):Void {

        try {
            js.Syntax.code(
                "navigator.clipboard.writeText({0}).then(function(){ {1}(null); }).catch(function(e){ {1}(e); })",
                text, onDone
            );
        }
        catch (e:Dynamic) {
            onDone(e);
        }

    }

    public function readText(onDone:(error:Dynamic, text:String) -> Void):Void {

        onDone('Reading the clipboard is not available here', null);

    }

    public function openUrl(url:String, onDone:(error:Dynamic) -> Void):Void {

        try {
            // noopener matters: without it the opened page gets a handle on
            // this window through window.opener.
            window.open(url, '_blank', 'noopener,noreferrer');
            onDone(null);
        }
        catch (e:Dynamic) {
            onDone(e);
        }

    }

/// Window

    public function showWindow():Void {}

    public function setWindowTitle(title:String):Void {
        document.title = title;
    }

    public function minimizeWindow():Void {}

    public function toggleMaximizeWindow():Void {}

    public function closeWindow():Void {}

    public function setZoom(factor:Float):Void {

        // CSS zoom rather than a transform: it reflows, so layout and
        // scrollbars stay correct, which a scale transform would not do.
        document.documentElement.style.setProperty('zoom', Std.string(factor));

    }

    public function installDragRegion():Void {}

    public function onWindowStateChanged(callback:(fullscreen:Bool, maximized:Bool) -> Void):Void {

        // Never calls back, on purpose. A tab has no OS window state, and
        // reporting a made-up "not fullscreen, not maximised" would be the
        // same answer the model already holds, with more code to read.

    }

}
