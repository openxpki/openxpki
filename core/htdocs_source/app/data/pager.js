import { tracked } from '@glimmer/tracking'
import Base from './base'

/*
 * Pager data, representing the current page, sort order etc.
 */
export default class Pager extends Base {
    static _type = 'app/data/pager'
    static _idField = 'pagerurl'

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
}
