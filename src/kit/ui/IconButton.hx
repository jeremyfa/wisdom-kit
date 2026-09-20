package kit.ui;

import wisdom.Component;

/** A square icon-only button, for toolbars and dense rows. */
class IconButton extends Component {

    @props var kind:String = 'circle';

    /** Required: with no label, this is the accessible name. */
    @props var title:String = '';

    @props var disabled:Bool = false;

    @props var active:Bool = false;

    /**
     * Whether to set the native `title` attribute.
     *
     * Turn it off when the button is wrapped in a `Tooltip`, or both labels
     * would show wherever the native one works. The accessible name stays,
     * because that is what a screen reader reads.
     */
    @props var nativeTitle:Bool = true;

    /**
     * "default" or "danger". Danger turns the button red on hover, which is
     * what a window's close button does on Windows and Linux.
     */
    @props var tone:String = 'default';

    @props var onpress:() -> Void = null;

    function render() '<>
        <button
            type="button"
            title=${nativeTitle ? title : null}
            aria-label=${title}
            aria-pressed=${active ? "true" : "false"}
            disabled=${disabled}
            onclick=${(_) -> if (!disabled && onpress != null) onpress()}
            class=${classes()}
        >
            <Icon kind=${kind} size=15 display="" />
        </button>
    ';

    function classes():String {

        final base = 'inline-flex items-center justify-center w-8 h-8 shrink-0 rounded-lg transition-colors ';

        if (disabled) return base + 'text-t-text-faint cursor-not-allowed';
        if (active) return base + 'text-t-accent bg-t-accent-soft cursor-pointer';
        if (tone == 'danger') return base + 'text-t-text-muted hover:text-white hover:bg-t-danger cursor-pointer';
        return base + 'text-t-text-muted hover:text-t-text hover:bg-t-surface-2 cursor-pointer';

    }

}
