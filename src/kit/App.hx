package kit;

import kit.model.ChromeState;
import kit.model.Preferences;
import kit.model.RootModel;
import kit.model.Theme;
import js.Browser.document;
import js.Browser.window;
import tracker.Autorun;
import wisdom.HtmlBackend;
import wisdom.Wisdom;
import wisdom.modules.AttributesModule;
import wisdom.modules.ClassModule;
import wisdom.modules.ListenersModule;
import wisdom.modules.PropsModule;
import wisdom.modules.StyleModule;

using tracker.SaveModel;

/**
 * The application shell: everything that has to happen before your code can
 * run, in the order it has to happen.
 *
 * Your entry point builds a root model and calls `App.start`. Nothing in this
 * package knows what your application is.
 *
 *   1. platform:  everything else may need to ask what host this is
 *   2. model:     restore state before anything renders it
 *   3. theme:     publish colours before the first paint, so nothing flashes
 *   4. wisdom:    the virtual DOM engine
 *   5. container: mount the reactive root
 *   6. keyboard:  shortcuts last, once there is something to act on
 *
 * That order is not a style choice. Restoring the model after the first paint
 * shows the user a blank app that then fills in. Publishing the theme after it
 * shows them the wrong colours first.
 */
class App {

    /** Version, taken from package.json at compile time. */
    public static inline final VERSION:String = kit.macros.VersionMacro.get();

    public static var wisdom(default, null):Wisdom;

    public static var theme(default, null):Theme;

    /** The root model, as the shell sees it. Your code should use its own. */
    public static var model(default, null):RootModel;

    static var started:Bool = false;

    public static function start(options:AppOptions):Void {

        if (started) throw 'App.start() has already been called';
        started = true;

        Platform.init();
        initModel(options);
        initTheme();
        initWisdom();
        mount(options);

        Keys.install(options.bindings, options.onEscape);

        // The title bar is drawn by the app, so it has to know what the OS
        // window is doing. Wired here rather than inside the backend, because
        // a backend has no business knowing a model exists.
        Platform.onWindowStateChanged((fullscreen, maximized) -> {
            model.chrome.windowFullscreen = fullscreen;
            model.chrome.windowMaximized = maximized;
        });

        // The desktop window is created hidden so the user never sees an
        // unstyled frame, so reveal it once the first render has happened.
        model.chrome.appReady = true;
        Platform.showWindow();

    }

    static function initModel(options:AppOptions):Void {

        model = options.model;

        try {
            model.loadFromKey(options.storageKey, true);
            model.autoSaveAsKey(options.storageKey);
        }
        catch (e:Dynamic) {
            // Safari refuses localStorage on file:// URLs, and a browser in
            // private mode can too. Carry on in memory and say so rather than
            // failing to start.
            model.error = 'Settings cannot be saved in this browser';
            window.console.warn('Persistence unavailable: ' + Std.string(e));
        }

        repairAfterLoad();
        if (options.onModelLoaded != null) options.onModelLoaded();

    }

    /**
     * Put back anything the restored save did not provide.
     *
     * A save records the CLASS NAME of every sub-model it holds. Rename or
     * move one, say `app.model.Preferences` becoming `kit.model.Preferences`,
     * and the old save still names the old class. Tracker cannot resolve it,
     * so the field comes back null. Adding a sub-model to an existing app has
     * the same effect: saves written before it existed have no value for it.
     *
     * Neither throws. `loadFromKey` succeeds, and the app then dies on the
     * first read, in a webview with no console, showing a blank window. This
     * turns that into a lost preference, which is the right trade.
     *
     * Only the shell's own fields are repaired here, because they are the only
     * ones the shell can name. Guard your own sub-models the same way in your
     * root model if they matter before the first render.
     */
    static function repairAfterLoad():Void {

        if (model.preferences == null) model.preferences = new Preferences();
        if (model.chrome == null) model.chrome = new ChromeState();

    }

    static function initTheme():Void {

        theme = new Theme();
        theme.applyMode(model.preferences.themeMode);

        // One autorun publishes every colour as a CSS custom property. It
        // re-runs whenever a colour changes, which is what makes switching
        // presets instant with no component knowing about it.
        new Autorun(() -> theme.publish());

        // Re-resolve when the preference changes, and keep following the
        // system while the preference is AUTO.
        new Autorun(() -> {
            final mode = model.preferences.themeMode;
            Autorun.unobserve();
            theme.applyMode(mode);
            Autorun.reobserve();
        });

        try {
            window.matchMedia('(prefers-color-scheme: dark)')
                .addEventListener('change', (_) -> theme.applyMode(model.preferences.themeMode));
        }
        catch (e:Dynamic) {}

        new Autorun(() -> Platform.setZoom(model.preferences.uiScale));

        // Publish the macOS traffic-light inset as a CSS variable rather than
        // as reactive markup. This is deliberate: if the title bar read the
        // fullscreen state inside its own render, it would re-render on every
        // fullscreen change and re-insert the children the app passed it,
        // duplicating raw markup children. Driving a CSS variable from here
        // keeps the title bar's markup completely static, so it works with any
        // children and never scrambles them.
        new Autorun(() -> {
            final inset = (Platform.isDesktop() && Platform.isMac && !model.chrome.windowFullscreen)
                ? '74px' : '0px';
            Autorun.unobserve();
            document.documentElement.style.setProperty('--kit-titlebar-inset', inset);
            Autorun.reobserve();
        });

    }

    static function initWisdom():Void {

        wisdom = new Wisdom([
                ClassModule.module(),
                StyleModule.module(),
                PropsModule.module(),
                AttributesModule.module(),
                ListenersModule.module()
            ],
            new HtmlBackend()
        );

    }

    static function mount(options:AppOptions):Void {

        final id = options.container != null ? options.container : 'container';
        final element = document.getElementById(id);
        if (element == null) throw 'No element with id "$id" to mount into';

        wisdom.reactive(element, options.render);

    }

}
