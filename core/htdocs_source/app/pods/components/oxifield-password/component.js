import Component from '@glimmer/component';
import { action } from '@ember/object';

export default class OxifieldPasswordComponent extends Component {
    @action
    onInput(event) {
        this.args.onChange(event.target.value);
    }
}
