package kit.ui;

import wisdom.Component;

/**
 * The window's title bar. On the desktop it IS the title bar: the OS draws no
 * chrome of its own.
 *
 * This component owns only what belongs to the window: dragging, the space
 * the macOS traffic lights need, and the minimise/maximise/close buttons the
 * other systems expect. What goes IN the bar is your application's business
 * and arrives as children.
 *
 * Two shapes, following each platform's own convention rather than inventing
 * a third:
 *
 *   macOS keeps its native traffic lights, floated over this bar by
 *   `titleBarStyle: "Overlay"`. We only have to leave room for them on the
 *   left, and take that room back in fullscreen, where the system hides them.
 *
 *   Windows and Linux get a genuinely undecorated window, so the buttons are
 *   ours to draw, on the right, where those systems put them.
 *
 * In a browser there is no window to control and neither applies: no inset, no
 * buttons, and the bar is just a header.
 *
 * `data-tauri-drag-region="deep"` makes the whole strip, including its
 * children, drag the window, and does nothing in a browser. Tauri handles this
 * natively: buttons, links and inputs are excluded automatically, so a plain
 * title or icon is draggable with no extra markup. To make a whole cluster
 * non-draggable, gaps included, put `data-tauri-drag-region="false"` on it,
 * the way the window-button group below does.
 */
class TitleBar extends Component {

    /**
     * Optional text centred on the whole bar, whatever sits on either side:
     * typically the name of the open document, the way native windows centre
     * their title. Null shows nothing.
     *
     * It ignores the pointer, so the bar still drags from under it, and it
     * never takes more than a third of the bar, so it cannot run into the
     * content at either end.
     */
    @props var centerTitle:String = null;

    function render() '<>
        <div
            data-tauri-drag-region="deep"
            class="relative shrink-0 flex items-center gap-2 px-3 h-12 border-b border-t-border bg-t-surface"
        >
            // Room for the macOS traffic lights, which float over this bar.
            // Kept as a real element rather than as padding on the container,
            // so that it simply disappears in fullscreen and everything slides
            // left with nothing else moving.
            //
            // Always mounted, only hidden: removing it would shift every child
            // after it by one, and wisdom would then match those children to
            // the wrong nodes, losing the first one in fullscreen.
            <div class=${needsTrafficLightInset() ? "w-[74px] shrink-0" : "hidden"}></div>

            $children

            // Always mounted too, for the same reason.
            <div class=${centerTitle != null ? "absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 max-w-[33%] truncate text-[13px] text-t-text-muted pointer-events-none" : "hidden"}>
                ${centerTitle != null ? centerTitle : ""}
            </div>

            <if ${needsWindowButtons()}>
                <div class="flex items-center gap-1 ml-2 pl-2 border-l border-t-border" data-tauri-drag-region="false">
                    <IconButton kind="minus" title="Minimize"
                                onpress=${() -> Platform.minimizeWindow()} />
                    <IconButton kind=${chrome.windowMaximized ? "copy" : "square"}
                                title=${chrome.windowMaximized ? "Restore" : "Maximize"}
                                onpress=${() -> Platform.toggleMaximizeWindow()} />
                    <IconButton kind="x" title="Close" tone="danger"
                                onpress=${() -> Platform.closeWindow()} />
                </div>
            </if>
        </div>
    ';

    /**
     * macOS only, and only while the traffic lights are actually on screen.
     *
     * The numbers here and in tauri.conf.json are a matched pair, measured
     * against this bar's 48px height rather than guessed:
     *
     *   trafficLightPosition x=14  puts the buttons at x 14..73
     *   this 74px spacer + the bar's 12px of padding + an 8px gap
     *                              puts the content at x 94, a clear 20px away
     *   trafficLightPosition y=26  centres the buttons at y 23.8, against a
     *                              bar centre of 24
     *
     * That y is NOT the top of the buttons. macOS applies it as an offset
     * from its own default, so it reads about nine pixels higher than the
     * number suggests. Change this bar's height and it has to be re-measured,
     * not recomputed.
     */
    function needsTrafficLightInset():Bool {

        return Platform.isDesktop() && Platform.isMac && !chrome.windowFullscreen;

    }

    /**
     * Absent rather than disabled in a browser and on macOS: on macOS the real
     * ones are on the left, and in a tab there is nothing they could do.
     */
    function needsWindowButtons():Bool {

        return Platform.can(WINDOW_CONTROLS) && !Platform.isMac;

    }

}
