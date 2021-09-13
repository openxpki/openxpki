import Component from '@glimmer/component';
import { action } from "@ember/object";
import { inject } from '@ember/service';
import { debug } from '@ember/debug';

export default class OxiFieldMainComponent extends Component {
    @inject('oxi-backend') backend;
    @inject('intl') intl;

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
        return 'col-lg-' + size;
    }

    get autofillConfig() {
        return this.args.field.autofill ? this.args.field.autofill : null;
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
