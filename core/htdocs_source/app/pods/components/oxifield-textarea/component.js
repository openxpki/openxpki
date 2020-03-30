import Component from '@glimmer/component';
import { action, set } from '@ember/object';

export default class OxifieldTextareaComponent extends Component {
    get cols() {
        return this.args.content.textAreaSize.width ?? 150;
    }

    get rows() {
        return this.args.content.textAreaSize.height ?? 10;
    }

    @action
    onInput(event) {
        // we need to update using set() because this.args.content.value is not a @tracked property
        set(this.args.content, "value", event.target.value);
        this.args.onChange(event.target.value);
    }
}
