package kit.ui;

import js.html.Event;
import js.html.SelectElement;
import wisdom.Component;

/**
 * A styled native `<select>`.
 *
 * Native rather than a custom menu: it gets keyboard navigation, type-ahead,
 * and the platform's own touch and accessibility behaviour for free.
 *
 * The current choice is expressed with `selected` on each option rather than
 * `value` on the select. Properties are applied before children are attached,
 * so a `value` set at creation time would refer to options that do not exist
 * yet and would be silently dropped.
 */
class Dropdown extends Component {

    @props var value:String = '';

    @props var options:Array<DropdownOption> = [];

    @props var ariaLabel:String = null;

    @props var onChange:(value:String) -> Void = null;

    function render() '<>
        <select
            aria-label=${ariaLabel}
            onchange=${(e) -> emit(e)}
            class="h-8 px-2 rounded-lg border border-t-button-border bg-t-button text-t-button-text text-[13px] outline-none focus:border-t-accent cursor-pointer"
        >
            <foreach ${options} ${(_:Int, option:DropdownOption) -> '<>
                <option key=${option.value} value=${option.value} selected=${option.value == value}>
                    ${option.label}
                </option>
            '} />
        </select>
    ';

    function emit(e:Event):Void {

        if (onChange == null) return;
        final el:SelectElement = cast e.target;
        onChange(el.value);

    }

}
