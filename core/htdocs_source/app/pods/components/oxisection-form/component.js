import Component from '@ember/component';

var OxisectionFormComponent = Component.extend({
    submitLabel: Em.computed("content.content.submit_label", function() {
        return this.get("content.content.submit_label") || "send";
    }),
    fields: Em.computed("content.content.fields.@each.name", function() {
        let fields = this.get("content.content.fields");
        for (const f of fields) {
            if (typeof f.placeholder === "undefined") {
                f.placeholder = "";
            }
        }
        let clonables = fields.filter(f => f.clonable);
        let names = [];
        for (const clonable of clonables) {
            if (Em.isArray(clonable.value)) {
                let index = fields.indexOf(clonable);
                fields.removeAt(index);
                let values = clonable.value.length ? clonable.value : [""];
                values.forEach((value, i) => {
                    var clone = Em.copy(clonable);
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
                Em.set(clone, "isLast", false);
                Em.set(clone, "canDelete", true);
                Em.set(clones[clones.length - 1], "isLast", true);
                if (clones.length === 1) {
                    Em.set(clones[0], "canDelete", false);
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
    }),
    visibleFields: Em.computed("fields", function() {
        let results = [];
        for (const f of this.get("fields")) {
            if (f.type !== "hidden") {
                results.push(f);
            }
        }
        return results;
    }),
    actions: {
        buttonClick: function(button) {
            return this.sendAction("buttonClick", button);
        },
        addClone: function(field) {
            let fields = this.get("content.content.fields");
            let index = fields.indexOf(field);
            let copy = Em.copy(field);
            copy.value = "";
            return fields.insertAt(index + 1, copy);
        },
        delClone: function(field) {
            let fields = this.get("content.content.fields");
            let index = fields.indexOf(field);
            return fields.removeAt(index);
        },
        valueChange: function(field) {
            if (field.actionOnChange) {
                let fields = this.get("content.content.fields");
                let data = {
                    action: field.actionOnChange,
                    _sourceField: field.name
                };
                let names = [];
                for (const field of fields) {
                    if (names.indexOf(field.name) < 0) {
                        names.push(field.name);
                    }
                }
                for (const name of names) {
                    let clones = fields.filter(f => f.name === name);
                    if (clones.length > 1) {
                        data[name] = clones.map(c => c.value);
                    } else {
                        data[name] = clones[0].value;
                    }
                }
                return this.container.lookup("route:openxpki").sendAjax({
                    data: data
                }).then((doc) => {
                    for (const newField of doc.fields) {
                        for (const oldField of fields) {
                            if (oldField.name === newField.name) {
                                let idx = fields.indexOf(oldField);
                                fields.replace(idx, 1, [Em.copy(newField)]);
                            }
                        }
                    }
                    return null;
                });
            }
        },
        reset: function() {
            return this.sendAction("buttonClick", {
                page: this.get("content.reset")
            });
        },
        submit: function() {
            let action = this.get("content.action");
            let fields = this.get("content.content.fields");
            let data = {
                action: action
            };
            // check validity and gather form data
            let isError = false;
            let names = [];
            for (const field of fields) {
                if (!field.is_optional && !field.value) {
                    isError = true;
                    Em.set(field, "error", "Please specify a value");
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
            if (isError) {
                this.$().find(".btn-loading").removeClass("btn-loading");
                return;
            }
            for (const name of names) {
                let clones = fields.filter(f => f.name === name);
                data[name] = clones[0].clonable ? clones.map(c => c.value) : clones[0].value;
            }
            this.set("loading", true);
            return this.container.lookup("route:openxpki").sendAjax({
                data: data
            }).then((res) => {
                this.set("loading", false);
                var ref1;
                let errors = (ref1 = res.status) != null ? ref1.field_errors : void 0;
                if (errors) {
                    fields = this.get("fields");
                    for (const error of errors) {
                        let clones = fields.filter(f => f.name === error.name);
                        if (typeof error.index === "undefined") {
                            clones.setEach("error", error.error);
                        } else {
                            Em.set(clones[error.index], "error", error.error);
                        }
                    }
                }
            });
        }
    }
});

export default OxisectionFormComponent;