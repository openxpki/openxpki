import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, computed } from '@ember/object';

export default class OxiFieldPasswordverifyComponent extends Component {
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
            this.args.onChange("");
        }
    }

    @action
    setValues() {
        // do passwords match?
        let value = this.password === this.confirm ? this.password : null;
        this.args.onChange(value);
        if (this.password !== this.confirm) {
            let msg = this.confirm ? "Passwords do not match" : "Please retype password";
            this.args.onError(msg);
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
