import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from "@ember/object";
import { debug } from '@ember/debug';

export default class OxiFieldSelectComponent extends Component {
    @tracked customMode = false;

    constructor() {
        super(...arguments);
        this.customMode = this.isCustomValue(this.args.content.value);
        if (this.isStatic) this.args.onChange(this.args.content.options[0].value);
    }

    // returns true if the given value is NOT part of the SELECT's option list
    isCustomValue(val) {
        return (this.options.map(o => o.value).indexOf[val] < 0);
    }

    get options() {
        let options, placeholder, ref;
        /*
          Prepend a "placeholder" (option with empty value) if:
          - "placeholder" is specified or
          - "is_optional" == 1
        */
        placeholder = this.args.content.placeholder;
        if (!placeholder && this.args.content.is_optional) {
            placeholder = "";
        }
        options = (this.args.content.options || []);
        if (typeof placeholder === "string") {
            return [ { label: placeholder, value: "" } ].concat(options);
        } else {
            return options;
        }
    }

    get isStatic() {
        let options = this.args.content.options;
        let isEditable = this.args.content.editable;
        let isOptional = this.args.content.is_optional;
        if (options.length === 1 && !isEditable && !isOptional) {
            return true;
        } else {
            return false;
        }
    }

    // no computed value - no need to refresh later on
    // (and making it computed causes strange side effects when optionSelected() is triggered)
    get sanitizedValue() {
        var value = this.args.content.value;
        if (typeof value === "string" || typeof value === "number") return value;

        var options = this.options;
        let result = options[0] ? (options[0].value || "") : "";
        debug(`oxifield-select (${this.args.content.name}): sanitizedValue ("${this.args.content.value}" -> "${result}")`);
        return result;
    }

    @action
    optionSelected(value) {
        debug("oxifield-select (" + this.args.content.name + "): optionSelected(" + value + ")");
        this.args.onChange(value);
    }


    @action
    toggleCustomMode() {
        this.customMode = !this.customMode;
        // only set default value if the current custom value is not included in SELECT's options
        // (prevents value change if custom mode is just toggled on and off)
        if (!this.customMode && this.isCustomValue(this.args.content.value)) {
            this.args.onChange(this.options[0].value);
        }
    }

    @action
    onCustomInsert(element) {
        element.focus(); // to focus after user hit the toggle button
        // oxi-section/form might steal focus again on initial form rendering
    }

    @action
    onCustomInput(event) {
        this.args.onChange(event.target.value);
    }
}
