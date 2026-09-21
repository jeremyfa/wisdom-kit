package kit.ui;

import wisdom.Component;

/**
 * A thin strip at the bottom: which host we are in, the version, and whatever
 * the shell has to say. Anything your application wants to show there is
 * passed as children and lands on the right.
 *
 * EVERY LABEL SITS IN ONE `items-baseline` ROW, which matters because the row
 * mixes the monospace and the sans faces. `items-center` centres each item's
 * BOX, and two fonts at the same size produce boxes of the same height with
 * the baseline in a different place inside them, so the text ends up about a
 * pixel out of line. Aligning on the baseline is what the eye actually reads.
 * The outer row still centres that group inside the bar.
 *
 * EACH LABEL IS TRIMMED TO ITS INK with `text-box: trim-both ex alphabetic`,
 * set on the label itself: the property acts on an element's own line boxes,
 * so on the flex row it would do nothing.
 * A line box is sized from the font's ascent and descent, and those include
 * room for accents above and a generous descender below, so centring the box
 * puts the letters visibly below the middle of the bar. WebKit and Chromium
 * also read those metrics from different font tables, so the same markup
 * sits at different heights in the two engines. Trimming the box to the
 * x-height and the baseline leaves only the ink, and centring that is what
 * reads as centred. Engines without `text-box` ignore it and fall back to
 * the `leading-none` line box, which is the closest approximation.
 *
 * The flash message slot is always in the DOM and merely empty when there is
 * nothing to say, so appearing and disappearing never changes the child count
 * and wisdom keeps matching nodes across renders.
 */
class StatusBar extends Component {

    function render() '<>
        <div class="shrink-0 flex items-center h-7 px-4 border-t border-t-border bg-t-surface text-[11.5px] text-t-text-muted">
            <div class="flex-1 min-w-0 flex items-baseline gap-3 leading-none">
                <span class="mono shrink-0 [text-box:trim-both_ex_alphabetic]">${Platform.isDesktop() ? 'desktop' : 'web'}</span>
                <span class="shrink-0 text-t-text-faint [text-box:trim-both_ex_alphabetic]">v${App.VERSION}</span>
                <span class="flex-1 min-w-0 truncate text-t-success [text-box:trim-both_ex_alphabetic]">
                    ${chrome.message != null ? chrome.message : ''}
                </span>
                $children
            </div>
        </div>
    ';

}
