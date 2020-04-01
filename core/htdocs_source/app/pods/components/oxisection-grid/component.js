import Component from '@glimmer/component';
import { getOwner } from '@ember/application';
import { action, computed, set, setProperties } from '@ember/object';
import { bool } from '@ember/object/computed';
import { tracked } from '@glimmer/tracking';
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
export default class OxisectionGridComponent extends Component {

    @tracked
    rawData = this.args.content.content.data;

    @computed("args.content.content.columns")
    get visibleColumns() {
        return (this.args.content.content.columns || [])
        .map( (col, index) => { col.index = index; return col })
        .filter(col => col.sTitle[0] !== "_" && col.bVisible !== 0);
    }

    @computed("args.content.content.pager", "visibleColumns")
    get pager() {
        let pager = this.args.content.content.pager || {};
        if (pager.count == null) { pager.count = 0 }
        if (pager.startat == null) { pager.startat = 0 }
        if (pager.limit == null) { pager.limit = Number.MAX_VALUE }
        if (pager.reverse == null) { pager.reverse = 0 }
        return pager;
    }

    @computed("pager.{startat,limit,order,reverse}")
    get pages() {
        let pager = this.pager;
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
    }

    @computed("pager.{pagesizes,limit,startat,order,reverse}")
    get pagesizes() {
        let pager = this.pager;
        if (!pager.pagesizes) { return [] }
        let greater = pager.pagesizes.filter(size => (size >= pager.count));
        let limit = Math.min.apply(null, greater);
        return pager.pagesizes
        .filter( size => (size <= limit))
        .map( size => {
            return {
                active: size === pager.limit,
                limit: size,
                startat: (pager.startat / size >> 0) * size,
                order: pager.order,
                reverse: pager.reverse
            };
        });
    }

    @computed("visibleColumns", "pager.{limit,startat,order,reverse}")
    get columns() {
        let columns = this.visibleColumns;
        let pager = this.pager;
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
    }

    @computed("rawData")
    get data() {
        let data = this.rawData;
        let columns = this.columns;
        let titles = this.args.content.content.columns.getEach("sTitle");
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
    }

    @computed("data", "columns", "pager.reverse")
    get sortedData() {
        let pager = this.pager;
        let data = this.data;
        if (pager.pagerurl) {
            return (data || []);
        } else {
            data = data.toArray();
            let columns = this.columns;
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
            return data;
        }
    }

    @computed("sortedData.@each.checked")
    get allChecked() {
        return this.sortedData.isEvery("checked", true);
    }

    @computed("sortedData.@each.checked", "args.content.content.buttons")
    get dummyMethodToSetButtonState() {
        let noneChecked = this.sortedData.isEvery("checked", false);
        for (const button of this.args.content.content.buttons.filterBy("select")) {
            set(button, "disabled", noneChecked);
        }
    }

    @computed("args.content.content.buttons.@each.select")
    get isBulkable() {
        return this.args.content.content.buttons.isAny("select");
    }

    @bool ("content.content.actions") hasAction

    contextIndex = null;

    onItem(action) {
        let columns = this.args.content.content.columns;
        let index = this.sortedData[this.contextIndex].originalIndex;
        let data = this.rawData[index];
        let path = action.path;
        let i, j, len;
        for (i = j = 0, len = columns.length; j < len; i = ++j) {
            let col = columns[i];
            path = path.replace(`{${col.sTitle}}`, data[i]);
            path = path.replace(`{col${i}}`, data[i]);
        }

        if (action.target === "_blank") {
            window.location.href = path;
        }
        else {
            return getOwner(this).lookup("route:openxpki").sendAjax({
                page: path,
                target: action.target
            });
        }
    }

    @action
    initializeContextmenu() {
        let actions = this.args.content.content.actions;
        if (!actions || actions.length === 1) { return }

        $().find(".context").contextmenu({
            target: $().find(".dropdown"),
            onItem: (e) => {
                let actions = this.args.content.content.actions;
                let ac = actions.filter(ac => ac.label === $(e.target).text())[0];
                return this.onItem(ac);
            }
        }).off("contextmenu");
    }

    @action
    buttonClick(button) {
        if (button.select) {
            let columns = this.args.content.content.columns.getEach("sTitle");
            let index = columns.indexOf(button.select);
            if (index === -1) {
                throw new Error(`There is no column matching "${button.select}"`);
            }
            let data = {
                action: button.action
            };
            data[button.selection] = this.sortedData.filterBy("checked").getEach("originalData").getEach("" + index);
            set(button, "loading", true);

            getOwner(this).lookup("route:openxpki")
            .sendAjax(data)
            .then(() => set(button, "loading", false));
        }
        else {
            this.args.buttonClick(button);
        }
    }

    @action
    select(row) {
        if (row) {
            set(row, "checked", !row.checked);
        }
        else {
            this.sortedData.setEach("checked", !this.allChecked);
        }
    }

    @action
    page(page) {
        if (page.disabled || page.active) {
            return;
        }
        let pager = this.pager;
        return getOwner(this).lookup("route:openxpki")
        .sendAjax({
            page: pager.pagerurl,
            limit: page.limit,
            startat: page.startat,
            order: page.order,
            reverse: page.reverse,
        })
        .then((res) => {
            this.rawData = res.data;
            setProperties(pager, page);
        });
    }

    @action
    sort(page) {
        let pager = this.pager;
        if (pager.pagerurl) {
            if (page.order) { this.page(page) }
        }
        else {
            setProperties(pager, page);
        }
    }

    @action
    rowClick(index) {
        this.contextIndex = index;
        let actions = this.args.content.content.actions;
        if (!actions) { return }
        if (actions.length === 1) {
            return this.onItem(actions[0]);
        }
        else {
            // FIXME: does not work, event is not defined
            /*
            let currentTarget = event.currentTarget;
            let clientX = event.clientX;
            let clientY = event.clientY;
            return Em.run.next(() => {
                return $(`tbody tr:nth-child(${index + 1})`).contextmenu("show", {currentTarget, clientX, clientY});
            });
            */
        }
    }
}
