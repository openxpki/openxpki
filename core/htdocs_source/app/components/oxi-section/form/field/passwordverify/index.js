import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';

/**
 * Password-with-confirmation field: two inputs that must match before a value is submitted.
 * When `content.value` is pre-filled the first field is shown as read-only (fixed password mode).
 *
 * @param { object } content - Plain field hash (from {@link Field}).
 * @param { string } [content.value] - Pre-filled password (activates fixed-password mode).
 * @param { string } [content.placeholder] - Placeholder for the confirmation input. Default: i18n string.
 * @param { boolean } [content.is_optional] - When falsy both inputs are marked required.
 * @param { function } onChange - Callback invoked with the confirmed password string, or `null` if inputs do not match.
 * @param { function } onError - Callback invoked with an error message when passwords do not match.
 * @param { function } setFocusInfo - Callback to register the first editable input for focus management.
 * @param { string } [error] - Validation error message to display below the inputs.
 *
 * @class OxiSection::Form::Field::Passwordverify
 * @extends Component
 */
export default class OxiFieldPasswordverifyComponent extends Component {
    @service('intl') intl;

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
