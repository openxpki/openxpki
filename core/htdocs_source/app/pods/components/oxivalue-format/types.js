import moment from "moment";

const types = {
    certstatus: v => `<span class='certstatus-${(v.value || v.label).toLowerCase()}' title='${v.tooltip || ""}'>${v.label}</span>`,
    link: v => `<a href='#/openxpki/${v.page}' target='${v.target || "modal"}' title='${v.tooltip || ""}'>${v.label}</a>`,
    extlink: v => `<a href='${v.page}' target='${v.target || "_blank"}' title='${v.tooltip || ""}'>${v.label}</a>`,
    timestamp: v => (v > 0) ? moment.unix(v).utc().format("YYYY-MM-DD HH:mm:ss UTC") : "---",
    datetime: v => moment().utc(v).format("YYYY-MM-DD HH:mm:ss UTC"),
    text: v => Em.$('<div/>').text(v).html(),
    nl2br: v => Em.$('<div/>').text(v).html().replace(/\n/gm, "<br>"),
    code: v => `<code>${Em.$('<div/>').text(v).html().replace(/\r/gm, "")}</code>`,
    raw: v => v,
    defhash: v => `<dl>${Object.keys.map(k => `<dt>${k}</dt><dd>${Em.$('<div/>').text(v[k]).html()}</dd>`).join("")}</dl>`,
    deflist: v => `<dl>${Object.keys.map(k => `<dt>${v[k].label}</dt><dd>${(v[k].format === "raw" ? v[k].value : Em.$('<div/>').text(v[k].value).html())}</dd>`).join("")}</dl>`,
    ullist:  v => `<ul class=\"list-unstyled\">${Object.keys.map(k => `<li>${Em.$('<div/>').text(v[k]).html()}</li>`).join("")}</ul>`,
    rawlist: v => `<ul class=\"list-unstyled\">${Object.values.map(w => `<li>${w}</li>`).join("")}</ul>`,
    linklist: v => `<ul class=\"list-unstyled\">${Object.values.map(w => `<li><a href='#/openxpki/${w.page}' target='${w.target || "modal"}' title='${w.tooltip || ""}'>${w.label}</a></li>`).join("")}</ul>`,
    styled: v => Em.$('<span/>').text(v).html().replace(/(([a-z]+):)?(.*)/gm, '<span class=\"styled-$2\">$3</span>'),
    tooltip: v => `<span title='${v.tooltip || ""}'>${v.value}</span>`,
    head: v => "1",
};

export default types;