package kit.platform;

/** A file that has been picked and read in one step. */
@:structInit
class OpenedFile {

    public var ref:FileRef;

    public var content:String;

    public function new(ref:FileRef, content:String) {
        this.ref = ref;
        this.content = content;
    }

}
