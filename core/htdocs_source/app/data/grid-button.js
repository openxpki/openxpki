import { tracked } from '@glimmer/tracking'
import ContainerButton from './container-button'

/**
 * Representation of a button in a {@link OxiSection::Grid} with information
 * about the processing of selected grid rows.
 * @class GridButton
 * @extends ContainerButton
 *
 * @property {string} selection Name of the request parameter that will hold the IDs of selected grid rows
 * @property {string} select `sTitle` of the column from which to read the IDs of selected rows
 */
export default class GridButton extends ContainerButton {
    static _type = 'app/data/grid-button'

    @tracked select
    @tracked selection
}
