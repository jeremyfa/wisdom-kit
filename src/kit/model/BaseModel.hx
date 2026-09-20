package kit.model;

import tracker.Model;

/**
 * Base class for every model in the app.
 *
 * Carries one thing: a slot for an error that belongs to this model. Putting
 * it here rather than in a global lets the interface show the problem next to
 * the thing that has it, instead of in a banner far away from the cause.
 */
class BaseModel extends Model {

    /** Description of the last failure on this model, or null. */
    @observe public var error:String = null;

    public function new() {
        super();
    }

}
