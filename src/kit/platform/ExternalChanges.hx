package kit.platform;

import haxe.crypto.Md5;

/**
 * Noticing that the open file was changed by another program, and offering
 * to reload it. Off until an application turns it on with `watch`.
 *
 * The file is read again when the application starts and each time its
 * window comes back to the front, which is when an outside edit can have
 * happened: no file watcher, so no extra permission, and no need to tell the
 * application's own saves apart from someone else's.
 *
 * What the disk held last is remembered as a hash the application keeps,
 * usually in a serialized model so it survives a restart. Set it when a file
 * is opened or saved (`hash(content)`), and a later difference can only come
 * from outside.
 *
 * Desktop only: a browser cannot read a file again. `watch` does nothing
 * without `FILE_SYSTEM`.
 */
class ExternalChanges {

    static var options:ExternalChangesOptions = null;

    static var reading:Bool = false;

    /**
     * Turn the checks on, and run the first one now. Calling it again only
     * replaces the options.
     */
    public static function watch(options:ExternalChangesOptions):Void {

        if (!Platform.can(FILE_SYSTEM)) return;

        final first = ExternalChanges.options == null;
        ExternalChanges.options = options;
        if (first) {
            window.addEventListener('focus', _ -> check());
            document.addEventListener('visibilitychange', _ -> if (!document.hidden) check());
        }
        check();

    }

    /** The hash to remember for `content`: what `known` returns and `setKnown` takes. */
    public static function hash(content:String):String {

        return Md5.encode(content);

    }

    /**
     * Read the file again and ask when it changed. Focus and visibility often
     * fire together: a check already reading, or a question already shown,
     * makes the next one wait for the following focus.
     */
    public static function check():Void {

        if (options == null || reading || chrome.dialog != null) return;

        final ref = options.file();
        if (ref == null || ref.path == null) return;

        reading = true;
        Platform.readTextFile(ref, (error, content) -> {
            reading = false;

            // Deleted or moved: nothing to offer, and saving writes it back.
            if (error != null || content == null) return;

            // Another file may have been opened while this one was read.
            final current = options.file();
            if (current == null || current.path != ref.path) return;

            final hash = hash(content);
            final known = options.known();
            if (hash == known) return;

            // Remembered before asking, so the answer holds until the file
            // changes again, whichever it is. With no hash yet (a file opened
            // before the application used this), the disk is taken as known.
            options.setKnown(hash);
            if (known == null) return;

            ask(ref, content);
        });

    }

    static function ask(ref:FileRef, content:String):Void {

        final unsaved = options.unsaved();
        Dialog.confirm(
            'File changed',
            unsaved
                ? '"${ref.name}" changed on disk. Reload it and lose your unsaved changes?'
                : '"${ref.name}" changed on disk. Reload it?',
            'Reload',
            () -> options.reload(content),
            unsaved ? 'danger' : 'default'
        );

    }

}

typedef ExternalChangesOptions = {

    /** The open file, or null when there is none. */
    var file:() -> FileRef;

    /** The hash of what the disk held last, as far as the application knows. */
    var known:() -> String;

    var setKnown:(hash:String) -> Void;

    /** Whether reloading would lose changes. */
    var unsaved:() -> Bool;

    /** Replace what is open with `content`, read from the file. */
    var reload:(content:String) -> Void;

}
