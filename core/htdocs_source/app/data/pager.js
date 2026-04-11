import { tracked } from '@glimmer/tracking'
import Base from './base'

/**
 * Pager data, representing pagination state: current page, sort order, page sizes etc.
 *
 * @property { number } num - Current page number.
 * @property { boolean } active - Whether this pager entry is the active/current page.
 * @property { number } count - Total number of items across all pages.
 * @property { number } startat - Zero-based index of the first displayed item.
 * @property { number } limit - Maximum items per page. Default: `Number.MAX_VALUE` (no paging).
 * @property { string } order - Currently active sort key.
 * @property { boolean } reverse - Sort direction; `true` for descending. Default: `false`.
 * @property { number[] } pagesizes - Selectable page-size options shown in the pager UI.
 * @property { number } pagersize - Maximum number of page buttons displayed before using ellipsis.
 * @property { string } pagerurl - URL used to fetch a new page; absence disables server-side paging.
 * @property { boolean } disabled - When `true`, pager controls are disabled.
 *
 * @class Pager
 * @extends Base
 */
export default class Pager extends Base {
    static _type = 'app/data/pager'
    static _idField = 'pagerurl'

    @tracked num // page number
    @tracked active
    @tracked count = 0 // total number of items
    @tracked startat = 0 // current start item index
    @tracked limit = Number.MAX_VALUE // max. items per page
    @tracked order
    @tracked reverse = false
    @tracked pagesizes // array of selectable page sizes
    @tracked pagersize // max. number of pages to display before using ellipsis "..."
    @tracked pagerurl
    @tracked disabled = false
}
