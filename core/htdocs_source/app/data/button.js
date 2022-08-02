import { tracked } from '@glimmer/tracking'
import Base from './base';

/*
 * Button data
 */
export default class Button extends Base {
    static get _type() { return 'app/data/button' }
    static get _idField() { return 'label' }

    /*
     * oxi-section
     */
    @tracked action

    /*
     * oxi-base/button
     */

    // Common
    @tracked format
    @tracked label                      // mandatory
    @tracked tooltip
    @tracked image
    @tracked loading = false            // pure client-side status
    onClick                             // pure client-side status
    // <a href> mode
    @tracked href                       // mandatory - triggers the <a href...> format
    @tracked target
    // <button> mode
    @tracked page
    disabled
    /* confirm = {
     *     label: "Really sure?",       / mandatory if "confirm" exists
     *     description: "Think!",       / mandatory if "confirm" exists
     *     confirm_label: ""
     *     cancel_label: ""
     * }
     */
    confirm

    /*
     * oxi-base/button-container
     */
    section
    description
    break_before
    break_after

    /*
     * oxi-section/grid
     */
    @tracked select
    @tracked selection
}
