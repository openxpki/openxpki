import Component from '@glimmer/component'
import Button from 'openxpki/data/button'

/**
 * Shows a button with an optional confirm dialog.
 *
 * ```html
 * <OxiBase::Button @button={{buttonObj}} class="btn btn-secondary"/>
 * ```
 *
 * The component shows either `<a href/>` or `<button/>`, see
 * {@link OxiBase::Button::Raw} for more details.
 *
 *
 * @param { hash | Button } buttonObj - button definition (hash or class derived from {@link Button})
 * ```javascript
 * {
 *     label: "Learn",                     // mandatory
 *     tooltip: "Just fyi",
 *     image: "https://...",
 *     ...
 * }
 * @class OxiBase::Button
 * @extends Component
 */

export default class OxiButtonComponent extends Component {

    get button() {
        return Button.fromHash(this.args.button)
    }
}
