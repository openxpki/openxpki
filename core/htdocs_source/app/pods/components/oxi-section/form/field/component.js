import Component from '@glimmer/component';
import { action } from "@ember/object";
import { inject } from '@ember/service';
import { debug } from '@ember/debug';

export default class OxiFieldMainComponent extends Component {
    @inject('oxi-backend') backend;
    @inject('intl') intl;
    @inject('oxi-config') config;

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

    /*
     * Options for <Tippy>, i.e. Popper.js
     * See
     *   https://atomiks.github.io/tippyjs/v6/all-props/#popperoptions and
     *   https://popper.js.org/docs/v2/modifiers/prevent-overflow/
     */
    get popperOptions() {
        return {
            modifiers: [
                {
                    name: 'preventOverflow',
                    options: {
                        tether: false, // allow Popper to leave its overflow area to always stick with reference?
                    },
                },
            ],
        }
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
        return this.args.setValue(value);
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
}
