package kit.platform;

/**
 * Something a host may or may not be able to do.
 *
 * Query with `Platform.can(...)` and use the answer to DISABLE an affordance,
 * never to delete it. Keeping the same markup in both hosts keeps the virtual
 * DOM tree stable, and a disabled button with a tooltip explains the
 * limitation where a missing button would just look like a bug.
 */
enum abstract Capability(Int) {

    /**
     * File references carry a real path, and `writeTextFile` overwrites in
     * place. False in a browser, where saving always means a fresh download.
     */
    var FILE_SYSTEM;

    /** Minimise, maximise, close and drag the OS window. */
    var WINDOW_CONTROLS;

    /** An OS menu bar exists to install into. */
    var NATIVE_MENU;

    /** "Show in Finder" / "Show in Explorer". */
    var REVEAL_IN_FOLDER;

    /**
     * The clipboard can be READ without a user gesture. Writing works
     * everywhere, so it is not a capability.
     */
    var CLIPBOARD_READ;

}
