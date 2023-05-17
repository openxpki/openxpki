import { tracked } from '@glimmer/tracking'
import Base from './base'

/*
 * Pager data, representing the current page, sort order etc.
 */
export default class Page extends Base {
    static _type = 'app/data/page'
    static _idField = 'name'

    @tracked name
    @tracked page
    @tracked main
    @tracked right
    @tracked status
}
