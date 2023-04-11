import Component from '@glimmer/component';
import { action } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { isArray } from '@ember/array';
import { service } from '@ember/service';
import { debug } from '@ember/debug';
import Field from 'openxpki/data/field';
import Button from 'openxpki/data/button';

/**
 * Draws a form.
 *
 * @param { hash } def - section definition
 * ```javascript
 * {
 *     ... // TODO
 * }
 * ```
 * @module component/oxi-section/form
 */
export default class OxiSectionFormComponent extends Component {
    @service('intl') intl;
    @service('oxi-content') content;
    @service router;

    @tracked loading = false;
    @tracked fields = [];

    clonableRefNames = [];
    focusFeedback = {}; // gets filled with the field feedback if they may receive the focus
    initialFocussingDone = false;

    get buttons() {
        let buttons = []

        // We cannot use Button.fromHash() here as the would prevent Ember from
        // tracking state changes.
        let submit = new Button()
        submit.label = this.args.def.submit_label || this.intl.t('component.oxisection_form.submit')
        submit.format = this.loading ? "loading" : "submit"
        submit.onClick = this.submit
        buttons.push(submit)

        if (this.args.def.reset) {
            let reset = new Button()
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
        if (field._canAdd === false) return;
        let index = this.fields.indexOf(field);
        let fieldCopy = field.clone();
        fieldCopy.value = "";
        fieldCopy._focusClone = true;
        this.fields.insertAt(index + 1, fieldCopy);
        this.#updateCloneFields();
    }

    @action
    delClone(field) {
        if (field._canDelete === false) return;
        let index = this.fields.indexOf(field);
        this.fields.removeAt(index);
        this.#updateCloneFields();
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
     */
    @action
    setFieldValue(field, value) {
        debug(`oxi-section/form (${this.args.def.action}): setFieldValue (${field.name} = "${value}")`);
        field.value = value;
        this.setFieldError(field, null);

        // check validation regex
        // (only for non-empty fields; the check if a required field is empty
        // is done via HTML <input> attribute required="..." in each component)
        if (field.ecma_match && value !== "") {
            try {
                let re = new RegExp(field.ecma_match);
                if (! re.test(field.value)) {
                    this.setFieldError(field, this.intl.t('component.oxisection_form.validation_failed'));
                    return Promise.resolve();
                }
            }
            catch (err) {
                /* eslint-disable-next-line no-console */
                console.debug(`Invalid validation regex for field ${field.name}: ecma_match = ${field.ecma_match}.\n${err}`);
            }
        }

        // action on change?
        if (!field.actionOnChange) { return Promise.resolve() }

        debug(`oxi-section/form (${this.args.def.action}): executing actionOnChange ("${field.actionOnChange}")`);
        let request = {
            action: field.actionOnChange,
            _sourceField: field.name,
            ...this.#encodeAllFields({ includeEmpty: true }),
        };

        let fields = this.fields;

        return this.content.updateRequest(request, true)
        .then((doc) => {
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

    /**
     * @param field { hash } - field definition (gets passed in via this components' template, i.e. is a reference to this components' "model")
     */
    @action
    setFieldName(field, name) {
        debug(`oxi-section/form (${this.args.def.action}): setFieldName (${field.name} -> ${name})`);
        field.name = name;
    }

    /**
     * @param field { hash } - field definition (gets passed in via this components' template, i.e. is a reference to this components' "model")
     */
    @action
    setFieldError(field, message) {
        debug(`oxi-section/form (${this.args.def.action}): setFieldError (${field.name} = ${message})`);
        let domElement = this.focusFeedback[field._refName]
        if (!domElement) return

        if (!message) message = '' // setCustomValidity() requires empty string to reset error
        field._error = message
        if (domElement) domElement.setCustomValidity(message)
    }

    /**
     * @param fieldNames { array } - the list of field names to encode
     * @param renameMap { Map } - optional mappings: source field name => target field name
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
     * Sub components of oxi-section/form/field should call this by using the
     * modifier
     *   {{on-init @setFocusInfo true}} or
     *   {{on-init @setFocusInfo false}}
     * depending on if it is an editable input field that may sensibly receive
     * the focus.
     * If it is editable, {{on-init @setFocusInfo true}} has to be attached to the DOM element
     * that shall receive the input focus.
     */
    @action
    setFocusInfoFor(field, element, mayFocus) { // 'field' is injected in our template via (fn ...)
        /*
         * A) Focus for newly added clone fields
         */
        if (mayFocus && field._focusClone) {
            element.focus();
            field._focusClone = false;
            return;
        }

        /*
         * B) Initial form rendering focus
         */
        if (this.initialFocussingDone) return;

        // store DOM element if component may receive focus
        // (NOTE: clone fields just "overwrite" the hash key with the same value)
        this.focusFeedback[field._refName] = mayFocus ? element : null;

        // if all form fields sent feedback, choose first focusable field
        let feedbackCount = Object.keys(this.focusFeedback).length;
        if (feedbackCount === this.originalFieldCount) {
            this.focusFirstField();
        }
    }

    focusFirstField() {
        if (!this.args.def.isFirstForm) {
            debug(`oxi-section/form (${this.args.def.action}): we are not the first form - NOT setting focus`);
            return;
        }
        this.initialFocussingDone = true;
        for (const field of this.visibleFields) {
            if (this.focusFeedback[field._refName] !== null) {
                debug(`oxi-section/form (${this.args.def.action}): first focusable field: ${field._refName}`);
                let elementToFocus = this.focusFeedback[field._refName];
                // Wrap the focus() in a setTimeout() as otherwise Ember will complain
                // > You attempted to update `hoverState` on `<wrapperClass:ember197>`,
                // > but it had already been used previously in the same computation.
                // Obviously our {{on-init @setFocusInfo ...}} modifier gets triggered by focus changes.
                setTimeout(() => elementToFocus.focus(), 1);
                return;
            }
        }
        debug(`oxi-section/form (${this.args.def.action}): no focusable field found`);
    }

    @action
    async submit() {
        debug(`oxi-section/form (${this.args.def.action}): submit`);

        // check validity and gather form data
        for (const field of this.fields) {
            if (!field.is_optional && !field.value) {
                this.setFieldError(field, this.intl.t('component.oxisection_form.missing_value'));
                return;
            } else {
                // previously detected error (client- or server-side)?
                if (field._error) return;
            }
        }

        let request = {
            action: this.args.def.action,
            ...this.#encodeAllFields({ includeEmpty: false }),
        };

        let res
        try {
            this.loading = true;
            res = await this.content.updateRequest(request)
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
                        this.setFieldError(clone, faultyField.error);
                    }
                // otherwise just pick the specified clone
                } else {
                    this.setFieldError(clones[faultyField.index], faultyField.error);
                }
            }
        }
    }
}
