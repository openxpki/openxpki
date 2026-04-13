import Component from '@glimmer/component'
import { tracked } from '@glimmer/tracking'
import { service } from '@ember/service'
import Clickable from 'openxpki/data/clickable'
//import ow from 'ow'

/**
 * Button implementation supporting custom inner layout. Shows either `<a href>` or `<button>`
 * depending on the button object's properties.
 *
 * ```html
 * <OxiBase::Button @button={{...}} class="btn btn-secondary">
 *     Click me
 * </OxiBase::Button>
 * ```
 *
 * @param { object } button - a {@link Clickable} object. Common properties for all modes:
 * @param { string } [button.format] - Button style format (e.g. `"primary"`, `"optional"`).
 * @param { boolean } [button.disabled] - Whether the button is disabled.
 * @param { object } [button.confirm] - Confirmation dialog config shown before the action fires.
 * @param { string } [button.href] - Mode 1: renders as `<a href>`. Mandatory for link mode.
 * @param { string } [button.target] - Mode 1: link target, e.g. `"_blank"`.
 * @param { function } [button.onClick] - Mode 2: renders as `<button>` with click handler. Must return a Promise. Button object is passed as parameter.
 * @param { string } [button.page] - Mode 3: renders as `<button>` that navigates to a page,<br>e.g. `"workflow!index!wf_type!request_checker"`.
 * @param { string } [button.action] - Mode 4: renders as `<button>` that triggers an action,<br>e.g. `"workflow!select!wf_action!global_cancel!wf_id!34"`.
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
    primary:        "oxi-btn-primary",
    submit:         "oxi-btn-submit",
    loading:        "oxi-btn-loading",
    cancel:         "oxi-btn-cancel",
    reset:          "oxi-btn-reset",
    expected:       "oxi-btn-expected",
    failure:        "oxi-btn-failure",
    optional:       "oxi-btn-optional",
    alternative:    "oxi-btn-alternative",
    exceptional:    "oxi-btn-exceptional",
    terminate:      "oxi-btn-terminate",
    tile:           "oxi-btn-tile",
    card:           "oxi-btn-card",
    info:           "oxi-btn-info",
}

export default class OxiClickableComponent extends Component {
    @service router;
    @service('oxi-content') content;

    @tracked showConfirmDialog = false

    /**
     * Returns the CSS class for the current button format (or `"oxi-btn-loading"` while
     * the button is in a loading state). Falls back to `"oxi-btn-optional"` for unknown formats.
     * @memberOf OxiBase::Button
     */
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

    /**
     * Returns `@button` as a {@link Clickable} instance.
     * @memberOf OxiBase::Button
     */
    get clickable() {
        return Clickable.fromHash(this.args.button)
    }
}
