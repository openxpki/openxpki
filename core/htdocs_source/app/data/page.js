import { tracked } from '@glimmer/tracking'
import Base from './base'

/**
 * Page data object, representing the currently active page and its main/status content.
 *
 * @property { string } name - Page name (route identifier).
 * @property { string } page - Raw page descriptor string.
 * @property { object } main - Main content sections array for the page.
 * @property { object } status - Status banner definition shown at the top of the page.
 *
 * @class Page
 * @extends Base
 */
export default class Page extends Base {
    static _type = 'app/data/page'
    static _idField = 'name'

    @tracked name
    @tracked page
    @tracked main
    @tracked status
}
