package kit;

import js.Browser.document;
import js.html.Element;
import js.html.KeyboardEvent;

/**
 * Keyboard shortcuts: one listener, one table.
 *
 * The shell owns the dispatching and a few bindings that belong to any app
 * (the zoom). Your application passes its own table to `App.start` and they
 * are concatenated, so `Keys.all` is what the About screen should list.
 *
 * Three rules are enforced here rather than left to each binding, because
 * getting any of them wrong is the kind of bug you only notice from a user
 * report:
 *
 *   A text field has priority. While one has focus, nothing but Escape fires,
 *   so typing never triggers a shortcut and the browser's own character-level
 *   undo keeps working inside the field.
 *
 *   A dialog is modal. While one is open, Escape dismisses it and everything
 *   else is swallowed, so nothing behind it can act.
 *
 *   Escape unwinds one layer at a time, innermost first.
 */
class Keys {

    /** Every binding in effect, the shell's own first. */
    public static var all(default, null):Array<Binding> = [];

    /**
     * Install the listener.
     *
     * Called by `App.start`; you should not need to call it yourself.
     */
    public static function install(?appBindings:Array<Binding>, ?onEscape:() -> Bool):Void {

        all = builtins().concat(appBindings != null ? appBindings : []);
        escapeHandler = onEscape;
        document.addEventListener('keydown', onKeyDown);

    }

    /**
     * What the app wants done when Escape is pressed and no dialog is open.
     * Returns true when it handled it. Closing a popup is the usual case.
     */
    static var escapeHandler:() -> Bool = null;

    /** Shortcuts every application wants, so no application has to write them. */
    static function builtins():Array<Binding> {

        return [
            { key: '=', description: 'Zoom in', action: () -> adjustScale(0.1) },
            { key: '-', description: 'Zoom out', action: () -> adjustScale(-0.1) },
            { key: '0', description: 'Reset zoom', action: () -> preferences.uiScale = 1.0 }
        ];

    }

    static function onKeyDown(e:KeyboardEvent):Void {

        final active:Element = cast document.activeElement;

        if (active != null && isTextField(active)) {
            // Only Escape is ours inside a field. Everything else, undo
            // included, belongs to the field.
            if (e.key == 'Escape') active.blur();
            return;
        }

        if (chrome.dialog != null) {
            // Modal: the dialog is the only thing that can act.
            if (e.key == 'Escape') {
                Dialog.dismiss();
                e.preventDefault();
            }
            return;
        }

        if (e.key == 'Escape' && escapeHandler != null && escapeHandler()) {
            e.preventDefault();
            return;
        }

        final modifierHeld = Platform.isMac ? e.metaKey : e.ctrlKey;

        for (binding in all) {
            if (binding.key != e.key.toLowerCase()) continue;
            if ((binding.modifier != false) != modifierHeld) continue;
            if ((binding.shift == true) != e.shiftKey) continue;

            binding.action();
            e.preventDefault();
            return;
        }

    }

    static function adjustScale(delta:Float):Void {

        preferences.uiScale = clampScale(preferences.uiScale + delta);

    }

    /** The range the interface stays legible in. Shared with the settings UI. */
    public static function clampScale(value:Float):Float {

        var next = value;
        if (next < 0.5) next = 0.5;
        if (next > 2.0) next = 2.0;
        return Math.round(next * 100) / 100;

    }

    static function isTextField(el:Element):Bool {

        final tag = el.tagName.toLowerCase();
        if (tag == 'input' || tag == 'textarea' || tag == 'select') return true;
        return el.getAttribute('contenteditable') == 'true';

    }

    /**
     * The modifier symbol to show in menus and tooltips.
     *
     * Which operating system this is comes from `Platform.isMac`, because it
     * is a fact about the machine rather than about the keyboard, and the
     * title bar needs the same answer to decide where the window buttons go.
     */
    public static function modifierLabel():String {

        return Platform.isMac ? '⌘' : 'Ctrl+';

    }

    /** How a binding should be written out in a shortcuts list. */
    public static function label(binding:Binding):String {

        final prefix = binding.modifier != false ? modifierLabel() : '';
        final shift = binding.shift == true ? (Platform.isMac ? '⇧' : 'Shift+') : '';
        return prefix + shift + binding.key.toUpperCase();

    }

}
