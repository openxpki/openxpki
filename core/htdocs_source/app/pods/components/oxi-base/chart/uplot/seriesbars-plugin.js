'use strict'

import uPlot from 'uplot';
import Quadtree from './quadtree';

function roundDec(val, dec) {
    return Math.round(val * (dec = 10**dec)) / dec;
}

const SPACE_BETWEEN = 1;
const SPACE_AROUND  = 2;
const SPACE_EVENLY  = 3;

const coord = (i, offs, iwid, gap) => roundDec(offs + i * (iwid + gap), 6);

function distr(numItems, sizeFactor, justify, onlyIdx, each) {
    let space = 1 - sizeFactor;

    let gap =  (
        justify == SPACE_BETWEEN ? space / (numItems - 1) :
        justify == SPACE_AROUND  ? space / (numItems    ) :
        justify == SPACE_EVENLY  ? space / (numItems + 1) : 0
    );

    let offs = (
        justify == SPACE_BETWEEN ? 0       :
        justify == SPACE_AROUND  ? gap / 2 :
        justify == SPACE_EVENLY  ? gap     : 0
    );

    let iwid = sizeFactor / numItems;
    let _iwid = roundDec(iwid, 6);

    if (onlyIdx == null) {
        for (let i = 0; i < numItems; i++)
            each(i, coord(i, offs, iwid, gap), _iwid);
    }
    else
        each(onlyIdx, coord(onlyIdx, offs, iwid, gap), _iwid);
}

