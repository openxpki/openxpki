import Component from '@glimmer/component';
import { action } from "@ember/object";
import { debug } from '@ember/debug';
import { guidFor } from '@ember/object/internals';

import uPlot from 'uplot';
import seriesBarsPlugin from './uplot/seriesbars-plugin';
import axisTimestampConfig from './uplot/axis-timestamp-config';
import reducedAlphaColor from './uplot/reduced-alpha-color';

/**
Draws a line or bar chart.

```html
<OxiBase::Chart @data={{this.data}} @options={{this.options}} />
```

@module oxi-base/chart
@param data { array } - list of data rows: `[ [x1, a1, b1, c1, ...], [x2, b2, c2, ...], ... ]`
@param options { hash } - display options for the chart
*/

export default class OxiChartComponent extends Component {
    guid;
    opt = {};
    seriesCount;

    // x - timestamp
    // y - BTC price
    // y - RSI
    // y - RSI MA

    constructor() {
        super(...arguments);

        this.guid = guidFor(this);

        this.seriesCount = this.args.data[0].length - 1;

        // Evaluate given options and set defaults
        const defaults = {
            width: 400,
            height: 200,
            title: "",
            cssClass: "",
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

        // Loops in 'bar' and 'pie' chart code need the series to be defined
        if (this.opt.series.length === 0) {
            for (let i = 0; i < this.seriesCount; i++) this.opt.series.push({})
        }

        // Defaults for series options
        let i = 0;
        let col_factor = 1/this.seriesCount;
        this.opt.series = this.opt.series.map(
            ({
                label = '',
                color = `rgba(${120 - i*col_factor*100}, ${150 - i*col_factor*150}, ${50 + i*col_factor*200}, 1)`,
                fill,
                line_width = 1,
                scale = 'auto',
            }) => { i++; return { label, color, fill, line_width, scale } }
        );
    }

    @action
    plot(element) {
        const type = this.args.options.type;
        if (type == 'line' || type == 'bar') this.drawLineOrBar(element)
    }

    @action
    drawLineOrBar(element) {
        // FIXME: Temporary workaround for seriesBarsPlugin() not working with single series
        let barChartSingleSeriesFix = (this.opt.type == 'bar' && this.args.data.length < 2);

        /*
         * Convert data from
         * from [ [x1, price1, rsi1], [x2, price2, rsi2] ]
         *   to [ [x1, x2], [price1, price2], [rsi1, rsi2] ]
         */
        let uplotData = [];
        for (let i=0; i<this.args.data[0].length; i++) {
            let seriesData = this.args.data.map(row => +row[i]);

            // FIXME: Temporary workaround for seriesBarsPlugin() not working with single series
            if (barChartSingleSeriesFix) seriesData.push(null);

            uplotData.push(seriesData);
        }

        /*
         * Options
         */

        // assemble uPlot options
        let uplotOptions = {
            width: this.opt.width,
            height: this.opt.height,
            title: this.opt.title,
            class: this.opt.cssClass,
            legend: {
                show: this.opt.legend_label,
                live: this.opt.legend_value,
            },
            scales: {
                x: {
                    time: this.opt.x_is_timestamp,
                },
                'auto': {
                    auto: true,
                },
                '%': {
                    auto: false,
                    range: (self) => [ 0, 100 ],
                },
            },
            axes: [
                {
                    time: true,
                    values: axisTimestampConfig,
                }, // x axis
            ],
        };

        /*
         * LINE chart
         */
        // set custom date format
        if (this.opt.type == 'line' && this.opt.x_is_timestamp) {
            // format strings: https://github.com/leeoniya/uPlot/blob/1.6.3/src/fmtDate.js#L74
            let dateFormatter = uPlot.fmtDate(this.opt.legend_date_format);
            uPlot.assign(uplotOptions, {
                series: [
                    // X values (time)
                    {
                        value: (self, rawValue) => rawValue == null ? "-" : dateFormatter(new Date(rawValue * 1000)),
                    }
                ],
            });
        }

        /*
         * BAR chart
         */
        if (this.opt.type == 'bar') {
            // 'bar' chart specific options
            uPlot.assign(uplotOptions, {
                series: [
                    // X values (time)
                    {}
                ],
                scales: {
                    x: {
                        time: false,
                        values: undefined,
                    },
                },
                plugins: [
                    seriesBarsPlugin({
                        labels: () => this.args.data.map(group => group[0]), // group / time series
                        ori: this.opt.bar_vertical ? 1 : 0,
                        dir: 1,
                        singleSeriesFix: barChartSingleSeriesFix,
                    }),
                ],
            });
        }

        /*
         * Series - generate scales, axes, series
         */
        let autoScaleId = 0;

        for (const graph of this.opt.series) {
            let {
                label = '',
                color = 'rgba(0, 100, 200, 1)',
                fill,
                line_width = 1,
                scale = 'auto',
            } = graph;

            // Auto-generate scale if an array [min, max] was specified
            if (Array.isArray(scale)) {
                scale = `_autogenerated_${++autoScaleId}`;
                uplotOptions.scales[scale] = {
                    auto: false,
                    range: () => scale,
                };
            }

            let seriesOpts = {
                label,
                scale,
                fill: fill ?? reducedAlphaColor(color),
                width: line_width/window.devicePixelRatio,
                //value: (self, rawValue) => rawValue == null ? "-" : rawValue.toFixed(0),
            }
            if (this.opt.type == 'line') {
                seriesOpts.stroke = color;
            }
            if (this.opt.type == 'bar') {
                seriesOpts.fill = color;
            }
            uplotOptions.series.push(seriesOpts);

            // add up to 2 axis (left and right)
            if (uplotOptions.axes.length < 3) {
                let axis = {
                    scale,
                    space: Math.max((this.opt.bar_vertical ? this.opt.width : this.opt.height) / 20, 15),
                    //labelSize: 150,
                    size: 60,
                    stroke: this.opt.type == 'bar' ? 'black' : color,
                };
                // special treatment for percent
                if (scale == '%') uPlot.assign(axis, {
                    values: (u, vals, space) => vals.map(v => `${v.toFixed(0)}%`),
                });
                // second axis
                if (uplotOptions.axes.length == 2) {
                    // skip if same scale as first axis
                    if (uplotOptions.axes[1].scale == scale) continue;
                    // right hand side, no grid
                    uPlot.assign(axis, {
                        side: 1,
                        grid: { show: false },
                    })
                }
                uplotOptions.axes.push(axis);
            }
        }

        new uPlot(uplotOptions, uplotData, (uplot, init) => {
            element.appendChild(uplot.root);
            init();
        })
    }
}
