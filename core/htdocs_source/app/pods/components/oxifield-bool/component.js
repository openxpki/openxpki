import Component from '@glimmer/component';
import { action } from '@ember/object';

export default class OxifieldBoolComponent extends Component {
    @action
    onInput(event) {
        this.args.onChange(event.target.checked ? 1 : 0);
    }
}
