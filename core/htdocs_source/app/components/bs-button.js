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
    get typeClass() {
        return this.args.type ? `btn-${this.args.type}` : '';
    }

    @action
    handleClick(event) {
        this.args.onClick?.(event);
    }
}
