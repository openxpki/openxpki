import Component from '@glimmer/component'
import { tracked } from '@glimmer/tracking'
import { action } from '@ember/object'
import { service } from '@ember/service'
import { debug } from '@ember/debug'

/**
 * Drop-down select field implementation, with optional free-text custom-value mode.
 * When `content.editable` is set a toggle button lets the user type an arbitrary value instead.
 *
 * @param { object } content - Plain field hash (from {@link Field}).
 * @param { array } content.options - List of `{ value, label }` option objects.
 * @param { string } [content.value] - Currently selected value.
 * @param { string } [content.placeholder] - Placeholder shown when nothing is selected.
 * @param { boolean } [content.is_optional] - When falsy the select is marked required; also controls the clear button.
 * @param { boolean } [content.editable] - Show a toggle button to switch to free-text custom-value input.
 * @param { boolean } [content.inline] - Render the select inline (no input-group wrapper).
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

    /**
     * Returns the placeholder text. Translates the special value `'_default'` or a missing
     * placeholder (on optional fields) to the i18n key `component.oxifield_select.default_placeholder`.
     * @memberOf OxiSection::Form::Field::Select
     */
    get placeholder() {
        let label = this.args.content.placeholder
        if (label == '_default' || (!label && this.args.content.is_optional)) {
            label = this.intl.t('component.oxifield_select.default_placeholder')
        }
        return label
    }

    /**
     * Returns `true` when there is exactly one option and the field is neither editable nor optional.
     * In this case the value is pre-selected and the `<select>` is rendered as read-only static text.
     * @memberOf OxiSection::Form::Field::Select
     */
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

    /**
     * Propagates the selected value to the parent form via `onChange`.
     * @memberOf OxiSection::Form::Field::Select
     */
    @action
    optionSelected(value) {
        debug(`oxifield-select (${this.args.content.name}): optionSelected(${value})`);
        this.args.onChange(value);
    }

    /**
     * Toggles between the `<select>` drop-down and the free-text custom-value input.
     * When switching back to select mode, resets to the first option if the current value
     * is not in the option list.
     * @memberOf OxiSection::Form::Field::Select
     */
    @action
    toggleCustomMode() {
        this.customMode = !this.customMode;
        // only set default value if the current custom value is not included in SELECT's options
        // (prevents value change if custom mode is just toggled on and off)
        if (!this.customMode && this.isCustomValue(this.args.content.value)) {
            this.args.onChange(this.args.content.options[0].value);
        }
    }

    /**
     * Called when the custom free-text input is inserted into the DOM.
     * Immediately focuses the element so the user can start typing.
     * @memberOf OxiSection::Form::Field::Select
     */
    @action
    onCustomInsert(element) {
        element.focus(); // to focus after user hit the toggle button
        // oxi-section/form might steal focus again on initial form rendering
    }

    /**
     * Propagates free-text input changes to the parent form via `onChange`.
     * @memberOf OxiSection::Form::Field::Select
     */
    @action
    onCustomInput(event) {
        this.args.onChange(event.target.value);
    }
}
