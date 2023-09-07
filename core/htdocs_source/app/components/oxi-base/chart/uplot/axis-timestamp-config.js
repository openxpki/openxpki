'use strict'

// From https://github.com/leeoniya/uPlot/blob/1.6.3/src/opts.js#L65

const ms = 1e-3; // 1e-3 = set up for seconds, 1 = set up for milliseconds

const NL = "\n";

const yyyy    = "{YYYY}";
const NLyyyy  = NL + yyyy;
const md      = "{DD}.{MM}";
const NLmd    = NL + md;
const NLmdyy  = NL + "{DD}.{MM}.{YY}";

const hmm     = "{H}:{mm}";
const NLhmm = NL + hmm;
const ss      = ":{ss}";

const _ = null;

const s  = ms * 1e3,
      m  = s  * 60,
      h  = m  * 60,
      d  = h  * 24,
      y  = d  * 365;

export default [
//   tick incr    default          year                    month   day                   hour    min       sec   mode
    [y,           yyyy,            _,                      _,      _,                    _,      _,        _,       1],
    [d * 28,      "{MMM}",         NLyyyy,                 _,      _,                    _,      _,        _,       1],
    [d,           md,              NLyyyy,                 _,      _,                    _,      _,        _,       1],
    [h,           "{H}",           NLmdyy,                 _,      NLmd,                 _,      _,        _,       1],
    [m,           hmm,             NLmdyy,                 _,      NLmd,                 _,      _,        _,       1],
    [s,           ss,              NLmdyy + " " + hmm,     _,      NLmd + " " + hmm,     _,      NLhmm,    _,       1],
    [ms,          ss + ".{fff}",   NLmdyy + " " + hmm,     _,      NLmd + " " + hmm,     _,      NLhmm,    _,       1],
];
