import Component from '@glimmer/component';
import { action, computed, set } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { getOwner } from '@ember/application';
import { isArray } from '@ember/array';
import { debug } from '@ember/debug';

class Field {
    @tracked type;
    @tracked name;
    @tracked _refName;
    @tracked value;
    @tracked label;
    @tracked tooltip;
    @tracked prompt;
    @tracked placeholder;
    @tracked clonable;
    @tracked options;
    @tracked keys;
    @tracked is_optional;
    @tracked canDelete;
    @tracked actionOnChange;

    clone() {
        let field = new Field();
        Object.keys(Object.getPrototypeOf(this)).forEach(k => field[k] = this[k]);
        return field;
    }
}

export default class OxisectionFormComponent extends Component {
    @tracked loading = false;
    @tracked fields = [];

    constructor() {
        super(...arguments);
        this.fields = this._prepareFields(this.args.content.content.fields);
    }

    get submitLabel() {
        return this.args.content.content.submit_label || "send";
    }

    _prepareFields(fields) {
        let result = [];
        let clonableRefNames = [];
        for (const fieldHash of fields) {
            // convert hash into field
            let field = new Field();
            for (const attr of Object.keys(fieldHash)) {
                if (! Field.prototype.hasOwnProperty(attr)) {
                    console.error(`oxisection-form: unknown field property "${attr}" (field.name = "${fieldHash.name}")`);
                }
                else {
                    field[attr] = fieldHash[attr];
                }
            }

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
                // process presets (array of key/value pairs): insert clones
                // NOTE: this does NOT support dynamic input fields
                if (isArray(field.value)) {
                    let values = field.value.length ? field.value : [""];
                    // add clones to field list
                    result.push(...values.map(v => {
                        let clone = field.clone();
                        // dynamic input fields: presets of clones are key/value hashes.
                        // we need to convert `value: { key: NAME, value: VALUE }` to `name: NAME, value: VALUE`
                        if (v && typeof v === "object") {
                            clone.name = v.key;
                            clone.value = v.value;
                        }
                        // standard fields: presets of clones are plain values
                        else {
                            clone.value = v;
                        }
                        return clone;
                    }));
                }
                if (clonableRefNames.indexOf(field._refName) < 0) {
                    clonableRefNames.push(field._refName);
                }
            }
        }
        for (const name of clonableRefNames) {
            let clones = result.filter(f => f._refName === name);
            for (const clone of clones) { clone.canDelete = true; }
            if (clones.length === 1) {
                clones[0].canDelete = false;
            }
        }

        return result;
    }

    get uniqueFieldNames() {
        let result = [];
        for (const field of this.fields) {
            if (result.indexOf(field.name) < 0) { result.push(field.name) }
        }
        return result;
    }

    get visibleFields() {
        return this.fields.filter(f => f.type !== "hidden");
    }

    @action
    buttonClick(button) {
        this.args.buttonClick(button);
    }

    @action
    addClone(field) {
        let fields = this.fields;
        let index = fields.indexOf(field);
        let fieldCopy = field.clone();
        fieldCopy.value = "";
        fields.insertAt(index + 1, fieldCopy);
    }

    @action
    delClone(field) {
        let fields = this.fields;
        let index = fields.indexOf(field);
        fields.removeAt(index);
    }

    // Turns all fields into request parameters
    _fields2request() {
        let result = [];
        // send clonables as list (even if there's only one field) and other fields as plain values
        for (const name of this.uniqueFieldNames) {
            let potentialClones = this.fields.filter(f => f.name === name);
            result[name] = potentialClones[0].clonable
                ? potentialClones.map(c => c.value)
                : potentialClones[0].value;
        }
        return result;
    }

    /**
     * @param field { hash } - field definition (gets passed in via this components' template, i.e. is a reference to this components' "model")
     */
    @action
    setFieldValue(field, value) {
        debug(`oxisection-form: setFieldValue (${field.name} = "${value}")`);
        field.value = value;

        // action on change?
        if (!field.actionOnChange) { return }

        debug(`oxisection-form: executing actionOnChange ("${field.actionOnChange}")`);
        let request = {
            action: field.actionOnChange,
            _sourceField: field.name,
            ...this._fields2request(),
        };

        let fields = this.fields;

        return getOwner(this).lookup("route:openxpki").sendAjax(request)
        .then((doc) => {
            for (const newField of doc.fields) {
                for (const oldField of fields) {
                    if (oldField.name === newField.name) {
                        let idx = fields.indexOf(oldField);
                        fields[idx] = newField;
                        this.fields = fields; // trigger refresh FIXME remove as Array changes are auto-tracked?! (Ember enhances JS array as https://api.emberjs.com/ember/3.17/classes/Ember.NativeArray)
                    }
                }
            }
            return null;
        });
    }

    /**
     * @param field { hash } - field definition (gets passed in via this components' template, i.e. is a reference to this components' "model")
     */
    @action
    setFieldName(field, name) {
        debug(`oxisection-form: setFieldName (${field.name} -> ${name})`);
        field.name = name;
    }

    /**
     * @param field { hash } - field definition (gets passed in via this components' template, i.e. is a reference to this components' "model")
     */
    @action
    setFieldError(field, message) {
        debug(`oxisection-form: setFieldError (${field.name})`);
        field.error = message;
    }

    @action
    reset() {
        this.args.buttonClick({ page: this.args.content.reset });
    }

    @action
    submit() {
        debug("oxisection-form: submit");

        // check validity and gather form data
        let isError = false;
        for (const field of this.fields) {
            if (!field.is_optional && !field.value) {
                isError = true;
                set(field, "error", "Please specify a value");
            } else {
                if (field.error) {
                    isError = true;
                } else {
                    delete field.error;
                }
            }
        }
        if (isError) { return }

        let data = {
            action: this.args.content.action,
            ...this._fields2request(),
        };

        this.loading = true;
        return getOwner(this).lookup("route:openxpki").sendAjax(data)
        .then((res) => {
            this.loading = false;
            let errors = res.status != null ? res.status.field_errors : null;
            if (errors) {
                for (const error of errors) {
                    let clones = this.fields.filter(f => f.name === error.name);
                    if (typeof error.index === "undefined") {
                        clones.setEach("error", error.error);
                    } else {
                        set(clones[error.index], "error", error.error);
                    }
                }
            }
        })
        .finally(() => this.loading = false);
    }
}
