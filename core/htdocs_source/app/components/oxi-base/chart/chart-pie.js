'use strict'

// Some code borrowed from uPlot to reuse its CSS for the pie chart

// https://github.com/leeoniya/uPlot/blob/1.6.4/src/domClasses.js
const pre = 'u-';
const UPLOT          =       'uplot';
const TITLE          = pre + 'title';
const WRAP           = pre + 'wrap';
const LEGEND         = pre + 'legend'
const LEGEND_INLINE  = pre + 'inline';
const LEGEND_SERIES  = pre + 'series';
const LEGEND_MARKER  = pre + 'marker';
const LEGEND_LABEL   = pre + 'label';
const LEGEND_VALUE   = pre + 'value';

// https://github.com/leeoniya/uPlot/blob/1.6.4/src/uPlot.js#L471
function initLegendRow(legendEl, i, label, color) {
    let row = placeTag('tr', LEGEND_SERIES, legendEl, legendEl.childNodes[i]);
    let labelDiv = placeTag('th', null, row);
    let indic = placeDiv(LEGEND_MARKER, labelDiv);

    indic.style.setProperty('background-color', color);

    let text = placeDiv(LEGEND_LABEL, labelDiv);
    text.textContent = label;

    let v = placeTag('td', LEGEND_VALUE, row);
    v.textContent = '--';
}

// https://github.com/leeoniya/uPlot/blob/1.6.4/src/dom.js
function placeTag(tag, cls, targ, refEl) {
    let el = document.createElement(tag);
    if (cls != null) addClass(el, cls);
    if (targ != null) targ.insertBefore(el, refEl);
    return el;
}

function placeDiv(cls, targ) {
    return placeTag('div', cls, targ);
}

function addClass(el, c) {
    c != null && el.classList.add(c);
}

/**
 * Renders an SVG-based pie chart into `element`, reusing uPlot's CSS class names
 * for consistent legend styling. Attaches a `ResizeObserver` when `opts.width`
 * or `opts.height` is `"auto"` and stores a cleanup callback on `element._pieCleanup`.
 *
 * @param { HTMLElement } element - Container element to render into.
 * @param { object } opts - Chart options (see {@link OxiBase::Chart} for the full schema).
 * @param { array } data - Row-major data: `[ [x1, pct1, pct2, ...], ... ]` (x value is discarded).
 */
export default function ChartPie(element, opts, data) {

    // https://github.com/leeoniya/uPlot/blob/1.6.4/src/uPlot.js#L270
    const root = self.root = placeDiv(UPLOT);

    addClass(root, opts.cssClass);

    if (opts.title) {
        let title = placeDiv(TITLE, root);
        title.textContent = opts.title;
    }

    let svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')

    if (opts.legend_position === 'right' || opts.legend_position === 'left') {
        addClass(root, `u-legend-${opts.legend_position}`);
    }

    const wrap = placeDiv(WRAP, root);
    wrap.appendChild(svg);

    const AUTO_SIZE_DEFAULT = 200;
    const autoWidth = opts.width === 'auto';
    const autoHeight = opts.height === 'auto';
    // Initial size — will be corrected by ResizeObserver if auto
    wrap.style.width = (autoWidth ? AUTO_SIZE_DEFAULT : opts.width) + 'px';
    wrap.style.height = (autoHeight ? AUTO_SIZE_DEFAULT : opts.height) + 'px';
    svg.setAttribute('class', 'pie-chart-svg');
    svg.setAttribute('viewBox','0 0 100 100');
    svg.setAttribute('preserveAspectRatio','xMidYMin');

    let filled = 0;
    for (let row of data) {
        row.shift(); // time
        for (let i=0; i<row.length; i++) {
            let circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle'),
                startAngle = -90,
                radius = 30,
                cx = 50,
                cy = 50,
                strokeWidth = 15,
                dashArray = 2*Math.PI*radius,
                dashOffset = dashArray - (dashArray * row[i] / 100) + 3,
                angle = (filled * 360 / 100) + startAngle;

            circle.setAttribute('r',radius);
            circle.setAttribute('cx',cx);
            circle.setAttribute('cy',cy);
            circle.setAttribute('fill','transparent');
            circle.setAttribute('stroke', opts.series[i].color);
            circle.setAttribute('stroke-width',strokeWidth);
            circle.setAttribute('stroke-dasharray',dashArray);
            circle.setAttribute('stroke-dashoffset',dashOffset);
            circle.setAttribute('transform','rotate('+(angle)+' '+cx+' '+cy+')');

            svg.appendChild(circle);
            filled+= +row[i];
        }
    }

    if (opts.legend_label) {
        let legendEl = placeTag('table', LEGEND, root);
        addClass(legendEl, LEGEND_INLINE);
        let i = 0;
        for (const series of opts.series) {
            initLegendRow(legendEl, i, series.label, series.color);
            i++;
        }
    }

    element.appendChild(root);

    if (!autoWidth && !autoHeight) return;

    const legendSide = opts.legend_position === 'right' || opts.legend_position === 'left';
    const legendEl = root.querySelector('.u-legend');
    const titleEl = root.querySelector('.u-title');

    // Snapshot the height once. If zero the container is sized by its content,
    // so fall back to a square (width-based) size.
    const initialHeight = Math.floor(element.getBoundingClientRect().height);
    const fixedHeight = autoHeight ? (initialHeight || null) : opts.height;

    let lastCanvasWidth = null;

    function resize() {
        // Read the element's own rendered width - the CSS layout has already
        // constrained it to the available space in its container.
        const availWidth = autoWidth ? Math.max(1, Math.floor(element.getBoundingClientRect().width)) : opts.width;
        const columnGap = (autoWidth && legendSide) ? Math.ceil(parseFloat(getComputedStyle(root).columnGap) || 0) : 0;
        const legendWidth = (autoWidth && legendSide && legendEl) ? legendEl.offsetWidth : 0;
        const titleHeight = (autoHeight && titleEl) ? titleEl.offsetHeight : 0;
        const w = autoWidth ? Math.max(1, availWidth - columnGap - legendWidth) : opts.width;
        if (w === lastCanvasWidth) return;
        lastCanvasWidth = w;
        root.style.maxWidth = availWidth + 'px';
        const availH = fixedHeight ? Math.max(1, fixedHeight - titleHeight) : 0;
        const h = autoHeight ? (availH || w) : opts.height; // square fallback when height unknown
        wrap.style.width = w + 'px';
        wrap.style.height = h + 'px';
    }

    // Initial size
    resize();

    const observer = new ResizeObserver((entries) => {
        const entry = entries[0];
        if (!entry) return;
        if (autoWidth && entry.contentRect.width < 1) return;
        resize();
    });

    // Observe element's parent: element itself grows/shrinks with content,
    // so we watch the containing block which is sized by CSS layout.
    observer.observe(element.parentElement || element);
    element._pieCleanup = () => observer.disconnect();
}
