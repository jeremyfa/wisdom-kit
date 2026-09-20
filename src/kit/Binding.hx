package kit;

/** One keyboard shortcut, as declared in a table. See `kit.Keys`. */
typedef Binding = {

    /** Lowercase key, as reported by KeyboardEvent.key. */
    var key:String;

    /** Shown in the shortcuts list. */
    var description:String;

    var action:() -> Void;

    /**
     * Requires the platform modifier: Command on macOS, Control elsewhere.
     * Defaults to true, because almost every shortcut should.
     */
    var ?modifier:Bool;

    var ?shift:Bool;

};
