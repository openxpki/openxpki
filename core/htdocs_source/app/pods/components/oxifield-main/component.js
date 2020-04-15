import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { computed, action } from "@ember/object";
import { equal, bool } from "@ember/object/computed";
import { debug } from '@ember/debug';

export default class OxifieldMainComponent extends Component {
    @equal("args.field.type", "bool") isBool;

    get field() {
        let field = this.args.field.toPlainHash();
        return field;
    }

    get type() {
        return "oxifield-" + this.args.field.type;
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
        this.args.addClone(this.args.field);
    }

    @action
    delClone(field) {
        this.args.delClone(this.args.field);
    }

    @action
    selectFieldType(value, label) {
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
}
