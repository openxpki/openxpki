import Component from '@glimmer/component'
import { tracked } from '@glimmer/tracking'
import { action, set } from "@ember/object"
import { debug } from '@ember/debug'
//import ow from 'ow'

/**
 * Shows a button with an optional confirm dialog.
 *
 * The component has two modes:
 *
 * 1. show a `<a href/>` tag and simply open the given URL:
 *    ```html
 *    <OxiBase::Button @button={{buttonObj1}} class="btn btn-secondary"/>
 *    ```
 * 2. show a `<button/>` tag and handle clicks via callback:
 *    ```html
 *    <OxiBase::Button @button={{buttonObj2}} class="btn btn-secondary"/>
 *    ```
 *
 * @param { Button } button - the button definition
 * Mode 1 `<a href>`:
 * ```javascript
 * {
 *     format: "primary",
 *     label: "Learn",                     // mandatory
 *     tooltip: "Just fyi",
 *     image: "https://...",
 *     href: "https://www.openxpki.org",   // mandatory - triggers the <a href...> format
 *     target: "_blank",
 * }
 * ```
 * Mode 2 `<button>`:
 * ```javascript
 * {
 *     format: "expected",
 *     label: "Move",                      // mandatory
 *     tooltip: "This should move it",
 *     image: "https://...",
 *     disabled: false,
 *     confirm: {
 *         label: "Really sure?",          // mandatory if "confirm" exists
 *         description: "Think!",          // mandatory if "confirm" exists
 *         confirm_label: ""
 *         cancel_label: ""
 *     },
 *     onClick: this.buttonClick,           // callback: Button object will be passed to the handler as single parameter
 * }
 * ```
 * @module component/oxi-base/button
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

export default class OxiButtonComponent extends Component {
    @tracked showConfirmDialog = false
    skipClickHandler = false
    clickTarget = null

    get isLink() {
        return this.args.button.href ? true : false
    }

    get additionalCssClass() {
        if (this.args.button.loading) { return "oxi-btn-loading" }
        if (!this.args.button.format) { return "btn-light border-secondary" }
        let cssClass = format2css[this.args.button.format]
        if (cssClass === undefined) {
            /* eslint-disable-next-line no-console */
            console.error(`oxi-button: button "${this.args.button.label}" has unknown format: "${this.args.button.format}"`)
        }
        return cssClass ?? ""
    }

    constructor() {
        super(...arguments)

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
        debug("oxi-button: click")

        if (this.skipClickHandler) {
            this.skipClickHandler = false
            return
        }

        // only links: save <a> element to create new click event in executeAction() later on
        this.clickTarget = event?.target // undefined for <button>

        if (this.args.button.confirm) {
            set(this.args.button, "loading", true)
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
            this.args.button.onClick?.(this.args.button) // invoke callback
        }
    }

    @action
    resetConfirmState() {
        set(this.args.button, "loading", false)
        this.showConfirmDialog = false
    }
}
