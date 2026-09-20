package kit.model;

/**
 * Settings the user chose, kept across sessions.
 *
 * Everything here is `@serialize`, which in tracker implies `@observe` as
 * well: changing a field both re-renders what depends on it and schedules a
 * save.
 */
class Preferences extends BaseModel {

    /** Light, dark, or follow the system. */
    @serialize public var themeMode:ThemeMode = AUTO;

    /** Interface scale, 1.0 being 100%. */
    @serialize public var uiScale:Float = 1.0;

    public function new() {
        super();
    }

}
