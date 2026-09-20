package kit.ui;

import wisdom.Component;

/**
 * A labelled button, optionally with a leading icon.
 *
 * `variant` picks the surface: "default" for ordinary actions, "primary" for
 * the one action a screen is about, "danger" for destructive ones.
 *
 * Class strings are whole literals in every branch. Tailwind finds class names
 * by scanning source text, so a class assembled by concatenation would never
 * reach the stylesheet.
 */
class Button extends Component {

    @props var label:String = '';

    @props var icon:String = null;

    @props var variant:String = 'default';

    @props var disabled:Bool = false;

    /** Shown on hover, and used as the accessible name when there is no label. */
    @props var title:String = null;

    @props var onpress:() -> Void = null;

    function render() '<>
        <button
            type="button"
            title=${title}
            aria-label=${label != '' ? label : title}
            disabled=${disabled}
            onclick=${(_) -> if (!disabled && onpress != null) onpress()}
            class=${classes()}
        >
            <if ${icon != null}>
                <Icon kind=${icon} size=15 display="" />
            </if>
            <if ${label != null && label != ''}>
                <span>${label}</span>
            </if>
        </button>
    ';

    function classes():String {

        final base = 'inline-flex items-center justify-center gap-1.5 h-8 px-3 rounded-lg '
            + 'text-[13px] font-medium transition-colors ';

        if (disabled) {
            return base + 'border border-t-border bg-t-surface text-t-text-faint cursor-not-allowed';
        }

        return base + switch variant {
            case 'primary':
                'bg-t-accent text-t-accent-text hover:bg-t-accent-hover cursor-pointer';
            case 'danger':
                'border border-t-danger text-t-danger hover:bg-t-danger-soft cursor-pointer';
            case _:
                'border border-t-button-border bg-t-button text-t-button-text hover:bg-t-button-hover cursor-pointer';
        }

    }

}
