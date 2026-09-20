package kit;

import kit.model.RootModel;
import wisdom.VNode;

/** Everything the shell needs from your application. See `kit.App.start`. */
typedef AppOptions = {

    /**
     * Your root model, already constructed. It is loaded from storage and put
     * under auto-save by the shell, so hand it over empty.
     */
    var model:RootModel;

    /**
     * localStorage key holding the whole serialized graph. Distinct per app:
     * two apps served from the same origin would otherwise overwrite each
     * other.
     */
    var storageKey:String;

    /**
     * The root of your interface. Called inside a reactive context, so
     * whatever it reads is what makes it re-render.
     */
    var render:() -> VNode;

    /**
     * Called once the model has been restored from storage and the shell has
     * repaired its own fields, and BEFORE anything renders.
     *
     * This is where you put back sub-models an older save did not provide.
     * It has to run here rather than after `start` returns, because the first
     * render happens inside `start` and would read them.
     */
    var ?onModelLoaded:() -> Void;

    /** Your shortcuts. The shell's own are prepended. */
    var ?bindings:Array<Binding>;

    /**
     * What Escape should do when no dialog is open, usually closing a popup.
     * Return true when you handled it.
     */
    var ?onEscape:() -> Bool;

    /** id of the element to mount into. Defaults to "container". */
    var ?container:String;

};
