import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, computed } from "@ember/object";
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

    @computed("args.content.{options,prompt,is_optional}")
    get options() {
        var options, prompt, ref;
        prompt = this.args.content.prompt;
        if (!prompt && this.args.content.is_optional) {
            prompt = "";
        }
        options = (this.args.content.options || []);
        if (typeof prompt === "string" && prompt !== ((ref = options[0]) != null ? ref.label : void 0)) {
            return [ { label: prompt, value: "" } ].concat(options);
        } else {
            return options;
        }
    }

    @computed("args.content.{options,editable,is_optional}")
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
