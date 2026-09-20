package app.model;

import kit.model.RootModel;

/**
 * The root of all application state.
 *
 * Extends `RootModel`, which is the seam with the shell: it already carries
 * `preferences` and `chrome`, the two things the shell needs, so everything
 * you declare here is genuinely yours.
 *
 * Sub-models are plain `@serialize` fields holding other models; tracker
 * serialises the whole graph under one key, so `Main` only has to persist this
 * one object.
 *
 * THE RULE THIS CODEBASE CANNOT BREAK: never mutate an observed array in
 * place. Observed collections are compared by identity, so `items.push(x)`
 * compiles, runs, and notifies nothing: no re-render and no save. Always
 * assign a NEW array. See the kit README.
 */
class AppModel extends RootModel {

    public function new() {
        super();
    }

}
