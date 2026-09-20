package kit.ui;

import wisdom.Component;

/**
 * Minimise, maximise and close, for the platforms that expect the window
 * buttons drawn by the app (Windows and Linux).
 *
 * This is its own component on purpose. The maximise icon depends on
 * `chrome.windowMaximized`, which is reactive. Keeping that read here means
 * only this small component re-renders when the window is maximised, and the
 * title bar around it stays static and never re-inserts its children.
 */
class WindowButtons extends Component {

    function render() '<>
        <div class="flex items-center gap-1 ml-2 pl-2 border-l border-t-border" data-tauri-drag-region="false">
            <IconButton kind="minus" title="Minimize"
                        onpress=${() -> Platform.minimizeWindow()} />
            <IconButton kind=${chrome.windowMaximized ? "copy" : "square"}
                        title=${chrome.windowMaximized ? "Restore" : "Maximize"}
                        onpress=${() -> Platform.toggleMaximizeWindow()} />
            <IconButton kind="x" title="Close" tone="danger"
                        onpress=${() -> Platform.closeWindow()} />
        </div>
    ';

}
