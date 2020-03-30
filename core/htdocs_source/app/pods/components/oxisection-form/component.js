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
        let copy = copy(field);
        copy.value = "";
        return fields.insertAt(index + 1, copy);
    }

    @action
    delClone(field) {
        let fields = this.fields;
        let index = fields.indexOf(field);
        return fields.removeAt(index);
    }

    @action
    fireActionOnChange(field) {
        if (!field.actionOnChange) { return }
        debug("oxisection-form: fireActionOnChange (field=" + field.name + ", action=" + field.actionOnChange + ") ");

        let request = {
            action: field.actionOnChange,
            _sourceField: field.name
        };

        let fields = this.fields;
        // build list of unique field names
        let names = [];
        for (const fld of fields) {
            if (names.indexOf(fld.name) < 0) { names.push(fld.name) }
        }
        // add field values to request:
        // either as plain value (1 field of that name)
        // or as array (>1 field with that name)
        for (const name of names) {
            let clones = fields.filter(f => f.name === name);
            if (clones.length > 1) {
                request[name] = clones.map(c => c.value);
            } else {
                request[name] = clones[0].value;
            }
        }
        return getOwner(this).lookup("route:openxpki").sendAjax(request)
        .then((doc) => {
            for (const newField of doc.fields) {
                for (const oldField of fields) {
                    if (oldField.name === newField.name) {
                        let idx = fields.indexOf(oldField);
                        fields[idx] = newField;
                        this.fields = fields;
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
        let fields = (this.fields || []);
        let data = {
            action: this.args.content.action
        };
        // check validity and gather form data
        let isError = false;
        let names = [];
        for (const field of fields) {
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
            if (names.indexOf(field.name) < 0) {
                names.push(field.name);
            }
        }
        debug("oxisection-form: isError = true");
        if (isError) { return }
        for (const name of names) {
            let clones = fields.filter(f => f.name === name);
            data[name] = clones[0].clonable ? clones.map(c => c.value) : clones[0].value;
        }
        this.loading = true;
        return getOwner(this).lookup("route:openxpki").sendAjax(data)
        .then((res) => {
            this.loading = false;
            var ref1;
            let errors = (ref1 = res.status) != null ? ref1.field_errors : void 0;
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
