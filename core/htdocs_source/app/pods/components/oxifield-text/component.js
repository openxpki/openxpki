import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, set } from '@ember/object';

export default class OxifieldTextComponent extends Component {
    @action
    onInput(event) {
        // we need to update using set() because this.args.content.value is not a @tracked property
        set(this.args.content, "value", event.target.value);
        this.args.onChange(event.target.value);
    }
}
