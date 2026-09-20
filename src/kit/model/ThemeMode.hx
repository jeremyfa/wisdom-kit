package kit.model;

/** Which appearance the user asked for. */
enum abstract ThemeMode(String) from String to String {

    /** Follow the operating system. The default. */
    var AUTO = 'auto';

    var LIGHT = 'light';

    var DARK = 'dark';

}
