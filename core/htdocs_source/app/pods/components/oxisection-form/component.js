import Component from '@glimmer/component';
import { action, computed, set } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { getOwner } from '@ember/application';
import { copy } from '@ember/object/internals';
import { isArray } from '@ember/array';
import { debug } from '@ember/debug';

export default class OxisectionFormComponent extends Component {
    @tracked loading = false;
    @tracked _fields = [];

    constructor() {
        super(...arguments);
        this.fields = this.args.content.content.fields;
    }

    get submitLabel() {
        return this.args.content.content.submit_label || "send";
    }

    set fields(fields) {
        for (const field of fields) {
            // dynamic input fields will change the form field name depending on the
            // selected option, so we need an internal reference to the original name ("refName")
            field.refName = field.name;
            // set placeholder
            if (typeof field.placeholder === "undefined") {
                field.placeholder = "";
            }
        }

        // process clonable field presets
        // NOTE: this does NOT support dynamic input fields
        let clonableRefNames = [];
        for (const clonable of fields.filter(f => f.clonable)) {
            // if there are already key/value pairs given for a clonable field:
            // remove the original (empty) field and replace it by cloned and filled fields
            if (isArray(clonable.value)) {
                let index = fields.indexOf(clonable);
                fields.removeAt(index);
                let values = clonable.value.length ? clonable.value : [""];
                // insert clones into field list
                values.forEach((v, i) => {
                    var clone = copy(clonable);
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
                    fields.insertAt(index + i, clone);
                });
            }
            if (clonableRefNames.indexOf(clonable.refName) < 0) {
                clonableRefNames.push(clonable.refName);
            }
        }
        for (const name of clonableRefNames) {
            let clones = fields.filter(f => f.refName === name);
            for (const clone of clones) { set(clone, "canDelete", true) }
            if (clones.length === 1) {
                set(clones[0], "canDelete", false);
            }
        }

        this._fields = fields;
    }

    get fields() {
        return this._fields;
    }

    get uniqueFieldNames() {
        let result = [];
        for (const field of this._fields) {
            if (result.indexOf(field.name) < 0) { result.push(field.name) }
        }
        return result;
    }

    @computed("_fields")
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
        let fieldCopy = copy(field);
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

    @action
    fireActionOnChange(field) {
        if (!field.actionOnChange) { return }
        debug("oxisection-form: fireActionOnChange (field=" + field.name + ", action=" + field.actionOnChange + ") ");

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

    @action
    reset() {
        return this.sendAction("buttonClick", {
            page: this.args.content.reset,
        });
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
