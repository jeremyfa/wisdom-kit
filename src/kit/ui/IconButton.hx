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

    /**
     * "default" (32px) or "small" (28px), which the title bar uses: its 36px
     * height leaves a default button no room around it.
     */
    @props var size:String = 'default';

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
            <Icon kind=${kind} size=${size == 'small' ? 14 : 15} display="" />
        </button>
    ';

    function classes():String {

        // Whole literals per size, because Tailwind reads source text.
        final box = size == 'small' ? 'w-7 h-7 rounded-md ' : 'w-8 h-8 rounded-lg ';
        final base = 'inline-flex items-center justify-center shrink-0 transition-colors ' + box;

        if (disabled) return base + 'text-t-text-faint cursor-not-allowed';
        if (active) return base + 'text-t-accent bg-t-accent-soft cursor-pointer';
        if (tone == 'danger') return base + 'text-t-text-muted hover:text-white hover:bg-t-danger cursor-pointer';
        return base + 'text-t-text-muted hover:text-t-text hover:bg-t-surface-2 cursor-pointer';

    }

}
