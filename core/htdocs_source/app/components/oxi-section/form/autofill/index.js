import Component from '@glimmer/component';
import { action } from "@ember/object";
import { service } from '@ember/service';
import { debug } from '@ember/debug';
//import { assert, optional, union, enums, object, type, boolean, string } from 'superstruct';

/**
 * Implements autofill functionality, e.g. shows a button and sends a request
 * the the backend on button click (or when component is intialized).
 *
 * To use the autofill functionality in any form field, the field's template
 * needs to include the following code:
 * ```html
 * {{#if (has-block "autofill")}}
 *   {{yield this.disableAutofillButton this.setAutofillValue to="autofill"}}
 * {{/if}}
 * ```
 * @param { object } config - Autofill configuration.
 * @param { object } config.request - Backend request config.
 * @param { string } config.request.url - URL to call.
 * @param { string } [config.request.method] - HTTP method (`'GET'` or `'POST'`). Default: `'GET'`
 * @param { object } [config.request.params] - Parameter sources.
 * @param { object } [config.request.params.user] - Maps backend param names to sibling field names whose values to include.
 * @param { object } [config.request.params.static] - Static key/value pairs always sent with the request.
 * @param { string } config.label - Human-readable label used in button text and result messages.
 * @param { string } [config.button_label] - Custom button label (overrides the generated one).
 * @param { boolean } [config.autorun] - Trigger the request automatically on component init.
 * @param { string } [config.convert] - Response conversion hint (reserved for future use).
 * @param { boolean } [disabled] - Set to `true` to disable the button.
 * @param { function } encodeFields - Encodes the given form fields (see {@link OxiSection::Form}).
 * @param { function } valueSetter - Processes the server response (called with the response data).
 * @class OxiSection::Form::AutoFill
 * @extends Component
 */

export default class Autofill extends Component {
    @service('intl') intl;
    @service('oxi-backend') backend;

    request;
    autorun;
    label;
    button_label;

    encodeFields;

    fieldRefParams = new Map(); // mapping: (source field name) => (parameter name for autocomplete query)
    valueSetter; // callback passed in from the actual component

    convert;

    constructor() {
        super(...arguments);

// TODO Reactivate type checking (with "superstruct", not "ow"!) once we drop IE11 support
/*
        NOTE: we could also use one of these:
          https://www.npmjs.com/package/joi
          https://www.npmjs.com/package/yup (too many issues?)
          https://www.npmjs.com/package/ajv (too bloated? - but good quality)

        // type validation
        assert(this.args.config, object({
            'request': object({
                'url': string(),
                'method': optional(enums(['GET', 'POST'])),
                'params': optional(object({
                    'user': optional(type({})),
                    'static': optional(type({})),
                })),
            }),
            'label': string(),
            'convert': optional(string()),
            'autorun': optional(union(boolean(), enums([0, 1, '0', '1']))),
            'button_label': optional(string()),
        }));
*/

        // Config
        this.request = this.args.config.request;
        this.autorun = this.args.config.autorun;
        this.label = this.args.config.label;
        this.button_label = this.args.config.button_label;

        let ref_params = this.request?.params?.user;
        if (ref_params) {
            for (const [param_name, ref_field] of Object.entries(ref_params)) {
                // param_name - parameter name for autocomplete query
                // ref_field - name of another form field whose value to use
                this.fieldRefParams.set(ref_field, param_name);
            }
        }

        this.convert = (response) => response.text();
        // if (this.args.config?.convert.matches(/^json:/) {
        //    this.convert = (response) => response.json() ... ;
        // }

        // Function to encode fields (from form)
        // TODO Reactivate type checking once we drop IE11 support
        //ow(this.args.encodeFields, 'encodeFields', ow.function);
        this.encodeFields = this.args.encodeFields;

        // Function to set field value (from field instance)
        // TODO Reactivate type checking once we drop IE11 support
        //ow(this.args.valueSetter, 'valueSetter', ow.function);
        this.valueSetter = this.args.valueSetter;

        if (this.autorun) this.query();
    }

    /**
     * Resolves referenced sibling field values, sends the configured HTTP request to the backend,
     * and passes the response text to `valueSetter`.
     * @memberOf OxiSection::Form::AutoFill
     */
    @action
    query() {
        // resolve referenced fields and their values
        let data = {
            ...this.encodeFields(this.fieldRefParams.keys(), this.fieldRefParams), // returns an Object
            ...(this.request.params.static || {}),
        };

        return this.backend.request({
            url: this.request.url,
            method: this.request.method || 'GET',
            data,
        }).then((response) => {
            debug("Autofill: response = " + JSON.stringify(response));
            // If OK: unpack JSON data
            if (response?.ok) {
                let label = this.intl.t('autofill.result', { target: this.label });
                return this.convert(response).then(data => {
                    debug("Autofill: data = " + data);
                    return this.valueSetter(data, label);
                });
            }
            // Handle non-2xx HTTP status codes
            else {
                console.error(response.status);
                return null;
            }
        });
    }

    /**
     * Returns the button label, using `button_label` if set, otherwise the i18n key `autofill.button`
     * parameterized with `label`.
     * @memberOf OxiSection::Form::AutoFill
     */
    get buttonLabel() {
        return (this.button_label
            ? this.button_label
            : this.intl.t('autofill.button', { target: this.label })
        );
    }
}
