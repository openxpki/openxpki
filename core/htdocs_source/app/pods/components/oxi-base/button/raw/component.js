import Component from '@glimmer/component'
import { tracked } from '@glimmer/tracking'
import { action, set as emSet } from "@ember/object"
import { debug } from '@ember/debug'
import { service } from '@ember/service'
import Clickable from 'openxpki/data/clickable'
//import ow from 'ow'

/**
 * Low level button implementation supporting custom inner layout.
 *
 * ```html
 * <OxiBase::Button::Raw @button={{buttonObj}} class="btn btn-secondary"/>
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
 * @class OxiBase::Button::Raw
 * @extends Component
 */

// mapping of format codes to CSS classes applied to the button
let format2css = {
    primary:        "btn-primary",
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
}

export default class OxiButtonRawComponent extends Component {
    @service router;
    @service('oxi-content') content;

    @tracked showConfirmDialog = false

    skipClickHandler = false
    clickTarget = null

    get isLink() {
        return this.args.button.href ? true : false
    }

    get additionalCssClass() {
        if (this.args.button.loading) { return "oxi-btn-loading" }
        if (!this.args.button.format) { return "oxi-btn-optional border-secondary" }
        let cssClass = format2css[this.args.button.format]
        if (cssClass === undefined) {
            /* eslint-disable-next-line no-console */
            console.error(`oxi-base/button/raw: button "${this.args.button.label}" has unknown format: "${this.args.button.format}"`)
        }
        return cssClass ?? ""
    }

    constructor() {
        super(...arguments)

        let getType = obj => typeof obj == 'object' ? obj.constructor.name : typeof obj;

        if (! (this.args.button instanceof Clickable)) {
            throw new Error(`oxi-base/button/raw: Parameter "button" has wrong type. Expected: instance of "Clickable" (openxpki/data/clickable). Got: "${getType(this.args.button)}"`)
        }
        // type validation
        // TODO Reactivate type checking once we drop IE11 support
        /*
        ow(this.args.button, 'button', ow.any(
            ow.object.partialShape({
                'label': ow.string.not.empty,
                'format': ow.optional.string,
                'tooltip': ow.optional.string,
                'disabled': ow.optional.boolean,
                'confirm': ow.optional.object.exactShape({
                    'label': ow.string.not.empty,
                    'description': ow.string.not.empty,
                    'confirm_label': ow.optional.string,
                    'cancel_label': ow.optional.string,
                }),
            }),
            ow.object.partialShape({
                'label': ow.string.not.empty,
                'href': ow.string.not.empty,
                'format': ow.optional.string,
                'tooltip': ow.optional.string,
                'target': ow.optional.string,
            }),
        ))
        */
    }

    @action
    click(event) {
        debug("oxi-base/button/raw: click")

        if (this.skipClickHandler) {
            this.skipClickHandler = false
            return
        }

        // only links: save <a> element to create new click event in executeAction() later on
        this.clickTarget = event?.target // undefined for <button>

        if (this.args.button.confirm) {
            emSet(this.args.button, "loading", true)
            this.showConfirmDialog = true
        } else {
            this.executeAction()
        }

        // cancel click event - only effective if we are called via <a onclick="...">
        return false
    }

    @action
    executeAction() {
        this.resetConfirmState()
        // link mode
        if (this.isLink) {
            // this will result in a (second) call to click()
            this.skipClickHandler = true
            this.clickTarget.dispatchEvent(new MouseEvent("click", { view: window, bubbles: true, cancelable: false }))
        }
        // button mode
        else {
            let button = this.args.button

            button.loading = true
            if (button.onClick) {
                debug(`oxi-base/button/raw: executeAction - custom onClick() handler`)
                button.onClick(button)
                .finally(() => button.loading = false)
            }
            else if (button.action) {
                debug(`oxi-base/button/raw: executeAction - call to backend action '${button.action}'`)
                let request = { action: button.action }
                if (button.action_params) request = { ...button.action_params, ...request };
                this.content.updateRequest(request)
                .finally(() => button.loading = false)
            }
            else if (button.page) {
                debug(`oxi-base/button/raw: executeAction - transition to page '${button.page}`)
                this.router.transitionTo("openxpki", button.page)
                .finally(() => button.loading = false)
            }
            else {
                throw new Error("oxi-base/button/raw: executeAction - nothing to do. No 'action', 'page' or 'onClick' specified")
            }
        }
    }

    @action
    resetConfirmState() {
        emSet(this.args.button, "loading", false)
        this.showConfirmDialog = false
    }
}
