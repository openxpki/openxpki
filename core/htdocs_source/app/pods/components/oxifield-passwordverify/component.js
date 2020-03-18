import Component from '@ember/component';

const OxifieldPasswordverifyComponent = Component.extend({
    password: "",
    confirm: "",
    confirmFocus: false,
    isFixed: false,
    setMode: Em.on("init", function() {
        if (this.get("content.value")) {
            this.set("password", this.get("content.value"));
            this.set("isFixed", true);
            return this.set("content.value", "");
        }
    }),
    showConfirm: Em.computed("password", "confirm", "confirmFocus", function() {
        return this.get("password") !== this.get("confirm") || this.get("confirmFocus");
    }),
    valueSetter: Em.observer("password", "confirm", function() {
        let password = this.get("password");
        let confirm = this.get("confirm");
        if (password === confirm) {
            return this.set("content.value", password);
        } else {
            return this.set("content.value", null);
        }
    }),
    placeholder: Em.computed("content.placeholder", function() {
        return this.get("content.placeholder") || "Retype password";
    }),
    label: "",
    updateValue: Em.observer("label", function() {
        let label = this.get("label");
        let values = this.get("content.options").filter(o => o.label === label).map(o => o.value);
        if (values.length === 1) {
            return this.set("content.value", values[0]);
        } else {
            return this.set("content.value", label);
        }
    }),
    passwordChange: Em.observer("password", function() {
        this.set("confirm", "");
        return this.set("content.error", null);
    }),
    actions: {
        confirmFocusIn: function() {
            this.set("confirmFocus", true);
            if (this.get("password") !== this.get("confirm")) {
                return this.set("confirm", "");
            }
        },
        hintRetype: function() {
            if (this.get("password") && !this.get("confirm")) {
                return this.set("content.error", "Please retype password");
            }
        },
        confirmFocusOut: function() {
            this.set("confirmFocus", false);
            if (this.get("password") !== this.get("confirm")) {
                if (this.get("confirm")) {
                    this.set("content.error", "Passwords do not match");
                    return this.set("confirm", "");
                } else {
                    return this.set("content.error", "Please retype password");
                }
            }
        }
    }
});

export default OxifieldPasswordverifyComponent;