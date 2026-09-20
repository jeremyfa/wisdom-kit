package kit.ui;

import wisdom.Component;

/**
 * One glyph from the bundled Lucide icon font.
 *
 * Renders an `<i>` carrying the class `icon-{kind}`, which the font's
 * stylesheet turns into a glyph. All 1615 Lucide names are available. Browse
 * them at https://lucide.dev.
 *
 * Colour is INHERITED: style the parent (`text-t-accent`), never the icon.
 * That way an icon inside a button automatically follows the button's hover
 * and disabled states with no extra wiring.
 */
class Icon extends Component {

    /** Lucide icon name, e.g. "plus", "trash-2", "folder-open". */
    @props var kind:String = 'circle';

    /** Size in pixels, applied as font-size. */
    @props var size:Int = 16;

    /** Extra classes on the element, for spacing or opacity. */
    @props var display:String = '';

    function render() '<>
        <i
            class=${'icon-' + kind + ' leading-none ' + display}
            style=${{ fontSize: size + 'px' }}
            aria-hidden="true"
        ></i>
    ';

}
