package kit.ui;

import kit.model.ThemeMode;
import wisdom.Component;

/**
 * The settings every application built on the kit has: the theme and the
 * interface scale. Both are bound straight to `preferences`, which persists.
 *
 * Whether it is open is `chrome.settingsOpen`. `kit.Keys` sets it on the
 * settings shortcut and clears it on Escape, and the close button and the
 * backdrop clear it here, so an application only mounts this component:
 *
 * ```haxe
 * <div class=${chrome.settingsOpen ? "" : "hidden"}>
 *     <if ${chrome.settingsOpen}>
 *         <SettingsPopup />
 *     </if>
 * </div>
 * ```
 *
 * An application's own settings go between the tags and land below these,
 * usually starting with a `SectionHeader` of their own.
 */
class SettingsPopup extends Component {

    function render() '<>
        <Popup title="Settings" onClose=${() -> chrome.settingsOpen = false}>
            <div class="flex flex-col gap-3">

                <SectionHeader label="Appearance" />

                <LabeledRow label="Theme" hint="Auto follows your system setting">
                    <Dropdown
                        value=${preferences.themeMode}
                        ariaLabel="Theme"
                        options=${[
                            { value: 'auto',  label: 'Auto'  },
                            { value: 'light', label: 'Light' },
                            { value: 'dark',  label: 'Dark'  }
                        ]}
                        onChange=${(value) -> preferences.themeMode = (value:ThemeMode)}
                    />
                </LabeledRow>

                <LabeledRow label="Interface scale" hint=${scaleHint()}>
                    <div class="flex items-center gap-1">
                        <IconButton kind="minus" title="Smaller" onpress=${() -> nudge(-0.1)} />
                        <IconButton kind="rotate-ccw" title="Reset"
                                    onpress=${() -> preferences.uiScale = 1.0} />
                        <IconButton kind="plus" title="Larger" onpress=${() -> nudge(0.1)} />
                    </div>
                </LabeledRow>

                $children

            </div>
        </Popup>
    ';

    function scaleHint():String {

        return Std.string(Math.round(preferences.uiScale * 100)) + '%';

    }

    function nudge(delta:Float):Void {

        // The same clamp the zoom shortcuts use, so the two cannot disagree
        // about what counts as a legible range.
        preferences.uiScale = Keys.clampScale(preferences.uiScale + delta);

    }

}
