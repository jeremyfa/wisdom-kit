package kit.model;

/**
 * What every application's root model has to provide.
 *
 * Extend this rather than `BaseModel` for the ONE model you hand to
 * `App.start`. It carries the two things the shell needs to do its job, the
 * user's preferences and the shell's own transient state, so the shell can
 * be written once without knowing anything about your application.
 *
 * This is the seam between the two layers. `kit` knows a root model has
 * `preferences` and `chrome`. It knows nothing else about it, and it never
 * looks.
 */
class RootModel extends BaseModel {

    /** Settings the user chose. Persisted with the rest of the graph. */
    @serialize public var preferences:Preferences = new Preferences();

    /** The shell's own state. Nothing inside it actually persists. */
    @serialize public var chrome:ChromeState = new ChromeState();

    public function new() {
        super();
    }

}
