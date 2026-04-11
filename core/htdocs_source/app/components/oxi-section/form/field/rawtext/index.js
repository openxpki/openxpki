import Component from '@glimmer/component';
import { action } from '@ember/object';

/**
 * Single-line plain text input field implementation (no autocomplete, no paste cleanup).
 *
 * @param { object } content - Plain field hash (from {@link Field}):
 *   - `value` { string } - Initial value.
 *   - `placeholder` { string } - Placeholder text.
 *   - `is_optional` { boolean } - When falsy the input is marked required.
 * @param { function } onChange - Callback invoked with the new string value on each keystroke.
 * @param { function } setFocusInfo - Callback to register the input element for focus management.
 * @param { string } [error] - Validation error message to display below the input.
 *
 * @class OxiSection::Form::Field::Rawtext
 * @extends Component
 */
export default class OxiFieldRawtextComponent extends Component {
    @action
    onInput(event) {
        this.args.onChange(event.target.value);
    }
}
