import Component from '@glimmer/component';
import { action } from '@ember/object';

/**
 * Single password input field implementation.
 *
 * @param { object } content - Plain field hash (from {@link Field}).
 * @param { string } [content.value] - Initial value.
 * @param { string } [content.placeholder] - Placeholder text.
 * @param { boolean } [content.is_optional] - When falsy the input is marked required.
 * @param { function } onChange - Callback invoked with the new string value on each keystroke.
 * @param { function } setFocusInfo - Callback to register the input element for focus management.
 * @param { string } [error] - Validation error message to display below the input.
 *
 * @class OxiSection::Form::Field::Password
 * @extends Component
 */
export default class OxiFieldPasswordComponent extends Component {
    @action
    onInput(event) {
        this.args.onChange(event.target.value);
    }
}
