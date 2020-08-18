import Component from '@glimmer/component';
import { action } from "@ember/object";

export default class OxiFieldMainComponent extends Component {
    get isBool() {
        return this.args.field.type === "bool";
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
        if (event.keyCode === 9 && this.field.clonable && this.field.value !== null && this.field.value !== "") {
            event.stopPropagation();
            event.preventDefault();
            this.args.addClone(this.args.field);
        }
    }

    // The sub component should call this with
    //   {{did-insert (fn @mayFocus true)}} or
    //   {{did-insert (fn @mayFocus false)}}
    // depending on if it is an editable input field that may sensibly receive
    // the focus.
    // If it is editable, {{did-insert...}} has to be attached to the element
    // that shall receive the input focus.
    @action
    mayFocus(mayFocus, element) {
        if (mayFocus && this.field._focusClone) element.focus();
        this.args.fieldMayFocus(mayFocus, element);
    }
}
