package kit.ui;

import wisdom.Component;

/**
 * A tinted note.
 *
 * `tone` selects the meaning: "info", "success", "warning" or "danger". The
 * tint is a `color-mix` of the tone colour so it works in both themes without
 * a second palette entry per tone.
 */
class InfoBox extends Component {

    @props var tone:String = 'info';

    @props var icon:String = null;

    function render() '<>
        <div class=${'flex items-start gap-2 px-3 py-2 rounded-lg text-[12.5px] leading-relaxed ' + toneClasses()}>
            <if ${icon != null}>
                <Icon kind=${icon} size=14 display="mt-[2px] shrink-0" />
            </if>
            <div class="min-w-0">$children</div>
        </div>
    ';

    function toneClasses():String {

        return switch tone {
            case 'success': 'bg-t-success-soft text-t-success';
            case 'warning': 'bg-t-warning-soft text-t-warning';
            case 'danger': 'bg-t-danger-soft text-t-danger';
            case _: 'bg-t-accent-soft text-t-accent';
        }

    }

}
