import Component from '@glimmer/component';
import { service } from '@ember/service';
import { action, set } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { debug } from '@ember/debug';
import { A } from '@ember/array'
import ContainerButton from 'openxpki/data/container-button'
import GridButton from 'openxpki/data/grid-button'

/*
 * Pager data, representing the current page, sort order etc.
 */
class Pager {
    @tracked num
    @tracked active
    @tracked count = 0
    @tracked startat = 0
    @tracked limit = Number.MAX_VALUE
    @tracked order
    @tracked reverse = false
    @tracked pagesizes
    @tracked pagersize
    @tracked pagerurl
    @tracked disabled = false

    fillFromHash(sourceHash) {
        for (const attr of Object.keys(sourceHash)) {
            // @tracked properties are prototype properties, the others instance properties
            if (! (Object.prototype.hasOwnProperty.call(Object.getPrototypeOf(this), attr) || Object.prototype.hasOwnProperty.call(this, attr))) {
                /* eslint-disable-next-line no-console */
                console.error(
                    `oxi-section/grid: unknown property "${attr}" in field "${sourceHash.name}". ` +
                    `If it's a new property, please add it to class 'Pager' defined in app/pod/components/oxi-section/grid/component.js`
                )
            }
            else {
                this[attr] = sourceHash[attr]
            }
        }
    }

    clone() {
        let twin = new Pager()
        // @tracked properties
        Object.keys(Object.getPrototypeOf(this)).forEach(k => twin[k] = this[k])
        // public class properties
        Object.keys(this).forEach(k => twin[k] = this[k])
        return twin
    }

    /**
     * Returns all non-private properties (i.e. no leading underscore) as a plain hash/object
     */
    toPlainHash() {
        let hash = {}
        // @tracked non-private properties
        Object.keys(Object.getPrototypeOf(this))
            .filter(k => k.charAt(0) != '_')
            .forEach(k => hash[k] = this[k])
        // non-private class properties
        Object.keys(this)
            .filter(k => k.charAt(0) != '_')
            .forEach(k => hash[k] = this[k])
        return hash
    }
}

/**
 * Draws a grid.
 *
 * @param { hash } def - section definition
 * ```javascript
 * {
 *     ... // TODO
 * }
 * ```
 * @class OxiSection::Grid
 * @extends Component
 */
export default class OxiSectionGridComponent extends Component {
    @service('oxi-content') content

    @tracked rawData = A([])
    @tracked pager = new Pager()
    buttons

    constructor() {
        super(...arguments)

        this.rawData = this.args.def.data || []
        this.pager.fillFromHash(this.args.def.pager || {})

        /* PLEASE NOTE that we cannot use a getter here, i.e. "get buttons()"
         * as for some reason this would recalculate every time we e.g. change
         * the "disabled" property in the derived GridButton class. And after
         * recalculating the changed property would be reset.
         */
        this.buttons = (this.args.def.buttons || []).map(def =>
            def.select
                ? GridButton.fromHash({...def, onClick: this.selectClick})
                : ContainerButton.fromHash(def)
        )
        this.updateButtonState()
    }

    get rawColumns() { return (this.args.def.columns || []) }
    get rawActions() { return (this.args.def.actions || []) }

    get hasAction() { return this.rawActions.length > 0 }
    get hasPager() { return !!this.pager.pagerurl }
    get multipleActions() { return this.rawActions.length > 1 }
    get firstAction() { return this.rawActions[0] }

    get visibleColumns() {
        return this.rawColumns
        .map( (col, index) => { col.index = index; return col })
        .filter(col => col.sTitle[0] !== "_" && col.bVisible !== 0);
    }

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

    get formattedColumns() {
        let results = [];
        for (const column of this.visibleColumns) {
            let order = this.hasPager
                ? column.sortkey // server-side sorting
                : column.sTitle; // client-side sorting
            let isSorted = this.pager.order && this.pager.order === order;
            let reverse = isSorted ? !this.pager.reverse : false;
            results.push({
                index: column.index,
                sTitle: column.sTitle,
                format: column.format,
                sortable: !!column.sortkey,
                isSorted: isSorted,
                // pager information to change sorting
                sortPage: {
                    limit: this.pager.limit,
                    order,
                    reverse,
                    startat: this.pager.startat
                }
            });
        }
        return results;
    }

