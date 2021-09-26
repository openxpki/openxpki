import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { inject } from '@ember/service';

export default class OxiFieldPasswordverifyComponent extends Component {
    @inject('intl') intl;

    @tracked password = "";
    @tracked confirm = "";
    @tracked isFixed = false;

    get placeholder() {
        return this.args.content.placeholder || this.intl.t('component.oxifield_passwordverify.retype_password');
    }

    constructor() {
        super(...arguments);

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
        if (this.password !== this.confirm) {
            let msg = this.confirm
                ? this.intl.t('component.oxifield_passwordverify.error_no_match')
                : this.intl.t('component.oxifield_passwordverify.error_retype_password');
            this.args.onError(msg);
        }
        else {
            this.args.onChange(value);
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
}
