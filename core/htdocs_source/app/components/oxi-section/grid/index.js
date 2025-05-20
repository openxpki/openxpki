import Component from '@glimmer/component'
import { service } from '@ember/service'
import { action, set as emSet } from '@ember/object'
import { tracked } from '@glimmer/tracking'
import { debug } from '@ember/debug'
import ContainerButton from 'openxpki/data/container-button'
import GridButton from 'openxpki/data/grid-button'
import GridAction from 'openxpki/data/grid-action'
import Pager from 'openxpki/data/pager'

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

    rawColumns
    @tracked rawData // this needs to be @tracked because the user may (de-)select items
    actions // generic actions that contain variables instead of real URLs, e.g. page = "wf_id!{serial}"
    @tracked pager
    buttons
    colByName = new Map()

    constructor() {
        super(...arguments)

        this.rawColumns = this.args.def.columns || []
        this.rawData = this.args.def.data || []
        this.actions = (this.args.def.actions || []).map(a => GridAction.fromHash(a))

        this.colByName = new Map()
        for (let i = 0; i < this.rawColumns.length; i++) this.colByName.set(this.rawColumns[i].sTitle, i)

        this.pager = Pager.fromHash(this.args.def.pager || {})

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

    get hasAction() { return this.actions.length > 0 }
    get multipleActions() { return this.actions.length > 1 }
    get firstAction() { return this.actions[0] }

    get hasPager() { return !!this.pager.pagerurl }

    get visibleColumns() {
        return this.rawColumns
        .map( (col, index) => { col.index = index; return col })
        .filter(col => col.sTitle[0] !== "_" && col.bVisible != 0);
    }

    get pages() {
        let pager = this.pager;
        if (!pager) { return [] }
        if (pager.count <= pager.limit) { return [] }
        let pages = Math.ceil(pager.count / pager.limit);
        let current = Math.floor(pager.startat / pager.limit);
        let o = [];
        for (let i = 0; i < pages; i++) {
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

        // list all pager sizes bigger than no. of items
        let tooBig = pager.pagesizes.filter(size => (size >= pager.count));
        // use the smallest of those big pager sizes as threshold
        let upperThreshold = Math.min(...tooBig);

        return pager.pagesizes
        .filter( size => (size <= upperThreshold))
        .map( size => {
            return {
                active: size == pager.limit,
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
        let titles = this.rawColumns.map(i => i.sTitle)
        let classIndex = titles.indexOf("_status")
        if (classIndex === -1) {
            classIndex = titles.indexOf("_className")
        }
        let results = []
        for (let y = 0; y < this.rawData.length; y++) {
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
                originalIndex: y,
                actions: this.actions.map(a => this.resolveVariables(a, row)),
            })
        }
        return results
    }

    resolveVariables(gridAction, row) {
        let rowAction = gridAction.clone()

        const replace = (str) => {
            let result = str
            for (const name of this.colByName.keys()) {
                // replace e.g. "wf_id!{serial}" with "wf_id!342"
                result = result.replace(`{${name}}`, row[this.colByName.get(name)])
            }
            return result
        }
        if (rowAction.href) rowAction.href = replace(rowAction.href)
        if (rowAction.page) rowAction.page = replace(rowAction.page)
        if (rowAction.action) rowAction.action = replace(rowAction.action)

        return rowAction
    }

    // split sorting from row data generation in "get data()" for better performance when re-sorting
    get sortedData() {
        // server-side sorting
        if (this.hasPager) return this.data;

        // client-side sorting
        let data = this.data

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
            if (this.pager.reverse) data.reverse()
        }
        return data;
    }

    get allChecked() {
        return this.sortedData.every(i => i.checked == true)
    }

    get noneChecked() {
        return this.sortedData.every(i => i.checked == false)
    }

    get isBulkable() {
        return this.buttons.some(i => i.select);
    }

    @action
    async selectClick(button) {
        debug('oxi-section/grid - selectClick')
        let columns = this.rawColumns.map(i => i.sTitle)
        let index = columns.indexOf(button.select)
        if (index === -1) {
            throw new Error(`There is no column matching "${button.select}"`)
        }
        let request = {
            action: button.action
        }
        request[button.selection] = this.sortedData.filter(i => i.checked).map(i => i.originalData[index])
        emSet(button, "loading", true)

        await this.content.requestPage(request)
        emSet(button, "loading", false)
    }

    // (de-)select single row
    @action
    select(row) {
        emSet(this.rawData[row.originalIndex], "checked", !this.rawData[row.originalIndex].checked)
        this.rawData = this.rawData // eslint-disable-line no-self-assign -- trigger Ember update
        this.updateButtonState()
    }

    // (de-)select all rows
    @action
    selectAll() {
        const wasAllChecked = this.allChecked;
        this.rawData.forEach(i => emSet(i, "checked", !wasAllChecked)) // FIXME turn rawData into object that extends Base and use @tracked properties instead of emSet()
        this.rawData = this.rawData // eslint-disable-line no-self-assign -- trigger Ember update
        this.updateButtonState()
    }

    updateButtonState() {
        this.buttons.filter(b => b.select).forEach(b => b.disabled = this.noneChecked)
    }

    @action
    updatePage(page) {
        debug('oxi-section/grid - updatePage()')
        if (page.disabled || page.active) {
            return;
        }
        return this.content.requestUpdate({
            page:    this.pager.pagerurl,
            limit:   page.limit,
            startat: page.startat,
            order:   page.order,
            reverse: page.reverse ? 1 : 0,
        }, { verbose: true })
        .then((res) => {
            this.rawData = res.data || [];
            this.pager.setFromHash(page);
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
            this.pager.setFromHash(page);
        }
    }
}
