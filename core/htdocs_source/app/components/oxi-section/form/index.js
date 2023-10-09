import Component from '@glimmer/component'
import { action } from "@ember/object"
import { tracked } from '@glimmer/tracking'
import { isArray } from '@ember/array'
import { service } from '@ember/service'
import { debug } from '@ember/debug'
import { scheduleOnce } from '@ember/runloop'
import Field from 'openxpki/data/field'
import ContainerButton from 'openxpki/data/container-button'

/**
 * Draws a form.
 *
 * @param { hash } def - section definition
 * ```javascript
 * {
 *     ... // TODO
 * }
 * ```
 * @class OxiSection::Form
 * @extends Component
 */
export default class OxiSectionFormComponent extends Component {
    @service('intl') intl;
    @service('oxi-content') content;
    @service router;

    @tracked loading = false;
    @tracked fields = [];

    clonableRefNames = [];
    domElementsByFieldId = {};
    dependants = {} // dependent fields by parent field name

    get buttons() {
        let buttons = []

        // We cannot use ContainerButton.fromHash() here as the would prevent Ember from
        // tracking state changes.
        let submit = new ContainerButton()
        submit.label = this.args.def.submit_label || this.intl.t('component.oxisection_form.submit')
        submit.format = this.loading ? "loading" : "submit"
        submit.onClick = this.submit
        buttons.push(submit)

        if (this.args.def.reset) {
            let reset = new ContainerButton()
            reset.label = this.args.def.reset_label || this.intl.t('component.oxisection_form.reset')
            reset.format = "reset"
            reset.page = this.args.def.reset
            buttons.push(reset)
        }

        if (this.args.def.buttons) { buttons.push(...this.args.def.buttons) }
        return buttons
    }

    hiddenFieldFilter(f) {
        return f.type !== "hidden" && f.type !== "encrypted";
    }

    constructor() {
        super(...arguments);
        this.fields = this.#prepareFields(this.args.def.fields);
        this.#updateCloneFields();
    }

    /**
     * Convert an array of field definition hashes into an array of Field objects.
     * Create multiple cloned fields if multiple values are given.
     * Properly set current key and value for input fields with dynamic (choosable)
     * key.
     */
    #prepareFields(fields) {
        let result = [];
        for (const fieldHash of fields) {
            // convert hash into field
            let field = Field.fromHash(fieldHash);

            // dynamic input fields will change the form field name depending on the
            // selected option, so we need an internal reference to the original name ("_refName")
            field._refName = field.name;

            // set placeholder
            if (typeof field.placeholder === "undefined") {
                field.placeholder = "";
            }

            // standard fields
            if (! field.clonable) {
                result.push(field);
            }
            // clonable field
            else {
                if (this.clonableRefNames.indexOf(field._refName) < 0) {
                    this.clonableRefNames.push(field._refName);
                }
                // process presets (array of key/value pairs): insert clones
                // NOTE: this does NOT support dynamic input fields
                if (isArray(field.value)) {
                    let values = field.value.length ? field.value : [""];
                    // add clones to field list
                    result.push(...values.map(v => {
                        let clone = field.clone();
                        clone.value = v;
                        return clone;
                    }));
                }
                else {
                    result.push(field.clone());
                }
            }
        }

        for (let field of result) {
            if (field.value) {
                // dynamic input fields: presets are key/value hashes.
                // we need to convert `value: { key: NAME, value: VALUE }` to `name: NAME, value: VALUE`
                if (typeof field.value === 'object' && field.value.key) {
                    field.name = field.value.key;
                    field.value = field.value.value;
                }
                // strip trailing newlines - esp. important for type "passwordverify"
                if (typeof field.value === 'string') {
                    field.value = field.value.replace(/\n*$/, "");
                }
            }
        }

