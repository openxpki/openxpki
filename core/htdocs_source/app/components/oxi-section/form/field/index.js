import Component from '@glimmer/component'
import { action } from '@ember/object'
import { service } from '@ember/service'
import { debug } from '@ember/debug'

const fieldModules = Object.fromEntries(
    Object.entries(import.meta.glob('./*/index.js', { eager: true }))
        .map(([path, mod]) => [path.replace(/^\.\/(.+)\/index\.js$/, '$1'), mod])
)

/**
 * Dispatcher for form field sub-components.
 * Reads the field type from `@field.type` and dynamically loads the matching
 * sub-component from `oxi-section/form/field/<type>/`.
 *
 * ```html
 * <OxiSection::Form::Field
 *     @field={{field}}
 *     @setValue={{this.setValue}}
 *     @setName={{fn this.setName field}}
 *     @setError={{fn this.setError field}}
 *     @setFocusInfo={{fn this.setFocusInfo field}}
 *     @encodeFields={{this.encodeFields}}
 *     @onSubmit={{this.submit}}
 *     @addClone={{this.addClone}}
 *     @delClone={{this.delClone}}
 * />
 * ```
 *
 * @param { Field } field - The {@link Field} data object for this row.
 * @param { function } setValue - Callback to update the field value: `(field, value)`.
 * @param { function } setName - Callback to rename a dynamic input field: `(value)`.
 * @param { function } setError - Callback to set a validation error message: `(message)`.
 * @param { function } setFocusInfo - Callback to register a DOM element for focus management: `(field, element, takesInput)`.
 * @param { function } encodeFields - Callback to encode sibling field values for autocomplete requests.
 * @param { function } onSubmit - Callback invoked when Enter is pressed inside the field.
 * @param { function } [addClone] - Callback to add a clone of a clonable field.
 * @param { function } [delClone] - Callback to remove a clone of a clonable field.
 *
 * @class OxiSection::Form::Field
 * @extends Component
 */
export default class OxiFieldMainComponent extends Component {
    @service('oxi-backend') backend;
    @service('intl') intl;
    @service('oxi-config') config;

    /**
     * Returns `true` when the field type is `'bool'`, used by the template to render
     * a checkbox layout instead of a label/input row.
     * @memberOf OxiSection::Form::Field
     */
    get isBool() {
        return this.args.field.type === 'bool';
    }

    /**
     * Returns a plain-object snapshot of the {@link Field} data object,
     * stripped of internal underscore-prefixed metadata properties.
     * Passed to sub-components via `@content`.
     * @memberOf OxiSection::Form::Field
     */
    get field() {
        let field = this.args.field.toPlainHash();
        return field;
    }

    /**
     * Resolves the sub-component class for the current field type by looking it up
     * in the eagerly-imported `fieldModules` map. Returns `undefined` for unknown types.
     * @memberOf OxiSection::Form::Field
     */
    get fieldComponent() {
        debug(`oxi-section/form/field: importing ./${this.args.field.type}`)
        return fieldModules[this.args.field.type]?.default
    }

    /**
     * Returns `true` when `field.width` is `'small'` (case-insensitive).
     * Controls the CSS width class of the field wrapper.
     * @memberOf OxiSection::Form::Field
     */
    get isSmall() {
        return new String(this.args.field.width || '').toLowerCase() == 'small'
    }

    /**
     * Returns `true` when `field.width` is `'large'` (case-insensitive).
     * Controls the CSS width class of the field wrapper.
     * @memberOf OxiSection::Form::Field
     */
    get isLarge() {
        return new String(this.args.field.width || '').toLowerCase() == 'large'
    }
    /*
     * Options for <Tippy>, i.e. Popper.js
     * See
     *   https://atomiks.github.io/tippyjs/v6/all-props/#popperoptions and
     *   https://popper.js.org/docs/v2/modifiers/prevent-overflow/
     */
    /**
     * Returns Popper.js modifier options for the field tooltip (`<Tippy>`).
     * Disables tethering so the tooltip always stays fully visible even near viewport edges.
     * @memberOf OxiSection::Form::Field
     */
    get popperOptions() {
        return {
            modifiers: [
                {
                    name: 'preventOverflow',
                    options: {
                        tether: false, // allow Popper to leave its overflow area to always stick with reference?
                    },
                },
            ],
        }
    }

    /**
     * Proxies `addClone` to the parent form, passing the current `@field`.
     * @memberOf OxiSection::Form::Field
     */
    @action
    addClone() {
        this.args.addClone(this.args.field);
    }

    /**
     * Proxies `delClone` to the parent form, passing the current `@field`.
     * @memberOf OxiSection::Form::Field
     */
    @action
    delClone() {
        this.args.delClone(this.args.field);
    }

    /**
     * Called when the user picks a new key in a dynamic input field; proxies to the parent
     * form's `setName` callback.
     * @memberOf OxiSection::Form::Field
     */
    @action
    selectFieldType(value) {
        this.args.setName(value);
    }

    /**
     * Propagates a validation error from a sub-component up to the parent form via `setError`.
     * @memberOf OxiSection::Form::Field
     */
    @action
    onError(message) {
        this.args.setError(message);
    }

    /**
     * Keyboard handler attached to every field input. Enter submits the form (except in
     * textareas); Tab on the last clone in a clonable group adds another clone.
     * @memberOf OxiSection::Form::Field
     */
    @action
    onKeydown(event) {
        // ENTER --> submit form
        if (event.key === 'Enter' && this.field.type !== "textarea") {
            event.stopPropagation();
            event.preventDefault();
            this.args.onSubmit();
        }
        // TAB --> clonable fields: add another clone
        if (event.key === 'Tab' && this.field._lastCloneInGroup && this.field.value !== null && this.field.value !== "") {
            event.stopPropagation();
            event.preventDefault();
            this.addClone();
        }
    }
}
