import Component from '@glimmer/component';
import { action } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { getOwner } from '@ember/application';
import { isArray } from '@ember/array';
import { inject } from '@ember/service';
import { debug } from '@ember/debug';

class Field {
    /*
     * Common
     */
    type;
    name;
    _refName; // internal use: original name, needed for dynamic input fields where 'name' can change
    value;
    label;
    is_optional;
    tooltip;
    placeholder;
    actionOnChange;
    @tracked error;
    /*
     * Clonable fields
     */
    clonable = false;
    max;
    // following attributes need to be tracked because they are updated after the field list
    @tracked _canDelete;
    @tracked _canAdd;
    @tracked _lastCloneInGroup;
    _focusClone = false; // initially focus clone after adding (done in setFocusInfo() below after callback by oxisection/form/field)
    /*
     * Dynamic input fields
     */
    keys;
    /*
     * oxisection/form/field/datetime
     */
    //
    timezone;
    /*
     * oxisection/form/field/select
     */
    options;
    prompt;
    editable;
    /*
     * oxisection/form/field/static
     */
    verbose;
    /*
     * oxisection/form/field/text
     */
    autocomplete_query;

    static fromHash(sourceHash) {
        let instance = new this(); // "this" in static methods refers to class
        for (const attr of Object.keys(sourceHash)) {
            // @tracked properties are prototype properties, the others instance properties
            if (! (this.prototype.hasOwnProperty(attr) || instance.hasOwnProperty(attr))) {
                /* eslint-disable-next-line no-console */
                console.error(
                    `oxi-section/form: unknown property "${attr}" in field "${sourceHash.name}". ` +
                    `If it's a new property, please add it to class 'Field' defined in app/pod/components/oxi-section/form/component.js`
                );
            }
            else {
                instance[attr] = sourceHash[attr];
            }
        }
        return instance;
    }

    clone() {
        let field = new Field();
        Object.keys(Object.getPrototypeOf(this)).forEach(k => field[k] = this[k]); // @tracked properties
        Object.keys(this).forEach(k => field[k] = this[k]);                        // public class properties
        return field;
    }

    toPlainHash() {
        let hash = {};
        Object.keys(Object.getPrototypeOf(this)).forEach(k => hash[k] = this[k]); // @tracked properties
        Object.keys(this).forEach(k => hash[k] = this[k]);                        // public class properties
        return hash;
    }
}

/**
 * Draws a form.
 *
 * @module oxi-section/form
 * @param { hash } def - section definition
 * ```javascript
 * {
 *     ... // TODO
 * }
 * ```
 */
export default class OxiSectionFormComponent extends Component {
    @inject('intl') intl;

    @tracked loading = false;
    @tracked fields = [];

    clonableRefNames = [];
    focusFeedback = {}; // gets filled with the field feedback if they may receive the focus
    initialFocussingDone = false;

    hiddenFieldFilter(f) {
        return f.type !== "hidden" && f.type !== "encrypted";
    }

    constructor() {
        super(...arguments);
        this.fields = this._prepareFields(this.args.def.fields);
        this._updateCloneFields();
    }

    _prepareFields(fields) {
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

    _updateCloneFields() {
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
        this._updateCloneFields();
    }

    @action
    delClone(field) {
        if (field._canDelete === false) return;
        let index = this.fields.indexOf(field);
        this.fields.removeAt(index);
        this._updateCloneFields();
    }

    // Turns all (non-empty) fields into request parameters (returns an Object)
    _encodeAllFields({ includeEmpty = false }) {
        return this._encodeFields({
            includeEmpty,
            fieldNames: this.uniqueFieldNames,
        });
    }

    _encodeFields({ fieldNames, includeEmpty = false, renameMap = new Map() }) {
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
        if (field.error) field.error = null;

        // action on change?
        if (!field.actionOnChange) { return }

        debug(`oxi-section/form (${this.args.def.action}): executing actionOnChange ("${field.actionOnChange}")`);
        let request = {
            action: field.actionOnChange,
            _sourceField: field.name,
            ...this._encodeAllFields({ includeEmpty: true }),
        };

        let fields = this.fields;

        return getOwner(this).lookup("route:openxpki").sendAjax(request, true)
        .then((doc) => {
            for (const newField of this._prepareFields(doc.fields)) {
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
        field.error = message;
    }

    /**
     * @param fieldNames { array } - the list of field names to encode
     * @param renameMap { Map } - optional mappings: source field name => target field name
     */
    @action
    encodeFields(fieldNames, renameMap) {
        debug(`oxi-section/form (${this.args.def.action}): encodeFields ()`);

        return this._encodeFields({ fieldNames, renameMap, includeEmpty: true });
    }

    get originalFieldCount() {
        return this.args.def.fields.filter(this.hiddenFieldFilter).length;
    }

    /*
    Sub components of oxi-section/form/field should call this by using the
    modifier
      {{may-focus this true}} or
      {{may-focus this false}}
    depending on if it is an editable input field that may sensibly receive
    the focus.
    If it is editable, {{may-focus...}} has to be attached to the DOM element
    that shall receive the input focus.
    */
    @action
    setFocusInfo(field, mayFocus, element) { // 'field' is injected in our template via (fn ...)
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
                // Obviously our {{may-focus}} modifier gets triggered by focus changes.
                setTimeout(() => elementToFocus.focus(), 1);
                return;
            }
        }
        debug(`oxi-section/form (${this.args.def.action}): no focusable field found`);
    }

    @action
    reset() {
        this.args.buttonClick({ page: this.args.def.reset });
    }

    @action
    submit() {
        debug(`oxi-section/form (${this.args.def.action}): submit`);

        // check validity and gather form data
        let isError = false;
        for (const field of this.fields) {
            if (!field.is_optional && !field.value) {
                isError = true;
                field.error = this.intl.t('component.oxisection_form.missing_value');
            } else {
                if (field.error) {
                    isError = true;
                }
            }
        }
        if (isError) { return }

        let request = {
            action: this.args.def.action,
            ...this._encodeAllFields({ includeEmpty: false }),
        };

        this.loading = true;
        return getOwner(this).lookup("route:openxpki").sendAjax(request)
        .then((res) => {
            this.loading = false;
            if (res.status != null && res.status.field_errors !== undefined) {
                for (const faultyField of res.status.field_errors) {
                    let clones = this.fields.filter(f => f.name === faultyField.name);
                    if (typeof faultyField.index === "undefined") {
                        clones.setEach("error", faultyField.error);
                    } else {
                        clones[faultyField.index].error = faultyField.error;
                    }
                }
            }
        })
        .finally(() => this.loading = false);
    }
}