        return result;
    }

    #extractDependentFields(field) {
        let dependants = []
        for (const opt of field.options) {
            // only add dependent fields for currently selected option (if any)
            if (opt.dependants && (field.value == opt.value)) {
                dependants = this.#prepareFields(opt.dependants) // recursive call
                field._dependants = dependants
                break
            }
        }
        return dependants
    }

    #removeDependentFields(field) {
        for (const depField of field._dependants) {
            if (depField.hasDependants) this.#removeDependentFields(depField)
        }
        this.#removeFields(...field._dependants)
        field._dependants = []
    }

    #updateCloneFields() {
        for (const name of this.clonableRefNames) {
            let clones = this.fields.filter(f => f._refName === name);
            for (const clone of clones) {
                clone._canDelete = true;
                clone._canAdd = clones[0].max ? clones.length < clones[0].max : true;
                clone._lastCloneInGroup = false;
            }
            if (clones.length === 1) {
                clones[0]._canDelete = false;
            }
            clones[clones.length-1]._lastCloneInGroup = true;
        }
    }

    get uniqueFieldNames() {
        let result = [];
        for (const field of this.fields) {
            if (result.indexOf(field.name) < 0) { result.push(field.name) }
        }
        return result;
    }

    get visibleFields() {
        return this.fields.filter(this.hiddenFieldFilter);
    }

    @action
    addClone(field) {
        if (field._canAdd === false) return
        let fieldCopy = field.clone()
        fieldCopy.value = ""
        fieldCopy._focusClone = true
        this.#insertFields(field, fieldCopy)
        this.#updateCloneFields()
    }

    @action
    delClone(field) {
        if (field._canDelete === false) return
        this.#removeFields(field)
        this.#updateCloneFields()
    }

    // insert the given field(s) after the anchor field
    #insertFields(anchor, ...fields) {
        if (fields.length == 0) return
        let anchorPos = this.fields.indexOf(anchor)
        this.fields.splice(anchorPos + 1, 0, ...fields)
        this.fields = this.fields // trigger Ember refresh
    }

    // remove given field(s) from field list
    #removeFields(...fields) {
        if (fields.length == 0) return
        for (let field of fields) {
            let pos = this.fields.indexOf(field)
            if (pos == -1) continue
            this.fields.splice(pos, 1)
        }
        this.fields = this.fields // trigger Ember refresh
    }

    // Turns all (non-empty) fields into request parameters (returns an Object)
    #encodeAllFields({ includeEmpty = false }) {
        return this.#encodeFields({
            includeEmpty,
            fieldNames: this.uniqueFieldNames,
        });
    }

    #encodeFields({ fieldNames, includeEmpty = false, renameMap = new Map() }) {
        let result = new Map();

        for (const name of fieldNames) {
            var newName = renameMap.has(name) ? renameMap.get(name) : name;

            // send clonables as list (even if there's only one field) and other fields as plain values
            let potentialClones = this.fields.filter(f =>
                f.name === name && (typeof f.value !== 'undefined') && (f.value !== "" || includeEmpty)
            );

            if (potentialClones.length === 0) continue; // there's not even one field to send

            if (potentialClones[0].type == 'encrypted') {
                // prefix triggers auto-decryption in the backend
                newName = '_encrypted_jwt_' + newName;
            }

            // encode ArrayBuffer as Base64 and change field name as a flag
            let encodeValue = (val) => {
                if (val instanceof ArrayBuffer) {
                    newName = `_encoded_base64_${newName}`;
                    return btoa(String.fromCharCode(...new Uint8Array(val)));
                }
                else {
                    return val;
                }
            };

            let value = potentialClones[0].clonable
                ? potentialClones.map(c => encodeValue(c.value))    // array for clonable fields
                : encodeValue(potentialClones[0].value)             // or plain value otherwise
            // setting 'result' must be separate step as encodeValue() modifies 'newName'
            result.set(newName, value);

            debug(`${name} = ${ potentialClones[0].clonable ? `[${value}]` : `"${value}"` }`);
        }
        return Object.fromEntries(result);
    }

    /**
     * @param field { hash } - field definition (gets passed in via this components' template, i.e. is a reference to this components' "model")
     * @param value { string } - the field's new value
     * @param skipValidityChecks { bool } - set to `true` to skip validity checks
     * @memberOf OxiSection::Form
     */
    @action
    setFieldValue(field, value, skipValidityChecks = false) {
        debug(`oxi-section/form (${this.args.def.action}): setFieldValue (${field.name}, value = "${value}", skipValidityChecks = ${skipValidityChecks})`);
        field.value = value;

        if (!skipValidityChecks) {
            if (this.#checkFieldValidity(field) == false) return Promise.resolve()
        }

        // process <select> with dependant fields
        if (field.hasDependants) {
            scheduleOnce('afterRender', () => {
                this.#removeDependentFields(field)
                let dependants = this.#extractDependentFields(field)
                this.#insertFields(field, ...dependants)
                this.#updateCloneFields()
            })
        }

        // action on change?
        if (!field.actionOnChange) return Promise.resolve()

        debug(`oxi-section/form (${this.args.def.action}): executing actionOnChange ("${field.actionOnChange}")`);
        let request = {
            action: field.actionOnChange,
            _sourceField: field.name,
            ...this.#encodeAllFields({ includeEmpty: true }),
        };

        let fields = this.fields;

        return this.content.requestUpdate(request)
        .then((doc) => {
            // replace fields in case the response contains an updated version
            for (const newField of this.#prepareFields(doc.fields)) {
                for (const oldField of fields) {
                    if (oldField.name === newField.name) {
                        let idx = fields.indexOf(oldField);
                        fields[idx] = newField;
                    }
                }
            }
            this.fields = fields; // trigger refresh
            return null;
        });
    }

    // check validation regex
    // (only for non-empty fields; the check if a required field is empty
    // is done via HTML <input> attribute required="..." in each component)
    #checkFieldValidity(field) {
        if (field.ecma_match && field.value !== "") {
            try {
                let re = new RegExp(field.ecma_match)
                if (! re.test(field.value)) {
                    this.setFieldError(field, this.intl.t('component.oxisection_form.validation_failed'))
                    return false
                }
            }
            catch (err) {
                /* eslint-disable-next-line no-console */
                console.debug(`Invalid validation regex for field ${field.name}: ecma_match = ${field.ecma_match}.\n${err}`)
            }
        }
        this.setFieldError(field, null)
        return true
    }

    /**
     * @param field { hash } - field definition (gets passed in via this components' template, i.e. is a reference to this components' "model")
     * @memberOf OxiSection::Form
     */
    @action
    setFieldName(field, name) {
        debug(`oxi-section/form (${this.args.def.action}): setFieldName (${field.name} -> ${name})`);
        field.name = name;
    }

    /**
     * @param field { hash } - field definition (gets passed in via this components' template, i.e. is a reference to this components' "model")
     * @memberOf OxiSection::Form
     */
    @action
    setFieldError(field, message, isServerError = false) {
        debug(`oxi-section/form (${this.args.def.action}): setFieldError (${field.name}, message = ${message}, isServerError = ${isServerError})`);

        if (isServerError) {
            field._server_error = message
            field._error = null
        }
        else {
            field._server_error = null
            field._error = message
        }

        let domElement = this.domElementsByFieldId[field._id]
        if (!domElement) return

        if (!message) message = '' // setCustomValidity() requires empty string to reset error
        if (domElement) domElement.setCustomValidity(message)
    }

    /**
     * @param fieldNames { array } - the list of field names to encode
     * @param renameMap { Map } - optional mappings: source field name => target field name
     * @memberOf OxiSection::Form
     */
    @action
    encodeFields(fieldNames, renameMap) {
        debug(`oxi-section/form (${this.args.def.action}): encodeFields ()`);

        return this.#encodeFields({ fieldNames, renameMap, includeEmpty: true });
    }

    get originalFieldCount() {
        return this.args.def.fields.filter(this.hiddenFieldFilter).length;
    }

    /**
     * Sub components of {@link OxiSection::Form::Field} should call this by using
     * the `{{on-init}}` modifier:
     * ```html
     * {{on-init @setFocusInfo true}}
     * {{on-init @setFocusInfo false}}
     * ```
     * depending on if it is an editable input field that may sensibly receive
     * the focus.
     * @memberOf OxiSection::Form
     */
    @action
    registerField(field, element, takesInput) { // 'field' is injected in our template via (fn ...)
        if (!takesInput) return

        this.domElementsByFieldId[field._id] = element;

        /*
         * A) Focus for newly added clone fields
         */
        if (field._focusClone) {
            element.focus();
            field._focusClone = false;
            return;
        }

        /*
         * B) Initial form rendering focus
         */
        let meta = this.args.meta || {}
        let index = this.fields.findIndex(f => f === field)
        this.content.registerFocusElement(meta.isPopup, true, element, meta.sectionNo, index);
    }

    @action
    async submit() {
        debug(`oxi-section/form (${this.args.def.action}): submit`);

        // check validity and gather form data
        for (const field of this.fields) {
            if (!field.is_optional && !field.value) {
                this.setFieldError(field, this.intl.t('component.oxisection_form.missing_value'));
                return
            } else {
                // previous server-side error (reset if user changes the input value)
                if (field._server_error) return
                // client side error
                if (this.#checkFieldValidity(field) == false) return
            }
        }

        let request = {
            action: this.args.def.action,
            ...this.#encodeAllFields({ includeEmpty: false }),
        };

        let res
        try {
            this.loading = true;
            res = await this.content.requestPage(request)
        }
        finally {
            this.loading = false;
        }

        // show field specific error messages if any
        if (res?.status?.field_errors !== undefined) {
            for (const faultyField of res.status.field_errors) {
                debug(`oxi-section/form (${this.args.def.action}): server reports faulty field: ${faultyField.name}`);
                let clones = this.fields.filter(f => f.name === faultyField.name);
                // if no index given: mark all clones as faulty
                if (typeof faultyField.index === "undefined") {
                    for (const clone of clones) {
                        this.setFieldError(clone, faultyField.error, true);
                    }
                // otherwise just pick the specified clone
                } else {
                    this.setFieldError(clones[faultyField.index], faultyField.error, true);
                }
            }
        }
    }
}
