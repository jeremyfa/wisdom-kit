package app;

import app.model.AppModel;
import kit.App;
import kit.AppOptions;
import wisdom.X;

/**
 * Entry point.
 *
 * Everything generic belongs to `kit` and is not repeated here: the init
 * order, persistence, the theme, the virtual DOM, the keyboard listener, the
 * window chrome, the settings popup. This file holds only what the shell
 * cannot know, which is the model, the storage key and the markup.
 *
 * `implements X` is what lets this class write wisdom markup.
 */
class Main implements X {

    static function main():Void {

        final model = new AppModel();

        // Made reachable as the ambient `model` before anything renders.
        @:privateAccess Shortcuts._model = model;

        App.start(({
            model: model,
            // APP_SLUG from project.config.sh.
            storageKey: App.SLUG,
            render: () -> '<>
                <div class="h-screen flex flex-col bg-t-background text-t-text">

                    <TitleBar>
                        // The title drags the window: TitleBar marks the whole
                        // bar data-tauri-drag-region="deep", so anything that
                        // is not a button moves the window. The button cluster
                        // on the right opts out, so its gaps do not drag either.
                        <div class="flex-1 min-w-0 flex items-center gap-2">
                            <Icon kind=${App.ICON} size=16 display="text-t-accent" />
                            <span class="text-[14px] font-semibold truncate">Wisdom App</span>
                            <div class="flex-1"></div>
                            <div class="flex items-center gap-1" data-tauri-drag-region="false">
                                <IconButton kind="settings" size="small"
                                            title=${'Settings (' + Keys.modifierLabel() + ',)'}
                                            onpress=${() -> chrome.settingsOpen = true} />
                            </div>
                        </div>
                    </TitleBar>

                    <div class="flex-1 min-h-0 overflow-y-auto scrollbar-themed">
                        <div class="max-w-[640px] mx-auto w-full px-5 py-6">
                            <h1 class="m-0 text-[19px] font-semibold tracking-tight">Wisdom App</h1>
                            <p class="m-0 mt-1 text-[13px] text-t-text-muted">
                                Your application goes here. The window, theme, platform and
                                primitives around it live in lib/wisdom-kit/src/kit and are
                                already working.
                            </p>
                        </div>
                    </div>

                    <StatusBar />

                    // Always mounted, hidden when there is nothing to show: a
                    // stable child count keeps wisdom matching nodes correctly
                    // across renders. The kit opens this on the settings
                    // shortcut and closes it on Escape. Your own settings go
                    // between its tags.
                    <div class=${chrome.settingsOpen ? "" : "hidden"}>
                        <if ${chrome.settingsOpen}>
                            <SettingsPopup />
                        </if>
                    </div>

                    // A separate slot, above the one before it. A question is
                    // usually raised from inside a popup and has to sit on top
                    // of the popup that raised it.
                    <div class=${chrome.dialog != null ? "" : "hidden"}>
                        <if ${chrome.dialog != null}>
                            <DialogPopup />
                        </if>
                    </div>

                </div>
            '
        } : AppOptions));

    }

}