export default function seriesBarsPlugin(opts) {
    const pxRatio    = devicePixelRatio;

    const labels     = opts.labels;

    const ori        = opts.ori;
    const dir        = opts.dir;

    const groupWidth = 0.9;
    const groupDistr = SPACE_BETWEEN;

    const barWidth   = 0.9;
    const barDistr   = SPACE_BETWEEN;

    const font       = Math.round(10 * pxRatio) + "px sans-serif";

    function pointWithin(px, py, rlft, rtop, rrgt, rbtm) {
        return px >= rlft && px <= rrgt && py >= rtop && py <= rbtm;
    }

    function walkTwo(yIdx, xCount, yCount, xDim, xDraw, yDraw) {
        distr(xCount, groupWidth, groupDistr, null, (ix, offPct, dimPct) => {
            let groupOffPx = xDim * offPct;
            let groupWidPx = xDim * dimPct;

            xDraw && xDraw(ix, groupOffPx, groupWidPx);

            yDraw && distr(yCount, barWidth, barDistr, yIdx, (iy, offPct, dimPct) => {
                let barOffPx = groupWidPx * offPct;
                let barWidPx = groupWidPx * dimPct;

                yDraw(ix, groupOffPx + barOffPx, barWidPx);
            });
        });
    }

    function drawBars(u, sidx, i0, i1) {
        return uPlot.orient(u, sidx, (series, dataX, dataY, scaleX, scaleY, valToPosX, valToPosY, xOff, yOff, xDim, yDim, moveTo, lineTo, rect) => {
            const fill = new Path2D();

            // test ori, text align, text baseline...x0, y0,m width, height

            let numGroups    = dataX.length;
            let barsPerGroup = u.series.length - 1;

            let y0Pos = valToPosY(0, scaleY, yDim, yOff);

            const _dir = dir * (ori == 0 ? 1 : -1);

            walkTwo(sidx - 1, numGroups, barsPerGroup, xDim, null, (ix, x0, wid) => {
                let lft = Math.round(xOff + (_dir == 1 ? x0 : xDim - x0 - wid));
                let barWid = Math.round(wid);

                let yPos = valToPosY(dataY[ix], scaleY, yDim, yOff);

                let btm = Math.round(Math.max(yPos, y0Pos));
                let top = Math.round(Math.min(yPos, y0Pos));
                let barHgt = btm - top;

                rect(fill, lft, top, barWid, barHgt);

                let x = ori == 0 ? Math.round(lft - xOff) : 0;
                let y = ori == 0 ? Math.round(top - yOff) : Math.round(lft - xOff);
                let w = ori == 0 ? barWid                 : barHgt;
                let h = ori == 0 ? barHgt                 : barWid;

                qt.add({x, y, w, h, sidx: sidx, didx: ix});
            });

            return {
                fill
            };
        });
    }

    function drawPoints(u, sidx, i0, i1) {
        u.ctx.font         = font;
        u.ctx.fillStyle    = "black";
        u.ctx.textAlign    = ori == 0 ? "center" : "left";
        u.ctx.textBaseline = ori == 0 ? "bottom" : "middle";

        uPlot.orient(u, sidx, (series, dataX, dataY, scaleX, scaleY, valToPosX, valToPosY, xOff, yOff, xDim, yDim, moveTo, lineTo, rect) => {
            let numGroups    = dataX.length;
            let barsPerGroup = u.series.length - 1;

            const _dir = dir * (ori == 0 ? 1 : -1);

            walkTwo(sidx - 1, numGroups, barsPerGroup, xDim, null, (ix, x0, wid) => {
                let lft    = Math.round(xOff + (_dir == 1 ? x0 : xDim - x0 - wid));
                let barWid = Math.round(wid);

                let yPos = valToPosY(dataY[ix], scaleY, yDim, yOff);

                let x = ori == 0 ? Math.round(lft + barWid/2) : Math.round(yPos);
                let y = ori == 0 ? Math.round(yPos)           : Math.round(lft + barWid/2);

                u.ctx.fillText(
                    dataY[ix],
                    x,
                    y,
                );
            });
        });
    }

    function range(u, dataMin, dataMax) {
        let [min, max] = uPlot.rangeNum(0, dataMax, 0.05, true);
        return [0, max];
    }

    let qt;
    let hovered = null;

    let barMark = document.createElement("div");
    barMark.classList.add("bar-mark");

    return {
        hooks: {
            init: u => {
                u.root.querySelector(".u-over").appendChild(barMark);
            },
            drawClear: u => {
                qt = qt || new Quadtree(0, 0, u.bbox.width, u.bbox.height);

                qt.clear();

                // force-clear the path cache to cause drawBars() to rebuild new quadtree
                u.series.forEach(s => {
                    s._paths = null;
                });
            },
            setCursor: u => {
                let found = null;
                let cx = u.cursor.left * pxRatio;
                let cy = u.cursor.top * pxRatio;

                qt.get(cx, cy, 1, 1, o => {
                    if (pointWithin(cx, cy, o.x, o.y, o.x + o.w, o.y + o.h))
                        found = o;
                });

                if (found) {
                    if (found != hovered) {
                        barMark.style.display = null;
                        barMark.style.left    = (found.x / pxRatio) + "px";
                        barMark.style.top     = (found.y / pxRatio) + "px";
                        barMark.style.width   = (found.w / pxRatio) + "px";
                        barMark.style.height  = (found.h / pxRatio) + "px";
                        hovered = found;
                    }
                }
                else if (hovered != null) {
                    hovered = null;
                    barMark.style.display = "none";
                }
            }
        },
        opts: (u, opts) => {
            const yScaleOpts = {
                range,
                ori: ori == 0 ? 1 : 0,
            };

            uPlot.assign(opts, {
                select: {show: false},
                cursor: {
                    x: false,
                    y: false,
                    points: {show: false}
                },
                scales: {
                    x: {
                        time: false,
                        distr: 2,
                        ori,
                        dir,
                    },
                }
            });

            if (ori == 1) {
                opts.padding = [0, null, 0, null];
            }

            uPlot.assign(opts.axes[0], {
                splits: (u, axisIdx) => {
                    const dim = ori == 0 ? u.bbox.width : u.bbox.height;
                    const _dir = dir * (ori == 0 ? 1 : -1);

                    let splits = [];

                    distr(u.data[0].length, groupWidth, groupDistr, null, (di, lftPct, widPct) => {
                        let groupLftPx = (dim * lftPct) / pxRatio;
                        let groupWidPx = (dim * widPct) / pxRatio;

                        let groupCenterPx = groupLftPx + groupWidPx / 2;

                        splits.push(u.posToVal(groupCenterPx, 'x'));
                    });

                    return _dir == 1 ? splits : splits.reverse();
                },
                values:     () => labels(),
                gap:        5,
                size:       40,
                labelSize:  20,
                grid:       {show: false},
                ticks:      {show: false},

                side:       ori == 0 ? 2 : 3,
            });

            opts.series.forEach((s, i) => {
                if (i > 0) {
                    uPlot.assign(s, {
                        width: 0,
                        paths: drawBars,
                        points: {
                            show: drawPoints
                        }
                    });
                }
            });
        }
    };
}