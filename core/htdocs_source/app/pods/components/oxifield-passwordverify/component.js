import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, computed, set } from '@ember/object';

export default class OxifieldPasswordverifyComponent extends Component {
    @tracked password = "";
    @tracked confirm = "";
    @tracked isFixed = false;

    @computed("args.content.placeholder")
    get placeholder() {
        return this.args.content.placeholder || "Retype password";
    }

    @action
    setMode() {
        if (this.args.content.value) {
            this.password = this.args.content.value;
            this.isFixed = true;
            set(this.args.content, "value", "");
            this.args.onChange("");
        }
    }

    @action
    setValues() {
        // do passwords match?
        let value = this.password === this.confirm ? this.password : null;
        set(this.args.content, "value", value);
        this.args.onChange(value);
        if (this.password !== this.confirm) {
            set(this.args.content, "error", this.confirm ? "Passwords do not match" : "Please retype password");
        }
    }

    @action
    passwordChange(event) {
        this.password = event.target.value;
        this.confirm = "";
        this.setValues();
    }

    @action
    confirmPasswordChange(event) {
        this.confirm = event.target.value;
        this.setValues();
    }

    @action
    confirmFocusIn() {
        if (this.password !== this.confirm) {
            this.confirm = "";
        }
    }
}
