import Component from '@glimmer/component'
import { tracked } from '@glimmer/tracking'
import { service } from '@ember/service'
import Clickable from 'openxpki/data/clickable'
//import ow from 'ow'

/**
 * Button implementation supporting custom inner layout.
 *
 * ```html
 * <OxiBase::Button @button={{buttonObj}} class="btn btn-secondary">
 *     {{buttonObj.label}}
 * </OxiBase::Button>
 * ```
 *
 * The component has two modes and shows either `<a href/>` or `<button/>`.
 *
 * @param { Clickable } buttonObj - a {@link Clickable} object where the following properties are relevant:
 * Common properties for all modes:
 * ```javascript
 * {
 *     format: "primary",
 *     disabled: false,
 *     confirm: { ... },
 * }
 * ```
 * Mode 1 `<a href>`:
 * ```javascript
 * {
 *     ...
 *     href: "https://www.openxpki.org", // mandatory
 *     target: "_blank",
 * }
 * ```
 * Mode 2 `<button>` with `onClick` handler:
 * ```javascript
 * {
 *     ...
 *     // callback: Must return a Promise! Button object will be passed as parameter
 *     onClick: this.clickHandler,
 * }
 * ```
 * Mode 3 `<button>` with `page`:
 * ```javascript
 * {
 *     ...
 *     page: 'workflow!index!wf_type!request_checker', // mandatory
 * }
 * ```
 * Mode 4 `<button>` with `action`:
 * ```javascript
 * {
 *     ...
 *     action: 'workflow!select!wf_action!global_cancel!wf_id!34', // mandatory
 * }
 * ```
 * @class OxiBase::Button
 * @extends Component
 */

/*
  Mapping of format codes to CSS classes applied to the button.

  We set the CSS class btn-light additionally to our own oxi-btn-xxx
  classes. This is to ensure the buttons are properly rendered by Bootstrap in
  "disabled" and "hover" states (without the need to specify these state
  dependent colors for every one of our buttons).
*/
let format2css = {
    none:           "", // to allow formatting via <OxiBase::Button class="..."> without adding fallback defaults
    primary:        "btn-primary",
    submit:         "btn-light oxi-btn-submit",
    loading:        "btn-light oxi-btn-loading",
    cancel:         "btn-light oxi-btn-cancel",
    reset:          "btn-light oxi-btn-reset",
    expected:       "btn-light oxi-btn-expected",
    failure:        "btn-light oxi-btn-failure",
    optional:       "btn-light oxi-btn-optional",
    alternative:    "btn-light oxi-btn-alternative",
    exceptional:    "btn-light oxi-btn-exceptional",
    terminate:      "btn-light oxi-btn-terminate",
    tile:           "btn-light oxi-btn-tile",
    card:           "oxi-btn-card",
    info:           "btn-light oxi-btn-info",
}

export default class OxiClickableComponent extends Component {
    @service router;
    @service('oxi-content') content;

    @tracked showConfirmDialog = false

    get formatCSSClass() {
        if (this.args.button.loading) { return "oxi-btn-loading" }

        let format = this.args.button.format || 'optional'
        let cssClass = format2css[format]
        if (cssClass === undefined) {
            /* eslint-disable-next-line no-console */
            console.error(`oxi-base/button: button "${this.args.button.label}" has unknown format: "${this.args.button.format}"`)
            cssClass = format2css['optional']
        }
        return cssClass
    }

    get clickable() {
        return Clickable.fromHash(this.args.button)
    }
}
