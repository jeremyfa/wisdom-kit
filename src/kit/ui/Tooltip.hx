package kit.ui;

import wisdom.Component;

/**
 * A themed hover label around whatever it wraps.
 *
 * WHY THIS EXISTS RATHER THAN A `title` ATTRIBUTE
 *
 * A disabled button receives no pointer events in any browser, so its native
 * `title` never appears. That is exactly the case where the explanation
 * matters most: the whole reason a control is disabled is something the user
 * cannot otherwise work out. Wrapping in a plain element, which is NOT
 * disabled, restores the hover.
 *
 * Elsewhere prefer `title`: it is free, it follows the platform's own timing,
 * and screen readers already know what to do with it.
 *
 * The bubble is always in the DOM and merely transparent, so appearing and
 * disappearing never changes the child count and wisdom keeps matching nodes
 * across renders.
 */
class Tooltip extends Component {

    @props var label:String = '';

    /** "top" or "bottom". Where the bubble sits relative to the content. */
    @props var side:String = 'bottom';

    function render() '<>
        <span class="relative inline-flex group">
            $children
            <span
                role="tooltip"
                class=${'pointer-events-none absolute left-1/2 -translate-x-1/2 z-[70] '
                    + 'whitespace-nowrap rounded-md px-2 py-1 text-[11.5px] '
                    + 'bg-t-surface-2 text-t-text border border-t-border '
                    + 'opacity-0 group-hover:opacity-100 transition-opacity '
                    + placement()}
            >${label}</span>
        </span>
    ';

    function placement():String {

        // Whole literals in both branches: Tailwind finds class names by
        // scanning source text, so a computed one would never be generated.
        return side == 'top' ? 'bottom-full mb-1.5' : 'top-full mt-1.5';

    }

}
