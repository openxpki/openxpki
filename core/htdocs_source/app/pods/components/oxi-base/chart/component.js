import Component from '@glimmer/component';
import { action } from "@ember/object";
import { debug } from '@ember/debug';
import { guidFor } from '@ember/object/internals';

import uPlot from 'uplot';
//import 'uplot/dist/uPlot.min.css';
//import wheelZoom from './chart/plugin-wheelzoom.js'

/**
...

```html
<OxiBase::Chart .../>
```

@module oxi-base/chart
@param list { array } - List of hashes defining the options.
*/
export default class OxiChartComponent extends Component {
    guid;
    options;
    data;

    // x - timestamp
    // y - BTC price
    // y - RSI
    // y - RSI MA

    constructor() {
        super(...arguments);

        this.guid = guidFor(this);
        /*
         * Options
         */
        // Evaluate given options and set defaults
        const {
            width = 400,
            height = 200,
            title = "",
            cssClass = "",
            x_is_timestamp = true,
            y_values = [],
            legend_label = true,
            legend_value = false,
            legend_date_format = '{YYYY}-{MM}-{DD}, {HH}:{mm}:{ss}',
        } = this.args.options;

        // assemble uPlot options
        let uplotOptions = {
            width,
            height,
            title,
            class: cssClass,
            legend: {
                show: legend_label,
                live: legend_value,
            },
            scales: {
                x: {
                    time: x_is_timestamp,
                },
            },
            series: [
                {}, // the x values !!
            ],
        };

        // set custom date format
        if (x_is_timestamp) {
            // format strings: https://github.com/leeoniya/uPlot/blob/1.6.3/src/fmtDate.js#L74
            let dateFormatter = uPlot.fmtDate(legend_date_format);
            uplotOptions.series[0].value = (self, rawValue) => rawValue == null ? "-" : dateFormatter(new Date(rawValue * 1000));
        }

        for (const graph of this.args.options.y_values) {
            const {
                label = '',
                scale = undefined,
                color = undefined,
                line_width = 1,
            } = graph;

            uplotOptions.series.push({
                label,
                scale,
                stroke: color,
                width: line_width/window.devicePixelRatio,
                //value: (self, rawValue) => rawValue == null ? "-" : rawValue.toFixed(0),
            });
        }

        this.options = uplotOptions;

        /*
         * Convert data from
         * from [ [x1, price1, rsi1], [x2, price2, rsi2] ]
         *   to [ [x1, x2], [price1, price2], [rsi1, rsi2] ]
         */
        this.data = [];
        for (let i=0; i<this.args.data[0].length; i++) {
            this.data.push(this.args.data.map(row => +row[i]));
        }
    }

    @action
    plot(element) {
        // new uPlot(this.options, this.data, (uplot, init) => {
        new uPlot(this.options, this.data, (uplot, init) => {
            element.appendChild(uplot.root);
            init();
        })
    }
}
