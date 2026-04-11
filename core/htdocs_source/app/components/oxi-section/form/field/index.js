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

    get isBool() {
        return this.args.field.type === 'bool';
    }

    get field() {
        let field = this.args.field.toPlainHash();
        return field;
    }

    get fieldComponent() {
        debug(`oxi-section/form/field: importing ./${this.args.field.type}`)
        return fieldModules[this.args.field.type]?.default
    }

    get isSmall() {
        return new String(this.args.field.width || '').toLowerCase() == 'small'
    }

    get isLarge() {
        return new String(this.args.field.width || '').toLowerCase() == 'large'
    }
    /*
     * Options for <Tippy>, i.e. Popper.js
     * See
     *   https://atomiks.github.io/tippyjs/v6/all-props/#popperoptions and
     *   https://popper.js.org/docs/v2/modifiers/prevent-overflow/
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

    @action
    addClone() {
        this.args.addClone(this.args.field);
    }

    @action
    delClone() {
        this.args.delClone(this.args.field);
    }

    @action
    selectFieldType(value) {
        this.args.setName(value);
    }

    @action
    onError(message) {
        this.args.setError(message);
    }

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
