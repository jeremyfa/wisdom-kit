package kit;

import kit.model.DialogRequest;

/**
 * Asking the user something.
 *
 * ALWAYS IN-APP, NEVER NATIVE. One implementation, no pair of backends, and
 * it looks like the rest of the application in both hosts. A native dialog
 * would mean a Tauri path and a browser path, and `window.confirm` in
 * particular blocks the thread, ignores the theme, and is suppressed outright
 * by some browsers.
 *
 * The state lives in `ChromeState.dialog`, so a dialog is just another thing the
 * model says is true, and `DialogPopup` renders it.
 */
class Dialog {

    /** Ask, and run `onConfirm` if the user agrees. */
    public static function confirm(title:String, message:String, confirmLabel:String,
        onConfirm:() -> Void, tone:String = 'default'):Void {

        chrome.dialog = {
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            tone: tone,
            onConfirm: onConfirm
        };

    }

    /** Tell the user something. One button, nothing happens after it. */
    public static function alert(title:String, message:String):Void {

        chrome.dialog = {
            title: title,
            message: message,
            confirmLabel: 'OK',
            tone: 'default',
            onConfirm: null
        };

    }

    public static function dismiss():Void {

        chrome.dialog = null;

    }

    /**
     * Close the dialog, then run its action.
     *
     * In that order: if the action opens another dialog, clearing afterwards
     * would throw the new one away.
     */
    public static function accept():Void {

        final request = chrome.dialog;
        if (request == null) return;

        chrome.dialog = null;
        if (request.onConfirm != null) request.onConfirm();

    }

}
