package kit.ui;

import kit.Dialog;
import wisdom.Component;

/**
 * Renders whatever `ChromeState.dialog` currently holds.
 *
 * Mounted above the ordinary popups, because the thing that asks a question is
 * usually something you did inside one of them: a destructive button in a
 * settings screen needs its confirmation on top of that screen, not instead
 * of it.
 */
class DialogPopup extends Component {

    function render() '<>
        <Popup
            title=${chrome.dialog != null ? chrome.dialog.title : ''}
            layer="top"
            onClose=${() -> Dialog.dismiss()}
        >
            <div class="flex flex-col gap-4">
                <p class="m-0 text-[13px] leading-relaxed text-t-text-muted select-text">
                    ${chrome.dialog != null ? chrome.dialog.message : ''}
                </p>
                <div class="flex items-center justify-end gap-2">
                    <Button label="Cancel" onpress=${() -> Dialog.dismiss()} />
                    <Button label=${confirmLabel()} variant=${confirmVariant()}
                            onpress=${() -> Dialog.accept()} />
                </div>
            </div>
        </Popup>
    ';

    function confirmLabel():String {

        final request = chrome.dialog;
        return (request != null && request.confirmLabel != null) ? request.confirmLabel : 'OK';

    }

    function confirmVariant():String {

        final request = chrome.dialog;
        return (request != null && request.tone == 'danger') ? 'danger' : 'primary';

    }

}
