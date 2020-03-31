import Component from '@glimmer/component';
import { action } from '@ember/object';

export default class OxifieldTextareaComponent extends Component {
    get cols() {
        return this.args.content.textAreaSize.width ?? 150;
    }

    get rows() {
        return this.args.content.textAreaSize.height ?? 10;
    }

    @action
    onInput(event) {
        this.args.onChange(event.target.value);
    }
}
