import Component from '@ember/component';
import $ from "jquery";

/**
Shows a button with an optional confirm dialog.

@module oxisection-grid
@param { hash } content - Hash containing the grid contents
```javascript
{
}
```
*/
const OxisectionGridComponent = Component.extend({
    visibleColumns: Em.computed("content.content.columns", function() {
        return (this.get("content.content.columns") || [])
        .map( (col, index) => { col.index = index; return col })
        .filter(col => col.sTitle[0] !== "_" && col.bVisible !== 0);
    }),
    pager: Em.computed("content.content.pager", "visibleColumns", function() {
        let pager = this.get("content.content.pager") || {};
        if (pager.count == null) { pager.count = 0 }
        if (pager.startat == null) { pager.startat = 0 }
        if (pager.limit == null) { pager.limit = Number.MAX_VALUE }
        if (pager.reverse == null) { pager.reverse = 0 }
        return pager;
    }),
    pages: Em.computed("pager.{startat,limit,order,reverse}", function() {
        let pager = this.get("pager");
        if (!pager) { return [] }
        if (pager.count <= pager.limit) { return [] }
        let pages = Math.ceil(pager.count / pager.limit);
        let current = Math.floor(pager.startat / pager.limit);
        let o = [];
        let i, j, ref;
        for (i = j = 0, ref = pages - 1; (0 <= ref ? j <= ref : j >= ref); i = 0 <= ref ? ++j : --j) {
            o.push({
                num: i + 1,
                active: i === current,
                startat: i * pager.limit,
                limit: pager.limit,
                order: pager.order,
                reverse: pager.reverse
            });
        }
        let pagersize = pager.pagersize;
        if (o.length > pagersize) {
            let ellipsis = {
                num: "...",
                disabled: true
            };
            pagersize = pagersize - 1;
            let l, r;
            l = r = pagersize >> 1;
            r = r + (pagersize & 1);
            if (current <= l) {
                o.splice(pagersize - 1, o.length - pagersize, ellipsis);
            } else if (current >= o.length - 1 - r) {
                o.splice(1, o.length - pagersize, ellipsis);
            } else {
                o.splice(current + r - 1, o.length - 1 - (current + r - 1), ellipsis);
                o.splice(1, current - (l - 1), ellipsis);
            }
        }
        o.prev = {
            disabled: current === 0,
            startat: (current - 1) * pager.limit,
            limit: pager.limit,
            order: pager.order,
            reverse: pager.reverse
        };
        o.next = {
            disabled: current === pages - 1,
            startat: (current + 1) * pager.limit,
            limit: pager.limit,
            order: pager.order,
            reverse: pager.reverse
        };
        return o;
    }),
    pagesizes: Em.computed("pager.{pagesizes,limit,startat,order,reverse}", function() {
        let pager = this.get("pager");
        if (!pager.pagesizes) { return [] }
        let greater = pager.pagesizes.filter(function(pagesize) {
            return pagesize >= pager.count;
        });
        let limit = Math.min.apply(null, greater);
        return pager.pagesizes
        .filter( pagesize => pagesize <= limit)
        .map( pagesize => {
            return {
                active: pagesize === pager.limit,
                limit: pagesize,
                startat: (pager.startat / pagesize >> 0) * pagesize,
                order: pager.order,
                reverse: pager.reverse
            };
        });
    }),
    columns: Em.computed("visibleColumns", "pager.{limit,startat,order,reverse}", function() {
        let columns = this.get("visibleColumns");
        let pager = this.get("pager");
        let results = [];
        for (const column of columns) {
            let order = pager.pagerurl ? column.sortkey : column.sTitle;
            let reverse = order === pager.order ? !pager.reverse : false;
            results.push({
                index: column.index,
                sTitle: column.sTitle,
                format: column.format,
                sortable: !!column.sortkey,
                isSorted: pager.order && pager.order === order,
                limit: pager.limit,
                order: order,
                reverse: +reverse,
                startat: pager.startat
            });
        }
        return results;
    }),
    data: Em.computed("content.content.data", function() {
        let data = this.get("content.content.data");
        let columns = this.get("columns");
        let titles = this.get("content.content.columns").getEach("sTitle");
        let classIndex = titles.indexOf("_status");
        if (classIndex === -1) {
            classIndex = titles.indexOf("_className");
        }
        let results = [];
        let y, j, len;
        for (y = j = 0, len = data.length; j < len; y = ++j) {
            let row = data[y];
            results.push({
                className: `gridrow-${row[classIndex]}`,
                originalData: row,
                data: columns.map(col => {
                    return {
                        format: col.format,
                        value: row[col.index],
                    }
                }),
                checked: false,
                originalIndex: y
            });
        }
        return results;
    }),
    sortedData: Em.computed("data", "columns", "pager.reverse", function() {
        let pager = this.get("pager");
        let data = this.get("data");
        if (pager.pagerurl) {
            return (data || []);
        } else {
            data = data.toArray();
            let columns = this.get("columns");
            let column = columns.findBy("isSorted");
            let sortNum = columns.indexOf(column);
            if (sortNum >= 0) {
                let re = /^[0-9.]+$/;
                data.sort(function(a, b) {
                    a = a.data[sortNum].value;
                    b = b.data[sortNum].value;
                    if (re.test(a) && re.test(b)) {
                        a = parseFloat(a, 10);
                        b = parseFloat(b, 10);
                    }
                    return (a > b) ? 1 : -1;
                });
                if (pager.reverse) {
                    data.reverseObjects();
                }
            }
            Em.run.scheduleOnce("afterRender", () => {
                return this.initializeContextmenu();
            });
            return data;
        }
    }),
    allChecked: Em.computed("sortedData.@each.checked", function() {
        return this.get("sortedData").isEvery("checked", true);
    }),
    manageBulkButtons: Em.on("init", Em.observer("sortedData.@each.checked", function() {
        let data = this.get("sortedData").filterBy("checked");
        let buttons = this.get("content.content.buttons");
        if (!buttons) { return }
        for (const button of buttons.filterBy("select")) {
            Em.set(button, "disabled", !data.length);
        }
    })),
    isBulkable: Em.computed("content.content.buttons.@each.select", function() {
        var ref;
        return (ref = this.get("content.content.buttons")) != null ? ref.isAny("select") : void 0;
    }),
    hasAction: Em.computed.bool("content.content.actions"),
    contextIndex: null,
    onItem: function(context, e) {
        let action;
        let actions = (this.get("content.content.actions") || []);
        if (actions.length === 1) {
            action = actions[0];
        } else {
            action = actions.filter(ac => ac.label === $(e.target).text())[0];
        }
        let columns = this.get("content.content.columns");
        let index = this.get("sortedData")[this.get("contextIndex")].originalIndex;
        let data = this.get("content.content.data")[index];
        let path = action.path;
        let i, j, len;
        for (i = j = 0, len = columns.length; j < len; i = ++j) {
            let col = columns[i];
            path = path.replace(`{${col.sTitle}}`, data[i]);
            path = path.replace(`{col${i}}`, data[i]);
        }
        if (action.target === "_blank") {
            return window.location.href = path;
        } else {
            return this.container.lookup("route:openxpki").sendAjax({
                page: path,
                target: action.target
            });
        }
    },
    initializeContextmenu: Em.on("didInsertElement", function() {
        var ref;
        return (ref = $()) != null ? ref.find(".context").contextmenu({
            target: $().find(".dropdown"),
            onItem: () => {
                return this.onItem.apply(this, arguments);
            }
        }).off("contextmenu") : void 0;
    }),
    actions: {
        buttonClick: function(button) {
            if (button.select) {
                let columns = this.get("content.content.columns").getEach("sTitle");
                let index = columns.indexOf(button.select);
                if (index === -1) {
                    throw new Error(`There is not column matching ${button.select}`);
                }
                let data = {
                    action: button.action
                };
                data[button.selection] = this.get("sortedData").filterBy("checked").getEach("originalData").getEach("" + index);
                Em.set(button, "loading", true);
                return this.container.lookup("route:openxpki").sendAjax(data)
                .then(function() {
                    return Em.set(button, "loading", false);
                });
            } else {
                return this.sendAction("buttonClick", button);
            }
        },
        select: function(row) {
            if (row) {
                return Em.set(row, "checked", !row.checked);
            } else {
                return this.get("sortedData").setEach("checked", !this.get("allChecked"));
            }
        },
        page: function(page) {
            if (page.disabled || page.active) {
                return;
            }
            let pager = this.get("pager");
            return this.container.lookup("route:openxpki")
            .sendAjax({
                page: pager.pagerurl,
                limit: page.limit,
                startat: page.startat,
                order: page.order,
                reverse: page.reverse,
            })
            .then((res) => {
                this.set("content.content.data", res.data);
                return Em.setProperties(pager, page);
            });
        },
        sort: function(page) {
            let pager = this.get("pager");
            if (pager.pagerurl) {
                if (page.order) {
                    return this.send("page", page);
                }
            } else {
                pager = this.get("pager");
                return Em.setProperties(pager, page);
            }
        },
        rowClick: function(index) {
            this.set("contextIndex", index);
            let actions = this.get("content.content.actions");
            if (!actions) { return }
            if (actions.length === 1) {
                return this.onItem();
            } else {
                let currentTarget = event.currentTarget;
                let clientX = event.clientX;
                let clientY = event.clientY;
                return Em.run.next(() => {
                    return $(`tbody tr:nth-child(${index + 1})`).contextmenu("show", {currentTarget, clientX, clientY});
                });
            }
        }
    }
});

export default OxisectionGridComponent;