    get data() {
        let columns = this.formattedColumns
        let titles = this.rawColumns.getEach("sTitle")
        let classIndex = titles.indexOf("_status")
        if (classIndex === -1) {
            classIndex = titles.indexOf("_className")
        }
        let results = []
        let y, j, len
        for (y = j = 0, len = this.rawData.length; j < len; y = ++j) {
            let row = this.rawData[y];

            let cssClass = ''
            if (classIndex != -1) {
                let _classname = row[classIndex]
                if (Object.prototype.toString.call(_classname) == '[object Object]') _classname = _classname.value
                cssClass = `gridrow-${_classname.toLowerCase()}`
            }

            results.push({
                className: cssClass,
                originalData: row,
                data: columns.map(col => {
                    return {
                        format: col.format,
                        value: row[col.index],
                    }
                }),
                checked: row.checked ? true : false,
                originalIndex: y
            })
        }
        return results
    }

    // split sorting from row data generation in "get data()" for better performance when re-sorting
    get sortedData() {
        // server-side sorting
        if (this.hasPager) return this.data;

        // client-side sorting
        let data = this.data.toArray()

        let col_index = this.formattedColumns.findIndex(col => col.isSorted)
        if (col_index >= 0) {
            let re = /^[0-9.]+$/;
            data.sort(function(a, b) {
                a = a.data[col_index].value;
                b = b.data[col_index].value;
                if (re.test(a) && re.test(b)) {
                    a = parseFloat(a, 10);
                    b = parseFloat(b, 10);
                }
                return (a > b) ? 1 : -1;
            });
            if (this.pager.reverse) {
                data.reverseObjects();
            }
        }
        return data;
    }

    get allChecked() {
        return this.sortedData.isEvery("checked", true);
    }

    get noneChecked() {
        return this.sortedData.isEvery("checked", false);
    }

    get isBulkable() {
        return this.buttons.isAny("select");
    }

    @action
    async selectClick(button) {
        debug("oxi-section/grid - selectClick")
        let columns = this.rawColumns.getEach("sTitle")
        let index = columns.indexOf(button.select)
        if (index === -1) {
            throw new Error(`There is no column matching "${button.select}"`)
        }
        let request = {
            action: button.action
        }
        request[button.selection] = this.sortedData.filterBy("checked").getEach("originalData").getEach("" + index)
        set(button, "loading", true)

        await this.content.updateRequest(request)
        set(button, "loading", false)
    }


    @action
    executeAction(row, act) {
        if (!act) return;
        let columns = this.rawColumns;
        let data = this.rawData[row.originalIndex];
        let path = act.path;
        let i, j, len;
        for (i = j = 0, len = columns.length; j < len; i = ++j) {
            let col = columns[i];
            // replace e.g. "wf_id!{serial}" with "wf_id!342"
            path = path.replace(`{${col.sTitle}}`, data[i]);
            path = path.replace(`{col${i}}`, data[i]);
        }

        if (act.target === "_blank") {
            window.location.href = path;
        }
        else {
            return this.content.updateRequest({
                page: path,
                target: act.target
            });
        }
    }

    // (de-)select single row
    @action
    select(row) {
        set(this.rawData[row.originalIndex], "checked", !this.rawData[row.originalIndex].checked)
        this.rawData = this.rawData // eslint-disable-line no-self-assign -- trigger Ember update
        this.updateButtonState()
    }

    // (de-)select all rows
    @action
    selectAll() {
        this.rawData.setEach("checked", !this.allChecked)
        this.rawData = this.rawData // eslint-disable-line no-self-assign -- trigger Ember update
        this.updateButtonState()
    }

    updateButtonState() {
        this.buttons.filter(b => b.select).forEach(b => b.disabled = this.noneChecked)
    }

    @action
    updatePage(page) {
            if (page.disabled || page.active) {
            return;
        }
        return this.content.updateRequest({
            page:    this.pager.pagerurl,
            limit:   page.limit,
            startat: page.startat,
            order:   page.order,
            reverse: page.reverse ? 1 : 0,
        })
        .then((res) => {
            this.rawData = res.data || [];
            this.pager.fillFromHash(page);
        });
    }

    @action
    sort(page) {
        // server-side sorting
        if (this.hasPager) {
            if (page.order) this.updatePage(page)
        }
        // client-side sorting
        else {
            this.pager.fillFromHash(page);
        }
    }
}
