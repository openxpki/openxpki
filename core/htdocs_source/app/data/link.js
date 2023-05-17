import { tracked } from '@glimmer/tracking'
import Clickable from './clickable'

/**
 * Representation of a link or a button.
 * @class Link
 * @extends Clickable
 *
 * @property {string} label Label to show
 * @property {string} tooltip Optional tooltip
 */
export default class Link extends Clickable {
    static _type = 'app/data/link'

    @tracked label                      // mandatory
    @tracked tooltip
}
