package kit.model;

import js.Browser.document;
import js.Browser.window;
import tracker.Autorun;
import tracker.Model;

/**
 * The active colour palette, as a reactive model.
 *
 * Every field holds a CSS colour value, never a Tailwind class name. An
 * autorun set up in `App` reads them all and writes each one as a custom
 * property on <html>, and `src/app.css` aliases those properties into Tailwind's
 * @theme so `bg-t-surface` and friends exist.
 *
 * Presets are Haxe constants rather than JSON resources on purpose: reading a
 * bundled resource is a Tauri capability, and the web build has to theme
 * itself too. Constants also mean no async, so the first paint is already
 * correct.
 */
class Theme extends Model {

    /** True when the resolved appearance is dark. Drives `color-scheme`. */
    @observe public var dark:Bool = false;

/// Surfaces

    @observe public var background:String = '#ffffff';
    @observe public var surface:String = '#ffffff';
    @observe public var surface2:String = '#f4f4f5';
    @observe public var border:String = '#e4e4e7';
    @observe public var borderStrong:String = '#d4d4d8';

/// Text

    @observe public var text:String = '#18181b';
    @observe public var textMuted:String = '#52525b';
    @observe public var textFaint:String = '#a1a1aa';

/// Accent

    @observe public var accent:String = '#4f46e5';
    @observe public var accentText:String = '#ffffff';
    @observe public var accentHover:String = '#4338ca';
    @observe public var accentSoft:String = '#eef2ff';

/// Buttons

    @observe public var button:String = '#ffffff';
    @observe public var buttonBorder:String = '#d4d4d8';
    @observe public var buttonText:String = '#18181b';
    @observe public var buttonHover:String = '#f4f4f5';

/// Feedback

    @observe public var success:String = '#059669';
    @observe public var successSoft:String = '#d1fae5';
    @observe public var warning:String = '#d97706';
    @observe public var warningSoft:String = '#fef3c7';
    @observe public var danger:String = '#dc2626';
    @observe public var dangerSoft:String = '#fee2e2';

/// Chrome

    @observe public var scrollbarThumb:String = '#d4d4d8';
    @observe public var scrollbarThumbHover:String = '#a1a1aa';
    @observe public var popupShadow:String = '0 10px 40px rgba(0, 0, 0, .18)';

    public function new() {
        super();
    }

/// Presets

    public function applyLight():Void {

        dark = false;

        background = '#fafafa';
        surface = '#ffffff';
        surface2 = '#f4f4f5';
        border = '#e4e4e7';
        borderStrong = '#d4d4d8';

        text = '#18181b';
        textMuted = '#52525b';
        textFaint = '#a1a1aa';

        accent = '#4f46e5';
        accentText = '#ffffff';
        accentHover = '#4338ca';
        accentSoft = '#eef2ff';

        button = '#ffffff';
        buttonBorder = '#d4d4d8';
        buttonText = '#18181b';
        buttonHover = '#f4f4f5';

        success = '#059669';
        successSoft = '#d1fae5';
        warning = '#d97706';
        warningSoft = '#fef3c7';
        danger = '#dc2626';
        dangerSoft = '#fee2e2';

        scrollbarThumb = '#d4d4d8';
        scrollbarThumbHover = '#a1a1aa';
        popupShadow = '0 10px 40px rgba(24, 24, 27, .16)';

    }

    public function applyDark():Void {

        dark = true;

        background = '#0b0b0e';
        surface = '#141418';
        surface2 = '#1c1c22';
        border = '#27272e';
        borderStrong = '#3a3a44';

        text = '#f4f4f5';
        textMuted = '#a1a1aa';
        textFaint = '#71717a';

        accent = '#818cf8';
        accentText = '#16162a';
        accentHover = '#a5b4fc';
        accentSoft = '#1e1b4b';

        button = '#1c1c22';
        buttonBorder = '#3a3a44';
        buttonText = '#f4f4f5';
        buttonHover = '#27272e';

        success = '#34d399';
        successSoft = '#064e3b';
        warning = '#fbbf24';
        warningSoft = '#451a03';
        danger = '#f87171';
        dangerSoft = '#450a0a';

        scrollbarThumb = '#3a3a44';
        scrollbarThumbHover = '#52525b';
        popupShadow = '0 10px 40px rgba(0, 0, 0, .55)';

    }

    /** Resolve a mode against the system preference and apply the preset. */
    public function applyMode(mode:ThemeMode):Void {

        if (resolveDark(mode)) applyDark() else applyLight();

    }

    public static function resolveDark(mode:ThemeMode):Bool {

        return switch mode {
            case LIGHT: false;
            case DARK: true;
            case _: systemPrefersDark();
        }

    }

    public static function systemPrefersDark():Bool {

        try {
            return window.matchMedia('(prefers-color-scheme: dark)').matches;
        }
        catch (e:Dynamic) {
            return false;
        }

    }

/// Publishing

    /**
     * Write every colour to <html> as a custom property.
     *
     * Reads all fields first, then calls `unobserve()` before touching the
     * DOM, so the autorun depends on the colours and nothing else. Without
     * that split, anything read during the write phase would silently become a
     * dependency and the autorun could re-enter.
     */
    public function publish():Void {

        final values:Array<Array<String>> = [
            ['background', background],
            ['surface', surface],
            ['surface-2', surface2],
            ['border', border],
            ['border-strong', borderStrong],
            ['text', text],
            ['text-muted', textMuted],
            ['text-faint', textFaint],
            ['accent', accent],
            ['accent-text', accentText],
            ['accent-hover', accentHover],
            ['accent-soft', accentSoft],
            ['button', button],
            ['button-border', buttonBorder],
            ['button-text', buttonText],
            ['button-hover', buttonHover],
            ['success', success],
            ['success-soft', successSoft],
            ['warning', warning],
            ['warning-soft', warningSoft],
            ['danger', danger],
            ['danger-soft', dangerSoft],
            ['scrollbar-thumb', scrollbarThumb],
            ['scrollbar-thumb-hover', scrollbarThumbHover],
            ['popup-shadow', popupShadow]
        ];
        final isDark = dark;

        Autorun.unobserve();

        final root = document.documentElement;
        for (entry in values) root.style.setProperty('--t-' + entry[0], entry[1]);

        // Native widgets read this, not our custom properties.
        root.setAttribute('data-theme', isDark ? 'dark' : 'light');

        Autorun.reobserve();

    }

}
