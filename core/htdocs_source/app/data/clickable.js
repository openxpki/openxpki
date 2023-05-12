import { tracked } from '@glimmer/tracking'
import Base from './base'

/**
 * Representation of a clickable "thing" (link or button).
 * @class Clickable
 * @extends Base
 *
 * @property {string} format `@tracked`: Format keyword
 * @property {bool} disabled `@tracked`
 * @property {hash} confirm Hash to configure a confirmation popup:
 * ```javascript
 * {
 *     label: "Really sure?", // mandatory if "confirm" exists
 *     description: "Think!", // mandatory if "confirm" exists
 *     confirm_label: ""
 *     cancel_label: ""
 * },
 * @property {string} href Link: triggers the `<a href...>` mode in {@link OxiBase::Button}
 * @property {string} target Link target (only used in `<a href...>` mode)
 * @property {string} action OpenXPKI action to call: triggers the `<button...>` mode in {@link OxiBase::Button}
 * @property {hash} action_params Additional parameters to send with the POST request
 * @property {string} page OpenXPKI page to load: triggers the `<button...>` mode in {@link OxiBase::Button}
 * @property {bool} loading Internal status: `true` if button was clicked and new page is loading
 * @property {callback} onClick Internal status: click handler
 */
export default class Clickable extends Base {
    static _type = 'app/data/clickable'

    // Common
    @tracked format
    @tracked disabled
    /* confirm = {
     *     label: "Really sure?",       / mandatory if "confirm" exists
     *     description: "Think!",       / mandatory if "confirm" exists
     *     confirm_label: ""
     *     cancel_label: ""
     * }
     */
    confirm
    target

    // only one of "href", "action" or "page" should be set
    href
    action
    action_params
    page

    // pure client-side status:
    @tracked loading = false
    @tracked onClick // this overrides "href", "action" or "page"
}
