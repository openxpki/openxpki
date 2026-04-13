import Component from '@glimmer/component';
import { action } from '@ember/object';

/**
 * Boolean (checkbox) field implementation.
 *
 * @param { object } content - Plain field hash (from {@link Field}).
 * @param { string } content.name - Field name, used as the checkbox element id.
 * @param { string } content.label - Label shown next to the checkbox.
 * @param { 0|1 } [content.value] - Current checked state.
 * @param { function } onChange - Callback invoked with `1` (checked) or `0` (unchecked).
 * @param { function } setFocusInfo - Callback to register the element for focus management.
 *
 * @class OxiSection::Form::Field::Bool
 * @extends Component
 */
export default class OxiFieldBoolComponent extends Component {
    @action
    onInput(event) {
        this.args.onChange(event.target.checked ? 1 : 0);
    }
}
