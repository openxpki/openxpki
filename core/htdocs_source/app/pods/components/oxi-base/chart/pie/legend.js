'use strict'

// From https://raw.githubusercontent.com/leeoniya/uPlot/1.6.4/src/domClasses.js
const pre = "u-";
export const LEGEND         = pre + "legend"
export const LEGEND_LIVE    = pre + "live";
export const LEGEND_INLINE  = pre + "inline";
export const LEGEND_THEAD   = pre + "thead";
export const LEGEND_SERIES  = pre + "series";
export const LEGEND_MARKER  = pre + "marker";
export const LEGEND_LABEL   = pre + "label";
export const LEGEND_VALUE   = pre + "value";

// Code borrowed from uPlot to reuse its CSS for the pie chart
function initLegendRow(legendEl, i, label, color) {
    let row = placeTag("tr", LEGEND_SERIES, legendEl, legendEl.childNodes[i]);
    let labelDiv = placeTag("th", null, row);
    let indic = placeTag("div", LEGEND_MARKER, labelDiv);

    indic.style.setProperty('background-color', color);

    let text = placeTag("div", LEGEND_LABEL, labelDiv);
    text.textContent = label;

    let v = placeTag("td", LEGEND_VALUE, row);
    v.textContent = "--";
}

function placeTag(tag, cls, targ, refEl) {
    let el = document.createElement(tag);
    if (cls != null) addClass(el, cls);
    if (targ != null) targ.insertBefore(el, refEl);
    return el;
}

function addClass(el, c) {
    c != null && el.classList.add(c);
}

export default function pieChartLegend(element, seriesList, getLabelAndColor) {
    let legendEl = placeTag("table", LEGEND, element);
    addClass(legendEl, LEGEND_INLINE);
    let i = 0;
    for (const series of seriesList) {
        let lc = getLabelAndColor(series);
        initLegendRow(legendEl, i, lc.label, lc.color);
        i++;
    }
}
