import Component from '@glimmer/component';
import { action } from '@ember/object';

/**
 * Generic Bootstrap button wrapper.
 *
 * ```html
 * <BsButton @type="primary" @icon="glyphicon glyphicon-ok" @onClick={{this.save}}>Save</BsButton>
 * ```
 *
 * @param { string } [type] - Bootstrap variant suffix (e.g. `'primary'`, `'light'`, `'sm'`).
 *   Mapped to `btn-<type>` CSS class. Omit for no extra variant class.
 * @param { string } [icon] - CSS class string for an icon `<span>` prepended to the button content.
 * @param { boolean } [active] - When true, adds the `active` CSS class to the button.
 * @param { function } [onClick] - Click handler. Receives the native click event.
 *
 * @class BsButton
 * @extends Component
 */
export default class BsButton extends Component {
    /**
     * Returns the Bootstrap variant CSS class derived from `@type` (e.g. `"btn-primary"`),
     * or an empty string when `@type` is omitted.
     * @memberOf BsButton
     */
    get typeClass() {
        return this.args.type ? `btn-${this.args.type}` : '';
    }

    /**
     * Forwards the native click event to `@onClick` if provided.
     * @memberOf BsButton
     */
    @action
    handleClick(event) {
        this.args.onClick?.(event);
    }
}
