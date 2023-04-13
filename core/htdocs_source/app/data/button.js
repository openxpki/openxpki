import { tracked } from '@glimmer/tracking'
import Clickable from './clickable'

/**
 * A button that may have a label, an image or a tooltip.
 *
 * @class Button
 * @extends Clickable
 * @property {string} label Button label
 * @property {string} image Optional image source (link or e.g. `data:...`)
 * @property {string} tooltip Optional tooltip
 */
export default class Button extends Clickable {
    static _type = 'app/data/button'
    static _idField = 'label'

    @tracked label                      // mandatory
    @tracked image
    @tracked tooltip
}
