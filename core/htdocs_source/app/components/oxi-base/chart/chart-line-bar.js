'use strict'

// uPlot and seriesbars-plugin are lazy-imported inside ChartLineBar() to
// avoid uPlot's top-level Intl.NumberFormat(navigator.language) call crashing
// the module graph at app boot time when navigator.language is invalid.
import axisTimestampConfig from './uplot/axis-timestamp-config';

function reducedAlphaColor(cssColor) {
    const div = document.createElement('div');
    div.style.color = cssColor;

    // appending the created element to the DOM
    document.querySelector('body').appendChild(div);

    const match = getComputedStyle(div).color.match(/^rgba?\s*\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*(\d(\.\d)?)\s*)?\)$/i);

    // removing element from the DOM
    div.parentNode.removeChild(div);

    if (match) {
        // match[0] is regex complete match (e.g. "rgb(0,0,0)"), not a regex capturing group
        let col = {
            r: match[1],
            g: match[2],
            b: match[3]
        };
        // if (match[4]) { // if alpha channel is present
        //     parsedColor.a = match[4];
        // }
        return `rgba(${col.r},${col.g},${col.b},0.1)`;
    } else {
        throw new Error(`Color ${cssColor} could not be parsed.`);
    }
}

/*
  Line and Bar chart class
*/
export default async function ChartLineBar(element, opts, data) {
    // uPlot calls new Intl.NumberFormat(navigator.language) when it first loads.
    // Guard against invalid language tags (e.g. Playwright sets it to "undefined").
    if (!navigator.language || navigator.language === 'undefined') {
        try { Object.defineProperty(Navigator.prototype, 'language', { get: () => 'en-US', configurable: true }) } catch(e) {}
    }
    const [{ default: uPlot }, { default: seriesBarsPlugin }] = await Promise.all([
        import('uplot'),
        import('./uplot/seriesbars-plugin'),
    ]);
    // FIXME: Temporary workaround for seriesBarsPlugin() not working with single series
    const barChartSingleSeriesFix = (opts.type == 'bar' && data.length < 2);

    /*
     * Convert data from
     * from [ [x1, price1, rsi1], [x2, price2, rsi2] ]
     *   to [ [x1, x2], [price1, price2], [rsi1, rsi2] ]
     */
    let uplotData = [];
    for (let i=0; i<data[0].length; i++) {
        let seriesData = data.map(row => +row[i]);

        // FIXME: Temporary workaround for seriesBarsPlugin() not working with single series
        if (barChartSingleSeriesFix) seriesData.push(null);

        uplotData.push(seriesData);
    }

    /*
     * Options
     */

    // assemble uPlot options
    let uplotOptions = {
        width: opts.width,
        height: opts.height,
        title: opts.title,
        class: opts.cssClass,
        legend: {
            show: opts.legend_label,
            live: opts.legend_value,
            ...((opts.legend_label && (opts.legend_position === 'right' || opts.legend_position === 'left')) && {
                mount: (self, legendEl) => {
                    self.root.classList.add(`u-legend-${opts.legend_position}`);
                    self.root.appendChild(legendEl);
                },
            }),
        },
        scales: {
            x: {
                time: opts.x_is_timestamp,
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
    if (opts.type == 'line' && opts.x_is_timestamp) {
        // format strings: https://github.com/leeoniya/uPlot/blob/1.6.3/src/fmtDate.js#L74
        let dateFormatter = uPlot.fmtDate(opts.legend_date_format);
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
    if (opts.type == 'bar') {
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
                    labels: () => data.map(group => group[0]), // group / time series
                    ori: opts.bar_vertical ? 1 : 0,
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

    for (const graph of opts.series) {
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
        if (opts.type == 'line') {
            seriesOpts.stroke = color;
        }
        if (opts.type == 'bar') {
            seriesOpts.fill = color;
        }
        uplotOptions.series.push(seriesOpts);

        // Bar charts draw values on top of each bar via the plugin, so no y-axis needed.
        if (opts.type == 'bar') continue;

        // add up to 2 axis (left and right)
        if (uplotOptions.axes.length < 3) {
            let axis = {
                scale,
                space: Math.max((opts.bar_vertical ? opts.width : opts.height) / 20, 15),
                //labelSize: 150,
                size: 60,
                stroke: color,
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

    function createChart(width, height) {
        uplotOptions.width = width;
        uplotOptions.height = height;
        return new uPlot(uplotOptions, uplotData, (uplot, init) => {
            element.appendChild(uplot.root);
            init();
        });
    }

    const autoWidth = opts.width === 'auto';
    const autoHeight = opts.height === 'auto';

    // FIXED size
    if (!autoWidth && !autoHeight) {
        createChart(opts.width, opts.height);
        return;
    }

    // AUTO size
    const AUTO_HEIGHT_DEFAULT = 200;

    let chart = null;
    let lastCanvasWidth = null;
    // legendReserved: the fixed amount to subtract from availWidth for the side legend
    // (legendWidth + columnGap). Measured once on first render; label text never changes.
    let legendReserved = 0;

    // Snapshot the container height before first render. If zero the container
    // is sized by its content, so use the fallback.
    const initialHeight = Math.floor(element.getBoundingClientRect().height);
    let fixedHeight = autoHeight ? (initialHeight || AUTO_HEIGHT_DEFAULT) : opts.height;

    const legendSide = opts.legend_position === 'right' || opts.legend_position === 'left';

    // Initial render: create chart, measure title and legend, recreate once if needed.
    function initialRender() {
        const availWidth = autoWidth ? Math.max(1, Math.floor(element.getBoundingClientRect().width)) : opts.width;
        chart = createChart(availWidth, fixedHeight);

        // Measure and subtract title height once so it does not overflow the container.
        const titleEl = element.querySelector('.u-title');
        if (titleEl && titleEl.offsetHeight > 0) {
            fixedHeight = Math.max(1, fixedHeight - titleEl.offsetHeight);
            chart.destroy();
            element.innerHTML = '';
            chart = createChart(availWidth, fixedHeight);
        }

        // When legend is on the side, measure legend width + column-gap and subtract
        // from canvas width so canvas + gap + legend fits the container.
        if (autoWidth && legendSide) {
            const legendEl = element.querySelector('.u-legend');
            const uplotRoot = element.querySelector('.uplot');
            if (legendEl && uplotRoot) {
                const columnGap = Math.ceil(parseFloat(getComputedStyle(uplotRoot).columnGap) || 0);
                const legendWidth = Math.ceil(legendEl.getBoundingClientRect().width);
                if (legendWidth > 0 && legendWidth < availWidth) {
                    legendReserved = columnGap + legendWidth;
                    const canvasWidth = availWidth - legendReserved;
                    chart.destroy();
                    element.innerHTML = '';
                    chart = createChart(canvasWidth, fixedHeight);
                    lastCanvasWidth = canvasWidth;
                    return;
                }
            }
        }
        lastCanvasWidth = availWidth;
    }

    initialRender();

    const observer = new ResizeObserver((entries) => {
        const entry = entries[0];
        if (!entry) return;
        if (autoWidth && entry.contentRect.width < 1) return;
        const availWidth = autoWidth ? Math.max(1, Math.floor(element.getBoundingClientRect().width)) : opts.width;
        const canvasWidth = availWidth - legendReserved;
        if (canvasWidth === lastCanvasWidth) return;
        lastCanvasWidth = canvasWidth;
        chart.setSize({ width: canvasWidth, height: fixedHeight });
    });

    // Observe element's parent: element itself grows/shrinks with uPlot content,
    // so we watch the containing block which is sized by CSS layout.
    observer.observe(element.parentElement || element);

    // Store cleanup function so the Ember component can disconnect the observer
    element._uplotCleanup = () => { observer.disconnect(); if (chart) chart.destroy(); };
}
