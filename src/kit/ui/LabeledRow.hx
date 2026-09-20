package kit.ui;

import wisdom.Component;

/** A label on the left, a control on the right. The settings-form building block. */
class LabeledRow extends Component {

    @props var label:String = '';

    /** Optional second line explaining the setting. */
    @props var hint:String = null;

    function render() '<>
        <div class="flex items-center justify-between gap-4 py-1.5">
            <div class="min-w-0">
                <div class="text-[13px] text-t-text">${label}</div>
                <if ${hint != null}>
                    <div class="text-[12px] text-t-text-muted">${hint}</div>
                </if>
            </div>
            <div class="shrink-0">$children</div>
        </div>
    ';

}
