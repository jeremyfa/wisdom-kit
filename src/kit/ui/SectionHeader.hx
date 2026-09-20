package kit.ui;

import wisdom.Component;

/** A small uppercase heading separating groups of settings or content. */
class SectionHeader extends Component {

    @props var label:String = '';

    function render() '<>
        <div class="text-[10.5px] uppercase tracking-[.14em] text-t-text-faint">${label}</div>
    ';

}
