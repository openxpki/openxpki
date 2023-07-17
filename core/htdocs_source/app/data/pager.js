import { tracked } from '@glimmer/tracking'
import Base from './base'

/*
 * Pager data, representing the current page, sort order etc.
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
