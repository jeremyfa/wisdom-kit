package kit.platform;

/** One entry of a file picker's type filter. */
@:structInit
class FileFilter {

    /** Shown in the native dialog, e.g. "JSON document". */
    public var name:String;

    /** Extensions without a dot, e.g. ["json"]. */
    public var extensions:Array<String>;

    public function new(name:String, extensions:Array<String>) {
        this.name = name;
        this.extensions = extensions;
    }

    /** The `accept` attribute form a browser file input expects. */
    public function toAccept():String {
        return [for (ext in extensions) '.' + ext].join(',');
    }

}
