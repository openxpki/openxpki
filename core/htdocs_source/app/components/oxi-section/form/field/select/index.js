import Component from '@glimmer/component'
import { tracked } from '@glimmer/tracking'
import { action } from '@ember/object'
import { service } from '@ember/service'
import { debug } from '@ember/debug'

/**
 * Drop-down select field implementation, with optional free-text custom-value mode.
 * When `content.editable` is set a toggle button lets the user type an arbitrary value instead.
 *
 * @param { object } content - Plain field hash (from {@link Field}):
 *   - `options` { array } - List of `{ value, label }` option objects.
 *   - `value` { string } - Currently selected value.
 *   - `placeholder` { string } - Placeholder shown when nothing is selected.
 *   - `is_optional` { boolean } - When falsy the select is marked required; also controls the clear button.
 *   - `editable` { boolean } - Show a toggle button to switch to free-text custom-value input.
 *   - `inline` { boolean } - Render the select inline (no input-group wrapper).
 * @param { function } onChange - Callback invoked with the selected (or typed) value string.
 * @param { function } setFocusInfo - Callback to register the active input element for focus management.
 * @param { string } [error] - Validation error message to display below the field.
 *
 * @class OxiSection::Form::Field::Select
 * @extends Component
 */
export default class OxiFieldSelectComponent extends Component {
    @service('intl') intl

    @tracked customMode = false;

    constructor() {
        super(...arguments);
        this.customMode = this.isCustomValue(this.args.content.value);
        if (this.isStatic) this.args.onChange(this.args.content.options[0].value);
    }

    // returns true if the given value is NOT part of the SELECT's option list
    isCustomValue(val) {
        if (val === null || val === undefined || val === '') return false;
        return (this.args.content.options.map(o => o.value).indexOf(val) < 0);
    }

    get placeholder() {
        let label = this.args.content.placeholder
        if (label == '_default' || (!label && this.args.content.is_optional)) {
            label = this.intl.t('component.oxifield_select.default_placeholder')
        }
        return label
    }

    get isStatic() {
        let options = this.args.content.options;
        let isEditable = this.args.content.editable;
        let isOptional = this.args.content.is_optional;
        if (options.length === 1 && !isEditable && !isOptional) {
            return true;
        } else {
            return false;
        }
    }

    @action
    optionSelected(value) {
        debug(`oxifield-select (${this.args.content.name}): optionSelected(${value})`);
        this.args.onChange(value);
    }

    @action
    toggleCustomMode() {
        this.customMode = !this.customMode;
        // only set default value if the current custom value is not included in SELECT's options
        // (prevents value change if custom mode is just toggled on and off)
        if (!this.customMode && this.isCustomValue(this.args.content.value)) {
            this.args.onChange(this.args.content.options[0].value);
        }
    }

    @action
    onCustomInsert(element) {
        element.focus(); // to focus after user hit the toggle button
        // oxi-section/form might steal focus again on initial form rendering
    }

    @action
    onCustomInput(event) {
        this.args.onChange(event.target.value);
    }
}
