package kit.model;

/**
 * A question the app is asking the user right now.
 *
 * Held in `ChromeState.dialog` and rendered by `DialogPopup`. There is one of
 * these at a time, on purpose: a second dialog stacked on the first is almost
 * always a sign that something should have been asked earlier or not at all.
 *
 * Build one through `kit.Dialog`, not by hand.
 */
typedef DialogRequest = {

    var title:String;

    var message:String;

    /** Label of the affirmative button. Defaults to "OK". */
    var ?confirmLabel:String;

    /** "default" or "danger". Danger colours the confirm button. */
    var ?tone:String;

    /** Run when the user confirms. Null makes this a plain acknowledgement. */
    var ?onConfirm:() -> Void;

};
