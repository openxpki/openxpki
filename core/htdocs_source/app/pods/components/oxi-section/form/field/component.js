import Component from '@glimmer/component';
import { action } from "@ember/object";
import { inject } from '@ember/service';
import { getOwner } from '@ember/application';
import ow from 'ow';

export default class OxiFieldMainComponent extends Component {
    @inject('oxi-config') config;

    autofillFieldRefParams = new Map(); // mapping: (source field name) => (parameter name for autocomplete query)

    get isBool() {
        return this.args.field.type === 'bool';
    }

    get field() {
        let field = this.args.field.toPlainHash();
        return field;
    }

    get type() {
        return `oxi-section/form/field/${this.args.field.type}`;
    }

    get sFieldSize() {
        let size;
        let keys = this.args.field.keys;
        if (keys) {
            let keysize = 2;
            size = 7 - keysize;
        } else {
            size = 7;
        }
        return 'col-md-' + size;
    }

    @action
    addClone() {
        this.args.addClone(this.args.field);
    }

    @action
    delClone() {
        this.args.delClone(this.args.field);
    }

    @action
    selectFieldType(value) {
        this.args.setName(value);
    }

    @action
    onChange(value) {
        this.args.setValue(value);
    }

    @action
    onError(message) {
        this.args.setError(message);
    }

    @action
    onKeydown(event) {
        // ENTER --> submit form
        if (event.keyCode === 13 && this.field.type !== "textarea") {
            event.stopPropagation();
            event.preventDefault();
            this.args.submit();
        }
        // TAB --> clonable fields: add another clone
        if (event.keyCode === 9 && this.field._lastCloneInGroup && this.field.value !== null && this.field.value !== "") {
            event.stopPropagation();
            event.preventDefault();
            this.addClone();
        }
    }

    get autofill() {
        return this.args.field.autofill;
    }

    @action
    initAutofill(setValueCallback) {
        if (!this.autofill) return;

        // type validation
        ow(this.autofill, 'autofill', ow.object.exactShape({
            'request': ow.object.exactShape({
                'url': ow.string,
                'method': ow.optional.string.oneOf(['GET', 'POST']),
                'params': ow.optional.object.exactShape({
                    'user': ow.optional.object,
                    'static': ow.optional.object,
                }),

            }),
            'trigger': ow.string.oneOf(['auto', 'button']),
        }));

        let ref_params = this.autofill.request?.params?.user;
        if (ref_params) {
            for (const [param_name, ref_field] of Object.entries(ref_params)) {
                // param_name - parameter name for autocomplete query
                // ref_field - name of another form field whose value to use
                this.autofillFieldRefParams.set(ref_field, param_name);
            }
        }

        if (this.autofill.trigger == 'auto') {
            this.autofillQuery().then(doc => {
                console.debug("Autofill response", doc);
                setValueCallback(JSON.stringify(doc));
            });
        }
    }

    @action
    autofillQuery() {
        // resolve referenced fields and their values
        let data = {
            ...this.args.encodeFields(this.autofillFieldRefParams.keys(), this.autofillFieldRefParams), // returns an Object
            ...(this.autofill.request.params.static || {}),
        };

        return getOwner(this).lookup("route:openxpki").backendFetch({
            url: this.autofill.request.url,
            method: this.autofill.request.method || 'GET',
            data,
        }).then((response) => {
            console.log("AUTOFILL response: ", response)
            // If OK: unpack JSON data
            if (response.ok) {
                return response.json();
            }
            // Handle non-2xx HTTP status codes
            else {
                console.error(response.status);
                return null;
            }
        });
    }
}
