import Component from '@glimmer/component'
import { service } from '@ember/service'
import { action, set as emSet } from '@ember/object'
import { tracked } from '@glimmer/tracking'
import { TrackedArray } from 'tracked-built-ins'
import { debug } from '@ember/debug'
import ContainerButton from 'openxpki/data/container-button'
import GridButton from 'openxpki/data/grid-button'
import GridAction from 'openxpki/data/grid-action'
import Pager from 'openxpki/data/pager'

/**
 * Render a sortable, pageable data grid with optional row selection and actions.
 *
 * ```html
 * <OxiSection::Grid @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition.
 * @param { array } def.columns - Column descriptors.
 * @param { string } def.columns[].sTitle - Column title. Columns whose title starts with `_`
 *   are hidden; `_status` / `_className` provide a per-row CSS class.
 * @param { string } [def.columns[].format] - Cell format hint (e.g. `'certstatus'`, `'timestamp'`, ...).
 * @param { number } [def.columns[].bVisible] - Set to `0` to hide the column. Default: `1`
 * @param { string } [def.columns[].sortkey] - Key used for server-side (or client-side) sorting.
 *   Omit to make the column non-sortable.
 * @param { string } [def.empty] - Message shown in the table body when there are no data rows.
 *   Default: `"&nbsp;"` (non-breaking space).
 * @param { string } [def.footer] - Text rendered in a `<tfoot>` row below the table body.
 * @param { array } def.data - Row data as a 2-D array; each inner array contains one value per
 *   column (positional, matching `columns`).
 * @param { array } [def.actions] - Row-level action descriptors (rendered as icon buttons per row).
 *   Column values may be interpolated with `{columnTitle}` placeholders.
 *   Each entry is a {@link GridAction} hash.
 * @param { string } def.actions[].label - Tooltip / label (ignored when there is only one action).
 * @param { string } [def.actions[].icon] - Icon name.
 * @param { string } [def.actions[].href] - Link URL target.
 * @param { string } [def.actions[].page] - OpenXPKI page target.
 * @param { string } [def.actions[].action] - OpenXPKI action target.
 * @param { array } [def.buttons] - Toolbar button descriptors. Buttons with a `select` property
 *   become bulk-selection buttons ({@link GridButton}); all others are standard {@link ContainerButton} entries.
 * @param { object } [def.pager] - Pagination/sorting state.
 * @param { string } [def.pager.pagerurl] - URL used to fetch a new page; absence disables
 *   server-side paging/sorting (client-side fallback is used instead).
 * @param { number } def.pager.count - Total number of items.
 * @param { number } def.pager.startat - Zero-based index of the first displayed item.
 * @param { number } def.pager.limit - Items per page.
 * @param { string } [def.pager.order] - Currently active sort key.
 * @param { boolean } [def.pager.reverse] - Sort direction.
 * @param { number[] } [def.pager.pagesizes] - Selectable page-size options.
 * @param { number } [def.pager.pagersize] - Max page buttons shown before ellipsis.
 *
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
        this.rawData = new TrackedArray(this.args.def.data || [])
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

    /**
     * Returns `true` when at least one row action is defined.
     * @memberOf OxiSection::Grid
     */
    get hasAction() { return this.actions.length > 0 }
    /**
     * Returns `true` when more than one row action is defined (toggles icon-button vs. drop-down rendering).
     * @memberOf OxiSection::Grid
     */
    get multipleActions() { return this.actions.length > 1 }
    /**
     * Returns the first (and usually only) {@link GridAction} for single-action rows.
     * @memberOf OxiSection::Grid
     */
    get firstAction() { return this.actions[0] }

    /**
     * Returns `true` when a `pagerurl` is set, enabling server-side paging and sorting.
     * @memberOf OxiSection::Grid
     */
    get hasPager() { return !!this.pager.pagerurl }

    /**
     * Returns the subset of columns that are visible (title does not start with `_`, `bVisible != 0`),
     * each augmented with its original positional `index`.
     * @memberOf OxiSection::Grid
     */
    get visibleColumns() {
        return this.rawColumns
        .map( (col, index) => ({ ...col, index }))
        .filter(col => col.sTitle[0] !== "_" && col.bVisible != 0);
    }

    /**
     * Returns the page descriptor array used by the pager UI, with `prev`/`next` sentinel objects
     * attached. Returns `[]` when pagination is not needed (all items fit on one page).
     * Collapses middle pages into an ellipsis entry when total pages exceed `pager.pagersize`.
     * @memberOf OxiSection::Grid
     */
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

    /**
     * Returns the selectable page-size options filtered to those that make sense given
     * the total item count (i.e. sizes up to and including the smallest size that covers all items).
     * Each entry carries `active`, `limit`, `startat`, `order`, and `reverse` fields.
     * Returns `[]` when no `pagesizes` are configured.
     * @memberOf OxiSection::Grid
     */
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

    /**
     * Returns the visible columns enriched with sort state (`isSorted`, `reverse`)
     * and a `sortPage` descriptor that can be passed to `sort()` to change the sort order.
     * Uses `sortkey` for server-side sorting and `sTitle` for client-side sorting.
     * @memberOf OxiSection::Grid
     */
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

    /**
     * Returns the fully processed row array. Each row contains
     *  - `className` (from `_status`/`_className` columns),
     *  - `data` (per-visible-column `{ format, value }` pairs),
     *  - `checked` state,
     *  - `originalIndex`, and
     *  - `actions` with column variables already resolved via `resolveVariables`.
     * @memberOf OxiSection::Grid
     */
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

    /**
     * Returns a clone of `gridAction` with `{columnTitle}` placeholders in `href`, `page`,
     * and `action` replaced by the corresponding cell value from `row`.
     * @memberOf OxiSection::Grid
     */
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

    /**
     * Returns `data` sorted according to the current `pager` order/reverse state.
     * Server-side paging: returns `data` as-is (sorting done by backend).
     * Client-side paging: sorts numerically when both values look like numbers, lexicographically otherwise.
     * @memberOf OxiSection::Grid
     */
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

    /**
     * Returns `true` when every visible row is checked.
     * @memberOf OxiSection::Grid
     */
    get allChecked() {
        return this.sortedData.every(i => i.checked == true)
    }

    /**
     * Returns `true` when no visible row is checked.
     * @memberOf OxiSection::Grid
     */
    get noneChecked() {
        return this.sortedData.every(i => i.checked == false)
    }

    /**
     * Returns `true` when at least one button carries a `select` property, enabling row checkboxes.
     * @memberOf OxiSection::Grid
     */
    get isBulkable() {
        return this.buttons.some(i => i.select);
    }

    /**
     * Collects the values of the column named by `button.select` for all checked rows
     * and sends them to the backend action defined by `button.action`.
     * @memberOf OxiSection::Grid
     */
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
        try {
            await this.content.requestPage(request)
        } finally {
            emSet(button, "loading", false)
        }
    }

    /**
     * Toggles the `checked` state of a single row and updates bulk-action button states.
     * @memberOf OxiSection::Grid
     */
    // (de-)select single row
    @action
    select(row) {
        let idx = row.originalIndex
        this.rawData[idx] = { ...this.rawData[idx], checked: !this.rawData[idx].checked }
        this.updateButtonState()
    }

    /**
     * Checks all rows when any are unchecked; unchecks all rows when all are already checked.
     * Updates bulk-action button states afterwards.
     * @memberOf OxiSection::Grid
     */
    // (de-)select all rows
    @action
    selectAll() {
        const wasAllChecked = this.allChecked;
        for (let i = 0; i < this.rawData.length; i++) {
            this.rawData[i] = { ...this.rawData[i], checked: !wasAllChecked }
        }
        this.updateButtonState()
    }

    /**
     * Enables or disables bulk-action buttons depending on whether any rows are checked.
     * @memberOf OxiSection::Grid
     */
    updateButtonState() {
        this.buttons.filter(b => b.select).forEach(b => b.disabled = this.noneChecked)
    }

    /**
     * Fetches a new data page from the server using `pager.pagerurl` and updates
     * `rawData` and the pager state. No-ops when `page.disabled` or `page.active`.
     * @memberOf OxiSection::Grid
     */
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
            this.rawData = new TrackedArray(res.data || []);
            this.pager.setFromHash(page);
        });
    }

    /**
     * Changes the sort order. For server-side paging calls `updatePage`; for client-side
     * paging updates `pager` state directly (re-render is triggered by tracked property).
     * @memberOf OxiSection::Grid
     */
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
