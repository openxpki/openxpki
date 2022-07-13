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

/*
  Pie chart class
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

    const wrap = placeDiv(WRAP, root);
    wrap.appendChild(svg);

    wrap.style.width = opts.width + 'px';
    wrap.style.height = opts.height + 'px';
    svg.setAttribute('width', '100%');
    svg.setAttribute('height', '100%');
    svg.setAttribute('viewBox','0 0 100 100');
    svg.setAttribute('preserveAspectRatio','xMidYMax');

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
}
