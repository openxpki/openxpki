import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { computed, action, set as emSet } from "@ember/object";
import { equal, bool } from "@ember/object/computed";
import { debug } from '@ember/debug';

export default class OxifieldMainComponent extends Component {
    @equal("args.field.type", "bool") isBool;
    @bool("args.field.error") hasError;

    @computed("args.field.type")
    get type() {
        return "oxifield-" + this.args.field.type;
    }

    @computed("args.field.size", "args.field.keysize")
    get sFieldSize() {
        var keys, keysize, size;
        keys = this.args.field.keys;
        size = this.args.field.size;
        keysize = this.args.field.keysize;
        if (!size) {
            if (keys) {
                if (!keysize) { keysize = 2 }
                size = 7 - keysize;
            } else {
                size = 7;
            }
        }
        return 'col-md-' + size;
    }

    /*
    keyPress: function(event) {
        if (event.keyCode === 9) {
            if (this.args.field.clonable) {
                if (this.args.field.value) {
                    this.addClone(this.args.field);
                    event.stopPropagation();
                    return event.preventDefault();
                }
            }
        }
    },
    */

    @action
    addClone(field) {
        this.addClone(this.args.field);
    }

    @action
    delClone(field) {
        this.delClone(this.args.field);
    }

    @action
    optionSelected(value, label) {
        emSet(this.args.field, "value", value);
        emSet(this.args.field, "error", null);
        this.onChange()
    }

    @action
    onChange() {
        debug("oxifield-main: onChange");
        emSet(this.args.field, "error", null);
        this.args.fieldChanged(this.args.field);
    }
}
