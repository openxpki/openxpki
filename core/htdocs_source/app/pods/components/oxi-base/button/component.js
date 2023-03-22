import Component from '@glimmer/component'

/**
 * Shows a button with an optional confirm dialog.
 *
 * ```html
 * <OxiBase::Button::Raw @button={{buttonObj}} class="btn btn-secondary"/>
 * ```
 *
 * The component has two modes and shows either a `<a href/>` or a `<button/>` tag.
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

export default class OxiButtonComponent extends Component {}
