package kit.ui;

import wisdom.Component;

/**
 * A two-state toggle.
 *
 * Controlled: it holds no state of its own. The value comes in as a prop and
 * changes go out through `onChange`; the parent owns the truth and the
 * persistence. Every input primitive in this kit follows that rule, which is
 * what keeps state in one place instead of scattered through the tree.
 */
class Switch extends Component {

    @props var value:Bool = false;

    @props var ariaLabel:String = null;

    @props var onChange:(value:Bool) -> Void = null;

    function render() '<>
        <button
            type="button"
            role="switch"
            aria-checked=${value ? "true" : "false"}
            aria-label=${ariaLabel}
            onclick=${(_) -> if (onChange != null) onChange(!value)}
            class=${'relative w-10 h-6 rounded-full transition-colors cursor-pointer shrink-0 '
                + (value ? 'bg-t-accent' : 'bg-t-surface-2 border border-t-border')}
        >
            <span class=${'absolute top-1 left-1 w-4 h-4 rounded-full bg-white shadow transition-transform '
                + (value ? 'translate-x-4' : '')}></span>
        </button>
    ';

}
