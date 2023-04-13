import { tracked } from '@glimmer/tracking'
import Button from './button'

/**
 * Representation of a button in a button container.
 * @class ContainerButton
 * @extends Button
 *
 * @property {string} section Optional group to sort the button into
 * @property {string} description Optional description to show next to the button
 * @property {bool} break_before Boolean value indicating a newline before this button
 * @property {bool} break_after Boolean value indicating a newline after this button
 */
export default class ContainerButton extends Button {
    static _type = 'app/data/container-button'

    section
    description
    break_before
    break_after
}
