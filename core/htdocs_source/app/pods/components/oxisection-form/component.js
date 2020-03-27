import Component from '@glimmer/component';
import { action, computed, set } from "@ember/object";
import { tracked } from '@glimmer/tracking';
import { getOwner } from '@ember/application';
import { copy } from '@ember/object/internals';
import { isArray } from '@ember/array';
import { debug } from '@ember/debug';

export default class OxisectionFormComponent extends Component {
    @tracked loading = false;

    get submitLabel() {
        return this.args.content.content.submit_label || "send";
    }

    @computed("args.content.content.fields")
    get fields() {
        let fields = this.args.content.content.fields;
        for (const f of fields) {
            if (typeof f.placeholder === "undefined") {
                f.placeholder = "";
            }
        }
        let clonables = fields.filter(f => f.clonable);
        let names = [];
        for (const clonable of clonables) {
            if (isArray(clonable.value)) {
                let index = fields.indexOf(clonable);
                fields.removeAt(index);
                let values = clonable.value.length ? clonable.value : [""];
                values.forEach((value, i) => {
                    var clone = copy(clonable);
                    clone.value = value;
                    fields.insertAt(index + i, clone);
                });
            }
            if (names.indexOf(clonable.name) < 0) {
                names.push(clonable.name);
            }
        }
        for (const name of names) {
            let clones = fields.filter(f => f.name === name);
            for (const clone of clones) {
                set(clone, "isLast", false);
                set(clone, "canDelete", true);
                set(clones[clones.length - 1], "isLast", true);
                if (clones.length === 1) {
                    set(clones[0], "canDelete", false);
                }
            }
        }
        for (const field of fields) {
            if (field.value && typeof field.value === "object") {
                field.name = field.value.key;
                field.value = field.value.value;
            }
        }
        return fields;
    }

    @computed("fields")
    get visibleFields() {
        return this.fields.filter(f => f.type !== "hidden");
    }

    @action
    buttonClick(button) {
        this.args.buttonClick(button);
    }

    @action
    addClone(field) {
        let fields = this.args.content.content.fields;
        let index = fields.indexOf(field);
        let copy = copy(field);
        copy.value = "";
        return fields.insertAt(index + 1, copy);
    }

    @action
    delClone(field) {
        let fields = this.args.content.content.fields;
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

        let fields = this.args.content.content.fields;
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
                        fields.replace(idx, 1, [copy(newField)]);
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
        let fields = (this.args.content.content.fields || []);
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
