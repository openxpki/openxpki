import Component from '@glimmer/component';
import { action } from "@ember/object";
import { guidFor } from '@ember/object/internals';
import { registerDestructor } from '@ember/destroyable';

import ChartPie from './chart-pie';
import ChartLineBar from './chart-line-bar';

/**
 * Draws a line, bar, or pie chart powered by uPlot.
 *
 * ```html
 * <OxiBase::Chart @data={{this.data}} @options={{this.options}} />
 * ```
 *
 * @param { array } data
 *   List of data rows, each row being an array where the first element is the
 *   X value (timestamp or category label) and the remaining elements are Y
 *   values for each series:
 *   `[ [x1, a1, b1, ...], [x2, a2, b2, ...], ... ]`
 *
 * @param { object } options - Display options for the chart:
 *
 *   **Layout**
 *   - `type` { string } - Chart type: `'line'` (default), `'bar'`, or `'pie'`
 *   - `width` { number|string } - Chart width in px, or `'auto'` to fill the container width. Default: `'auto'`
 *   - `height` { number|string } - Chart height in px, or `'auto'` to fill the container height. Default: `'auto'`
 *   - `title` { string } - Chart title shown above the plot. Default: `""`
 *   - `cssClass` { string } - Extra CSS class added to the uPlot root element. Default: `null`
 *
 *   **X axis** (line/bar only)
 *   - `x_is_timestamp` { boolean } - Treat X values as Unix timestamps (seconds).
 *     Default: `true`
 *   - `bar_vertical` { boolean } - Render bar chart with vertical bars (i.e. horizontal layout).
 *     Default: `false`
 *
 *   **Legend**
 *   - `legend_label` { boolean } - Show series labels in the legend.
 *     Default: `true` when `options.series` is provided, `false` otherwise
 *   - `legend_value` { boolean } - Show live data values at the cursor position in the legend
 *     (line/bar only). Default: `false`
 *   - `legend_position` { string } - Legend placement: `'bottom'` (default), `'right'`, or `'left'`
 *   - `legend_date_format` { string } - Date format string for the X value shown in the legend
 *     (line chart with `x_is_timestamp` only).
 *     Tokens: `{YYYY}` `{MM}` `{DD}` `{HH}` `{mm}` `{ss}`.
 *     Default: `'{YYYY}-{MM}-{DD}, {HH}:{mm}:{ss}'`
 *
 *   **Series** (array of per-series objects, one entry per data column after X)
 *   - `series` { array } - Series configuration. Each entry may contain:
 *     - `label` { string } - Series label shown in the legend. Default: `''`
 *     - `color` { string } - CSS color string for the stroke/fill. Default: auto-generated palette
 *     - `fill` { string } - Fill color (line chart only). Default: `color` at 10 % opacity
 *     - `line_width` { number } - Stroke width in CSS px (line chart only). Default: `1`
 *     - `scale` { string|Array } - Y scale to bind this series to.
 *       Use `'auto'` (default) for a shared auto-ranging scale, `'%'` for a 0–100 % scale,
 *       or a two-element array `[min, max]` to create a fixed-range scale.
 *
 * @class OxiBase::Chart
 */

export default class OxiChartComponent extends Component {
    guid;
    opt = {};
    seriesCount;

    constructor() {
        super(...arguments);

        this.guid = guidFor(this);

        this.seriesCount = this.args.data ? this.args.data[0].length - 1 : 0;

        /*
          Option defaults
        */
        const defaults = {
            width: 'auto',
            height: 'auto',
            title: "",
            cssClass: null,
            type: 'line',
            series: [],
            legend_label: (this.args.options.series ? true : false),
            // Only 'line' and 'bar' chart:
            legend_value: false,
            legend_date_format: '{YYYY}-{MM}-{DD}, {HH}:{mm}:{ss}',
            legend_position: 'bottom',
            x_is_timestamp: true,
            bar_vertical: false,
        };

        for (const key of Object.keys(defaults)) {
            this.opt[key] = this.args.options[key] ?? defaults[key];
        }

        /*
          Series option defaults
        */
        // Loops in 'bar' and 'pie' chart code need the series options to be
        // defined for all existing data series
        if (this.opt.series.length === 0) {
            for (let i = 0; i < this.seriesCount; i++) this.opt.series.push({})
        }

        let i = 0;
        let r = 1/this.seriesCount;
        this.opt.series = this.opt.series.map(
            ({
                label = '',
                // create a color palette
                color = `rgba(${Math.round(120-i*r*100)}, ${Math.round(150-i*r*150)}, ${Math.round(50+i*r*200)}, 1)`,
                fill,
                line_width = 1,
                scale = 'auto',
            }) => { i++; return { label, color, fill, line_width, scale } }
        );
    }

    @action
    async plot(element) {
        const type = this.args.options.type;

        if (type == 'line' || type == 'bar') {
            await ChartLineBar(element, this.opt, this.args.data);
        }
        else if (type == 'pie') {
            new ChartPie(element, this.opt, this.args.data);
        }
        else {
            throw new Error(`Unknown chart type '${type}'`);
        }

        if (element._uplotCleanup) {
            registerDestructor(this, () => element._uplotCleanup());
        }
        if (element._pieCleanup) {
            registerDestructor(this, () => element._pieCleanup());
        }
    }
}
