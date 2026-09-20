package kit.platform;

/**
 * A file the app has opened or saved.
 *
 * Deliberately opaque about location. The reference implementation this kit is
 * modelled on is path-oriented: its picker returns a String path that you read
 * later. A browser never has a path, so that shape cannot be made to work in
 * both hosts.
 *
 * Here `path` is null in a browser and set on the desktop. UI code should show
 * `name`, and only reach for `path` after checking
 * `Platform.can(FILE_SYSTEM)`.
 */
@:structInit
class FileRef {

    /** File name with extension, e.g. "notes.json". Always present. */
    public var name:String;

    /** Absolute path, or null when the host has no filesystem. */
    public var path:String = null;

    public function new(name:String, ?path:String) {
        this.name = name;
        this.path = path;
    }

    /** True when this reference can be written to in place. */
    public function isWritableInPlace():Bool {
        return path != null;
    }

    public function toString():String {
        return path != null ? path : name;
    }

}
