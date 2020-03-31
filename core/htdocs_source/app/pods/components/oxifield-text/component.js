import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';

export default class OxifieldTextComponent extends Component {
    @action
    onInput(event) {
        this.args.onChange(event.target.value);
    }
}
