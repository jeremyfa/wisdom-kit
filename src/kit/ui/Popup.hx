package kit.ui;

import js.html.MouseEvent;
import wisdom.Component;

/**
 * A modal shell: backdrop, titled header, scrollable body.
 *
 * Whether it is visible is the caller's business. This renders itself and
 * assumes it was mounted for a reason.
 *
 * The backdrop tracks press and release so that starting a drag inside the
 * dialog and finishing it on the backdrop does not close the dialog, which is
 * the usual way a modal eats a user's text selection.
 *
 * Escape is handled centrally in `KeyBindings`, so there is no per-popup
 * listener to install and, more importantly, none to forget to remove.
 */
class Popup extends Component {

    @props var title:String = '';

    @props var onClose:() -> Void = null;

    /**
     * "base" or "top". A dialog raised from inside another popup needs to sit
     * above it, and a stacking order is not something a component can work out
     * for itself.
     */
    @props var layer:String = 'base';

    var pressedBackdrop:Bool = false;

    function render() '<>
        <div
            class=${layerClasses()}
            onmousedown=${(e) -> onBackdropDown(e)}
            onclick=${(e) -> onBackdropClick(e)}
        >
            <div
                role="dialog"
                aria-modal="true"
                aria-label=${title}
                class="w-full max-w-[460px] rounded-xl border border-t-border bg-t-surface flex flex-col overflow-hidden max-h-[85vh]"
                style=${{ boxShadow: 'var(--t-popup-shadow)' }}
            >
                <div class="flex items-center justify-between gap-3 px-4 py-3 border-b border-t-border shrink-0">
                    <div class="text-[14px] font-semibold truncate">${title}</div>
                    <IconButton kind="x" title="Close" onpress=${() -> close()} />
                </div>

                <div class="px-4 py-3 overflow-y-auto scrollbar-themed select-text">
                    $children
                </div>
            </div>
        </div>
    ';

    function layerClasses():String {

        // Whole literals per branch, because Tailwind reads source text.
        final base = 'fixed inset-0 flex items-center justify-center px-6 ';
        return layer == 'top'
            ? base + 'z-[60] bg-black/35'
            : base + 'z-50 bg-black/45';

    }

    function onBackdropDown(e:MouseEvent):Void {

        pressedBackdrop = e.target == e.currentTarget;

    }

    function onBackdropClick(e:MouseEvent):Void {

        if (pressedBackdrop && e.target == e.currentTarget) close();
        pressedBackdrop = false;

    }

    function close():Void {

        if (onClose != null) onClose();

    }

}
