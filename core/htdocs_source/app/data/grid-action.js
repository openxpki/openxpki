import Clickable from './clickable'
import { tracked } from '@glimmer/tracking'

/**
 * Representation of an action in a grid section.
 * @class GridAction
 * @extends Clickable
 *
 * @property {string} label Label for the action (ignored if there is only one action in the grid)
 * @property {string} icon Optional icon name
 */
export default class GridAction extends Clickable {
    static _type = 'app/data/grid-action'

    label
    icon
}
