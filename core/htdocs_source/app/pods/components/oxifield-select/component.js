import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, computed, observer } from "@ember/object";
import { next } from '@ember/runloop'

export default class OxifieldSelectComponent extends Component {
    @tracked customMode = false;

    @computed("content.{options,prompt,is_optional}")
    get options() {
        var options, prompt, ref;
        prompt = this.args.content.prompt;
        if (!prompt && this.args.content.is_optional) {
            prompt = "";
        }
        options = this.args.content.options;
        if (typeof prompt === "string" && prompt !== ((ref = options[0]) != null ? ref.label : void 0)) {
            return [
                {
                    label: prompt,
                    value: ""
                }
            ].concat(options);
        } else {
            return options;
        }
    }

    @computed("content.{options,editable,is_optional}")
    get isStatic() {
        var isEditable, isOptional, options;
        options = this.args.content.options;
        isEditable = this.args.content.editable;
        isOptional = this.args.content.is_optional;
        if (options.length === 1 && !isEditable && !isOptional) {
            this.args.content.value = options[0].value;
            return true;
        } else {
            return false;
        }
    }

    @computed("options", "content.value")
    get isCustomValue() {
        var o, value, values;
        values = (function() {
            var i, len, ref, results;
            ref = this.options;
            results = [];
            for (i = 0, len = ref.length; i < len; i++) {
                o = ref[i];
                results.push(o.value);
            }
            return results;
        }).call(this);
        value = this.args.content.value;
        var isCustom = values.indexOf[value] < 0;
        this.customMode = isCustom;
        return isCustom;
    }


/*
change, not in list: custom
click: toggle
    to NOT customized: reset value


*/
    @computed("content.value")
    get sanitizedValue() {
        var value = this.args.content.value;
        if (typeof value === "string") return value;

        var options = this.options;
        var ref;
        return ((ref = options[0]) != null ? ref.value : void 0) || "";
    }

    @action
    toggleCustomMode() {
        this.toggleProperty("customMode");
        if (!this.customMode) {
            if (this.isCustomValue) {
                this.args.content.value = this.options[0].value;
            }
        }
        next(this, () => {
            this.$("input,select")[0].focus();
        });
    }

    @action
    optionSelected(value, label) {
        this.args.content.value = value;
    }
}
