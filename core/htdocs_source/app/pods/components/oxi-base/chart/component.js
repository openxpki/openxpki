import Component from '@glimmer/component';
import { action } from "@ember/object";
import { guidFor } from '@ember/object/internals';

import ChartPie from './chart-pie';
import ChartLineBar from './chart-line-bar';

/**
 * Draws a line or bar chart.
 *
 * ```html
 * <OxiBase::Chart @data={{this.data}} @options={{this.options}} />
 * ```
 *
 * @param { array } data - list of data rows: `[ [x1, a1, b1, c1, ...], [x2, b2, c2, ...], ... ]`
 * @param { hash } options - display options for the chart
 * @module component/oxi-base/chart
 */

export default class OxiChartComponent extends Component {
    guid;
    opt = {};
    seriesCount;

    constructor() {
        super(...arguments);

        this.guid = guidFor(this);

        this.seriesCount = this.args.data[0].length - 1;

        /*
          Option defaults
        */
        const defaults = {
            width: 400,
            height: 200,
            title: "",
            cssClass: null,
            type: 'line',
            series: [],
            legend_label: (this.args.options.series ? true : false),
            // Only 'line' and 'bar' chart:
            legend_value: false,
            legend_date_format: '{YYYY}-{MM}-{DD}, {HH}:{mm}:{ss}',
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
    plot(element) {
        const type = this.args.options.type;

        if (type == 'line' || type == 'bar') {
            new ChartLineBar(element, this.opt, this.args.data);
        }
        else if (type == 'pie') {
            new ChartPie(element, this.opt, this.args.data);
        }
        else {
            throw new Error(`Unknown chart type '${type}'`);
        }
    }
}
